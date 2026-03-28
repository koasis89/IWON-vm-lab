# Azure Files NFS v4.1 마운트 진행 내역

기준 시간: 2026-03-28 16:00 UTC+9200 (approx)

## 진행 단계

### 1단계: 구성 확인 및 계산

#### 1-1. Storage Account 이름 계산
- 소스: `vm-azure/storage.tf` 라인 6
- 계산식: `"iwonsfskrc${replace(var.resource_group_name, "-", "")}01"`
- var.resource_group_name: `"iwon-svc-rg"`
- replace 결과: `"iwonsvcrg"` (모든 "-" 제거)
- **최종 이름: `iwonsfskrciwonsvcrg01`**

#### 1-2. NFS 공유 정보
- Share Name: `shared` (storage.tf 라인 66)
- Protocol: `NFS v4.1`
- Access Tier: `Premium`
- Mount Path: `/mnt/shared`
- NFS Options: `vers=4,minorversion=1,sec=sys`
- Private Endpoint FQDN: `iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net`

#### 1-3. 마운트 대상 호스트
- was01 (10.0.2.20)
- app01 (10.0.2.30)
- smartcontract01 (10.0.2.40) - integration 그룹

### 2단계: Ansible 설정 업데이트

#### 2-1. group_vars/all.yml 수정
파일: `vm-ansible/group_vars/all.yml`

**변경 전:**
```yaml
nfs_mount_enabled: false
nfs_storage_account: ""
nfs_share_name: ""
nfs_mount_path: /mnt/shared
```

**변경 후:**
```yaml
nfs_mount_enabled: true
nfs_storage_account: "iwonsfskrciwonsvcrg01"
nfs_share_name: "shared"
nfs_mount_path: /mnt/shared
```

**수정 완료:** ✓

### 3단계: Ansible 플레이북 실행 시도

#### 3-1. Syntax Check
```bash
ansible-playbook -i inventory.ini site.yml --syntax-check
```

결과: ✓ PASS

#### 3-2. NFS 마운트 배포 시도
```bash
cd C:\Workspace\k8s-lab-dabin\vm-ansible
ansible-playbook site.yml --limit was,app,integration
```

**실행 명령어:**
```bash
wsl.exe bash -lc 'cd /mnt/c/Workspace/k8s-lab-dabin/vm-ansible && ansible-playbook -i inventory.ini site.yml --limit was,app,integration'
```

**결과: ❌ FAILED**

#### 3-3. 실패 내용

PLAY RECAP:
```
app01                      : ok=7    changed=3    unreachable=0    failed=1
smartcontract01            : ok=7    changed=3    unreachable=0    failed=1
was01                      : ok=7    changed=3    unreachable=0    failed=1
```

**에러 메시지:**
```
TASK [nfs_client : Mount NFS share]
fatal: [app01]: FAILED! => 
  cmd: ["mount", "-a"]
  stderr: "mount.nfs4: mounting iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net:/shared failed, reason given by server: No such file or directory"
```

**공통 실패 원인:**
- Mount 명령: `mount.nfs4: mounting iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net:/shared failed`
- 에러 유형: `No such file or directory` (NFS 경로 없음 또는 서버 응답 거부)

**fstab 설정은 성공했으나 마운트 단계에서 실패:**
- 3개 호스트 공통: ok=7 changed=3 (fstab 수정, 디렉토리 생성까지는 성공)
- Mount 명령에서만 fail (rc=32)

#### 3-4. 진단 분석

#### 가능한 원인 분석

| 원인 | 상태 | 진단 필요 |
|------|------|----------|
| NFS 서버 응답 없음 | 아님 (에러 응답이 들어옴) | ✓ 네트워크 연결은 정상 |
| 경로 `/shared` 불존재 | 가능성 높음 | ✓ Azure Files 리소스 상태 확인 필요 |
| Terraform apply 미완료 | 가능성 있음 | ✓ Azure 포털에서 Storage Account 상태 확인 필요 |
| NFS 활성화 안 됨 | 가능성 있음 | ✓ Storage Account NFS 설정 확인 필요 |
| 네트워크 보안 규칙 | 아님 (응답 받음) | - |

### 진행 상황 요약

| 항목 | 상태 | 진행률 |
|------|------|--------|
| Storage Account 이름 계산 | ✓ 완료 | 100% |
| Ansible 변수 설정 | ✓ 완료 | 100% |
| NFS fstab 구성 | ✓ 완료 | 100% |
| NFS 실제 마운트 | ❌ 실패 | 0% |

### 다음 단계

1. **실서버에서 NFS 서버 상태 확인**
   - NFS 경로 확인: `showmount -e iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net`
   - 네트워크 연결: `nc -zv iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net 2049`

2. **Azure 포털 확인**
   - Storage Account: `iwonsfskrciwonsvcrg01` 존재 여부
   - File share: `shared` 존재 여부
   - NFS protocol 활성화 여부
   - Private Endpoint 연결 상태

3. **Terraform State 검증**
   - azure/terraform.tfstate에서 NFS 리소스 상태
   - Storage Share 리소스의 actual state 확인

