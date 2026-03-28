# Azure Files NFS v4.1 마운트 작업 최종 보고서

**실행 일시:** 2026-03-28  
**작업 범위:** Premium FileStorage + NFS v4.1 마운트 설정  
**대상 호스트:** was01, app01, smartcontract01 (integration)

---

## 📋 작업 완료 사항

### 1단계: 인프라 검증 ✓ 완료

**Storage Account 이름 계산**
```
계산식: "iwonsfskrc${replace(var.resource_group_name, "-", "")}01"
결과: "iwonsfskrciwonsvcrg01"
검증: terraform.tfstate에서 확인됨 ✓
```

**Terraform 리소스 상태**
```
✓ azurerm_storage_account (nfs) - State에 존재
✓ azurerm_storage_account_network_rules (nfs) - State에 존재  
✓ azurerm_storage_share (nfs) - State에 존재
```

### 2단계: Ansible 설정 ✓ 완료

**파일: vm-ansible/group_vars/all.yml**

**값 변경:**
```yaml
# Before:
nfs_mount_enabled: false
nfs_storage_account: ""
nfs_share_name: ""
nfs_mount_path: /mnt/shared

# After:
nfs_mount_enabled: true
nfs_storage_account: "iwonsfskrciwonsvcrg01"
nfs_share_name: "shared"
nfs_mount_path: /mnt/shared
```

**변경 사항:** M vm-ansible/group_vars/all.yml

### 3단계: Ansible 플레이북 실행 ⚠️ 부분 완료

**실행 명령어:**
```bash
cd C:\Workspace\k8s-lab-dabin\vm-ansible
ansible-playbook site.yml --limit was,app,integration
```

**결과 요약:**
```
Syntax Check: ✓ PASS
NFS 설정 적용: ⚠️ 부분 성공
  - nfs-common 설치: ✓ OK
  - /mnt/shared 디렉토리 생성: ✓ OK (changed=3)
  - /etc/fstab 수정: ✓ OK (changed=3)
  - 실제 마운트 (mount -a): ❌ FAILED (rc=32)
```

**실패 호스트:**
```
app01: failed=1, skipped=0
was01: failed=1, skipped=0
smartcontract01: failed=1, skipped=0
```

**에러 메시지:**
```
TASK [nfs_client : Mount NFS share]
fatal: [app01]: FAILED! => 
  stderr: "mount.nfs4: mounting iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net:/shared 
  failed, reason given by server: No such file or directory"
```

---

## 🔍 현재 상황 분석

### 성공한 부분
- ✅ NFS 클라이언트 패키지 설치 (nfs-common)
- ✅ 마운트 포인트 `/mnt/shared` 생성
- ✅ `/etc/fstab` 엔트리 추가:
  ```
  iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net:/shared /mnt/shared nfs4 vers=4,minorversion=1,sec=sys,noatime,_netdev 0 0
  ```

### 실패한 부분
- ❌ 실제 NFS 마운트 실패 ("No such file or directory")

### 근본 원인 분석

| 순위 | 원인 | 가능성 | 진단 방법 |
|-----|------|--------|---------|
| 1 | Azure Files NFS Share 미프로비저닝 | 높음 | Azure Portal에서 Storage Account 상태 확인 |
| 2 | Private Endpoint 미완료 | 중 | Private Endpoint 상태 및 연결 확인 |
| 3 | NFS 프로토콜 미활성화 | 중 | Storage Account NFS 설정 확인 |
| 4 | 네트워크 정책 제한 | 낮음 | NSG 및 Storage Account Network Rules 확인 |

---

## 📁 생성된 파일 목록

### 1. Ansible 설정 수정
```
M  vm-ansible/group_vars/all.yml
```

### 2. 테스트 및 진단 스크립트 (vm-ansible/nfs/)
```
?? vm-ansible/nfs/nfs-mount-setup.sh
   - NFS 마운트 설정 및 검증 자동화
   - Syntax check, 배포, 검증 통합

?? vm-ansible/nfs/nfs-diagnostics.sh
   - NFS 연결성 진단
   - DNS 해석, 포트 연결 테스트, 경로 확인

?? vm-ansible/nfs/nfs-setup-progress.md
   - 이 작업의 상세 진행 내역
   - 원인 분석 및 해결 방안 가이드
```

### 3. 기존 스크립트 (이전 작업)
```
?? tools(sh-py)/analyze_sql_case.py
?? tools(sh-py)/check-db-root-fix.sh
?? tools(sh-py)/reset-and-reimport-db.sh
?? tools(sh-py)/step5-verify.sh
```

---

## 🔧 다음 단계

### 즉시 실행 권장사항

**Step 1: Azure 포털 수동 확인 (필수)**
```
1. Azure Portal 접속
2. 리소스 그룹 "iwon-svc-rg" 이동
3. Storage Account "iwonsfskrciwonsvcrg01" 검색
4. 다음 확인:
   - Provisioning State: "Succeeded" ✓
   - Account Kind: "FileStorage" ✓
   - Tier: "Premium" ✓
   - File Shares > "shared" 존재 ✓
   - Protocol: "NFS" 활성화 ✓
   - Networking > Private Endpoints 상태 확인
```