4. **NFS 마운트 옵션 조정 검토**
   - vers=4.1 명시적 설정 필요 여부
   - 다른 보안 옵션 시도

## 생성된 보조 파일

- `vm-ansible/nfs/nfs-mount-setup.sh` - 마운트 설정 및 검증 자동화 스크립트
- `vm-ansible/nfs/nfs-diagnostics.sh` - NFS 연결성 진단 스크립트
- `vm-ansible/nfs/nfs-setup-progress.md` - 이 진행 문서

---

## Terraform 리소스 상태 확인

Terraform state 검증 결과:
```
Type: azurerm_storage_account, Name: nfs
Type: azurerm_storage_account_network_rules, Name: nfs
Type: azurerm_storage_share, Name: nfs
```

✓ Terraform에서 정의된 NFS 리소스 3개 모두 state에 존재

---

## 트러블슈팅 및 해결 방안

### 현재 상황
- Terraform: 리소스 정의 완료 ✓
- Ansible fstab: 설정 완료 ✓
- NFS 실제 마운트: 실패 ❌ ("No such file or directory")

### 근본 원인 분석

에러: `mount.nfs4: mounting iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net:/shared failed, reason given by server: No such file or directory`

#### 가능한 원인 (우선순위 순서)

1. **Azure Files NFS Share 미프로비저닝**
   - Terraform apply 이후 Azure 리소스 실제 생성 미완료
   - Storage Share 상태: "Creating" 또는 불완전 상태일 가능성

2. **Private Endpoint 연결 미완성**
   - Private Endpoint의 프로비저닝이 미완료일 가능성
   - Private DNS 레코드 동기화 미완료

3. **NFS 프로토콜 미활성화**
   - Storage Account에서 NFS 프로토콜이 비활성화 상태
   - Storage Share의 enabled_protocol이 실제로 적용되지 않았을 가능성

4. **네트워크 정책 충돌**
   - Storage Account의 네트워크 규칙(default_action: "Deny")이 과도하게 제한
   - Private Endpoint 경로 외 다른 경로로의 접근 차단

### 해결 방안

#### Step 1: Azure 포털 확인 (수동)
```
1. Azure Portal → "iwonsfskrciwonsvcrg01" Storage Account 검색
2. Storage Account 상태 확인:
   - Provisioning State: "Succeeded" 확인
   - Account Kind: "FileStorage" 확인
   - Account Tier: "Premium" 확인

3. File Shares 메뉴 → "shared" share 확인:
   - 상태: "Available" 확인
   - Protocol: "NFS" 활성화 확인
   - Access Tier: "Premium" 확인

4. Networking → Private Endpoints:
   - Private Endpoint 상태 확인
   - Private Connections 상태: "Approved" 확인
```

#### Step 2: 실서버 진단 (CLI)
```bash
# Was01에서 실행
ssh iwon@20.214.224.224  # Bastion
ssh -A iwon@10.0.2.20    # was01

# 네트워크 연결성 확인
ping iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net

# NFS 포트 연결성 확인
nc -zv iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net 2049

# NFS 서버의 공유 목록 확인
showmount -e iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net
```

#### Step 3: Terraform 재배포 (필요시)
```bash
cd C:\Workspace\k8s-lab-dabin\vm-azure

# 변경사항 확인
terraform plan -out=tfplan

# 재배포
terraform apply tfplan

# 결과 확인
terraform output storage_account_name
terraform output storage_nfs_mount_command
```

#### Step 4: Ansible 재실행 (리소스 준비 후)
```bash
cd C:\Workspace\k8s-lab-dabin\vm-ansible

# 1. fstab 항목 제거 (이전 실패 제거)
ansible app_vms -i inventory.ini -m shell -a "sudo sed -i '/privatelink.file.core.windows.net/d' /etc/fstab" 2>&1

# 2. 마운트 디렉토리 정리
ansible app_vms -i inventory.ini -m shell -a "sudo umount /mnt/shared 2>/dev/null || true" 2>&1

# 3. NFS 재마운트 진행
ansible-playbook site.yml --limit was,app,integration 2>&1
```

---

## 추가 리소스

### 참고 문서
- [Azure Files NFS 문제 해결](https://docs.microsoft.com/azure/storage/files/storage-troubleshooting-files-nfs)
- [Private Endpoint 네트워크 설정](https://docs.microsoft.com/azure/private-link/private-endpoint-dns)

### 지원 명령어
```bash
# group_vars/all.yml 상태 확인
cat vm-ansible/group_vars/all.yml | grep -A 3 nfs_mount_enabled

# fstab 설정 확인 (실서버에서)
cat /etc/fstab | grep privatelink

# 마운트 상태 확인 (실서버에서)
mount | grep /mnt/shared

# 최근 마운트 로그
dmesg | tail -20 | grep -i nfs
```

---

## 생성된 보조 파일

- `vm-ansible/nfs/nfs-mount-setup.sh` - 마운트 설정 및 검증 자동화 스크립트
- `vm-ansible/nfs/nfs-diagnostics.sh` - NFS 연결성 진단 스크립트
- `vm-ansible/nfs/nfs-setup-progress.md` - 이 진행 문서