**Step 2: 실서버 직접 테스트 (권장)**
```bash
# Bastion을 통해 was01 접속
ssh iwon@20.214.224.224
ssh -A iwon@10.0.2.20

# DNS 해석 확인
nslookup iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net

# NFS 포트 연결 테스트
nc -zv iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net 2049

# NFS 서버의 공유 목록 확인
showmount -e iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net

# 수동 마운트 시도
sudo mkdir -p /mnt/shared_test
sudo mount -t nfs4 -o vers=4,minorversion=1,sec=sys \
  iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net:/shared /mnt/shared_test
```

**Step 3: Azure Files NFS 상태 CLI 확인**
```bash
# Terraform apply 확인
cd C:\Workspace\k8s-lab-dabin\vm-azure
terraform refresh  # Azure 상태 동기화

# Storage Share 상태 조회
terraform show | grep -A 10 'azurerm_storage_share'

# 또는 Azure CLI (설치된 경우)
az storage account show --name iwonsfskrciwonsvcrg01 --resource-group iwon-svc-rg
az storage share list --account-name iwonsfskrciwonsvcrg01 --auth-mode login
```

**Step 4: 문제 해결 후 Ansible 재실행**
```bash
# 기존 fstab 항목 제거 (있을 경우)
ansible app_vms -i vm-ansible/inventory.ini -m shell \
  -a "sudo sed -i '/privatelink.file.core.windows.net/d' /etc/fstab"

# 기존 마운트 제거
ansible app_vms -i vm-ansible/inventory.ini -m shell \
  -a "sudo umount /mnt/shared 2>/dev/null || true"

# Ansible 재실행
cd vm-ansible
ansible-playbook site.yml --limit was,app,integration
```

---

## 📊 현재 마운트 상태

**실서버 검증 결과 (이 작업 실행 시점):**
```
web01:  /mnt/shared - ❌ 미마운트 (NFS 클라이언트 미설치)
was01:  /mnt/shared - ❌ 미마운트 (fstab 있음, 마운트 실패)
app01:  /mnt/shared - ❌ 미마운트 (fstab 있음, 마운트 실패)
smartcontract01: /mnt/shared - ❌ 미마운트 (fstab 있음, 마운트 실패)
db01:   /mnt/shared - ❌ 스킵 (NFS 마운트 대상 아님)
kafka01: /mnt/shared - ❌ 스킵 (NFS 마운트 대상 아님)
```

**fstab 상태:**
```
was01/ app01 / smartcontract01: 
  iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net:/shared /mnt/shared nfs4 vers=4,minorversion=1,sec=sys,noatime,_netdev 0 0
  ✓ 입력됨
```

---

## 📝 명령어 이력

### 변경 사항 적용
```bash
# 1. group_vars/all.yml 수정 (완료)
cat vm-ansible/group_vars/all.yml | grep -A 3 nfs_mount_enabled

# 2. Ansible Syntax Check
wsl.exe bash -lc 'cd /mnt/c/Workspace/k8s-lab-dabin/vm-ansible && \
  ansible-playbook -i inventory.ini site.yml --syntax-check'

# 3. playbook 실행
wsl.exe bash -lc 'cd /mnt/c/Workspace/k8s-lab-dabin/vm-ansible && \
  ansible-playbook site.yml --limit was,app,integration'

# 4. 검증
ansible app_vms -i vm-ansible/inventory.ini -m shell \
  -a "mount | grep /mnt/shared || echo MOUNT_NOT_FOUND"
```

### 진단 스크립트 실행 (필요시)
```bash
# NFS 설정 및 검증
bash vm-ansible/nfs/nfs-mount-setup.sh

# 연결성 진단
bash vm-ansible/nfs/nfs-diagnostics.sh
```

---

## 🎯 추천 조치 사항

1. **우선순위 높음:**
   - Azure Portal에서 Storage Account / File Share 물리 상태 확인
   - Terraform refresh 후 리소스 상태 재검증
   - 실서버에서 NFS 서버 접근성 테스트

2. **우선순위 중간:**
   - Private Endpoint 프로비저닝 상태 확인
   - Azure Storage Account Network Rules 정책 검토
   - Private DNS Zone 레코드 동기화 확인

3. **우선순위 낮음 (문제 해결 후):**
   - Ansible Group_vars 값 재검증
   - 모든 호스트에 NFS 마운트 완료 후 웹/WAS 서비스 재시작
   - 마운트 포인트 권한 설정 확인

---

## ✅ 완료 체크리스트

- [x] Storage Account 이름 계산 및 검증
- [x] Terraform 리소스 상태 확인
- [x] group_vars/all.yml 수정
- [x] Ansible Syntax Check
- [x] Ansible playbook 실행 시도
- [x] 에러 수집 및 분석
- [x] 진단 스크립트 생성
- [x] 진행 상황 문서화
- [ ] 실제 마운트 성공 (Azure 측 검증 후)
- [ ] 모든 호스트 마운트 확인
- [ ] Smoke test 실행

---

## 📚 참고 자료

- Terraform 설정: `vm-azure/storage.tf`
- Ansible NFS Role: `vm-ansible/roles/nfs_client/tasks/main.yml`
- Ansible 변수: `vm-ansible/group_vars/all.yml`
- Inventory: `vm-ansible/inventory.ini`
- 진행 상황: `vm-ansible/nfs/nfs-setup-progress.md`
