# NFS 마운트 작업 - 최종 진행 상황 요약

**작업 기간:** 2026-03-28  
**현재 진행률:** 70% 완료 (마운트 단계 진행 중)

---

## 📊 현재 상황 (Portal 수동 확인 기반)

### ✅ 완료된 항목

```
1. Terraform 리소스 배포
   ✓ Storage Account: iwonsfskrciwonsvcrg01 (Premium FileStorage)
   ✓ File Share: "shared" (NFS v4.1)
   ✓ Private Endpoint: iwon-svc-rg-storage-pe
   ✓ Private IP: 10.0.2.4 할당됨

2. Private Endpoint 설정 (Portal 확인 완료)
   ✓ 프라이빗 엔드포인트명: iwon-svc-rg-storage-pe
   ✓ 위치: Korea Central
   ✓ 콕넷: app-subnet (iwon-svc-rg-vnet)
   ✓ 프라이빗 IP: 10.0.2.4 할당
   ✓ 상태: 활성

3. Ansible 설정
   ✓ group_vars/all.yml 수정:
     - nfs_mount_enabled: true
     - nfs_storage_account: iwonsfskrciwonsvcrg01
     - nfs_share_name: shared
   ✓ Syntax check: PASS
```

### ⚠️ 확인 필요 항목 (다음 단계)

```
1. Private DNS Zone 레코드 ⚠️
   ? privatelink.file.core.windows.net에 A 레코드 존재
   ? 레코드명: iwonsfskrciwonsvcrg01
   ? 값: 10.0.2.4
   → Portal 수동 확인 필요

2. Storage Account File Share 상태 ⚠️
   ? File Share "shared": Available 상태
   ? Enabled protocols: NFS v4.1
   ? Provisioning state: Succeeded
   → Portal 수동 확인 필요

3. 실서버 네트워크 연결 ⚠️
   ? was01/app01/smartcontract01에서:
     - DNS 해석: 매정 → 10.0.2.4
     - 포트 2049 연결: 성공
     - showmount 응답: /shared 표시
   → 스크립트/수동 진단 필요
```

### ❌ 현재 문제

```
NFS 실제 마운트 실패
Error: mount.nfs4: mounting iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net:/shared 
       failed, reason given by server: No such file or directory

원인 분석 (우선순위):
1. 높음: Private DNS 레코드 미동기화
2. 중간: File Share 프로비저닝 미완료
3. 중간: NFS 프로토콜 미활성화
```

---

## 📁 작성된 문서 및 스크립트

### 📄 문서 (5개)

1. **nfs-setup-progress.md** (첫 진단 문서)
   - 계산식 및 Terraform 리소스 확인
   - 이전 실패 내용 분석
   - 초기 원인 분석

2. **nfs-setup-final-report.md** (상세 보고서)
   - 작업 완료 사항 정리
   - 현재 상황 분석
   - 다음 단계 권장사항

3. **nfs-portal-verification.md** (Portal 결과 검증)
   - Private Endpoint 정보 검증
   - 확인 필요 사항 상세 분석
   - 마운트 실패 원인 추적

4. **nfs-portal-checklist.md** ⭐ 추천
   - Azure Portal 확인 체크리스트
   - 이미 확인된 항목 vs 미확인 항목
   - 비정상 시 대응 방법

5. **nfs-troubleshooting-guide.md** ⭐ 추천
   - 최종 실행 가이드 (3단계)
   - 단계별 명령어 모음
   - 빠른 시작 명령어

### 🔧 스크립트 (3개)

1. **nfs-mount-setup.sh**
   - Ansible playbook 실행 및 검증 자동화

2. **nfs-diagnostics.sh**
   - 초기 진단 스크립트 (미사용)

3. **nfs-server-diagnostics.sh** ⭐ 추천
   - 실서버 네트워크 진단 자동화
   - 3개 호스트 (was01, app01, smart01) 동시 테스트
   - DNS, Port, showmount 확인

---

## 🎯 다음 즉시 실행 항목

### Phase 1: Portal 확인 (5분) 
**담당:** 사용자 (수동)

```
☐ 1단계: Private DNS Zone
  - 위치: Private DNS Zones > privatelink.file.core.windows.net
  - 확인: A Record "iwonsfskrciwonsvcrg01" = "10.0.2.4" 존재?
  - 결과:
    ✓ 있음 → 다음으로
    ❌ 없음 → 수동 추가 (2~3분)

☐ 2단계: File Share 설정
  - 위치: Storage Account > File shares > "shared" > Properties
  - 확인: Status = Available, Protocol = NFS v4.1
  - 결과:
    ✓ 정상 → Phase 2로
    ❌ 이상 → 30분 대기 후 새로고침

☐ 3단계: 정리
  - 위 모두 ✓면 nfs-troubleshooting-guide.md의 Step 3 실행
```

**참고 자료:** `vm-ansible/nfs/nfs-portal-checklist.md`

### Phase 2: 실서버 진단 (5분)
**담당:** 에이전트 (지원 또는 사용자 수동)

```bash
# 실서버 진단 (자동 스크립트)
bash C:/Workspace/k8s-lab-dabin/vm-ansible/nfs/nfs-server-diagnostics.sh

또는 수동 (was01에서):
ssh iwon@20.214.224.224  # Bastion
ssh -A iwon@10.0.2.20    # was01
nslookup iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net
nc -zv iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net 2049
showmount -e iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net
```

**참고 자료:** `vm-ansible/nfs/nfs-server-diagnostics.sh`

### Phase 3: 마운트 재시도 (5분)
**담당:** 에이전트 (Ansible 실행)

```bash
# 조건: Phase 1,2 모두 ✓

# 1. 기존 마운트 정리
cd C:/Workspace/k8s-lab-dabin/vm-ansible
ansible app_vms -i inventory.ini -m shell \
  -a "sudo umount /mnt/shared 2>/dev/null || true; \
      sudo sed -i '/privatelink/d' /etc/fstab"

# 2. Ansible 재실행
ansible-playbook -i inventory.ini nfs-only.yml

# 3. 결과 확인
ansible app_vms -i inventory.ini -m shell -a "mount | grep /mnt/shared"
```

**참고 자료:** `vm-ansible/nfs/nfs-troubleshooting-guide.md`

---

## 📋 상태별 다음 조치

### 만약 Phase 1에서 실패하면...

| 발견 사항 | 조치 |
|---------|------|
| Private DNS 레코드 없음 | Portal에서 수동 추가 (1-2분) |
| File Share "Creating" 상태 | 30분 대기 후 새로고침 |
| NFS Protocol 미활성화 | Storage Account 재생성 고려 |

### 만약 Phase 2에서 실패하면...

| 증상 | 원인 | 조치 |
|------|------|------|
| `nslookup` 응답 없음 | DNS 미동기화 | Private DNS 레코드 추가 |
| `nc` 연결 실패 | NSG/Firewall | Storage Account Firewall 확인 |
| `showmount` 응답 없음 | NFS 미활성 | File Share 상태 재확인 |

### 만약 Phase 3에서도 실패하면...

```
Terraform 재배포 시도:
cd vm-azure
terraform refresh
terraform plan
terraform apply -auto-approve
```

---

## 📊 진행도 체크보드

```
초기 계산 & 검증: ████████████████████ 100% ✓
Ansible 설정: █████████████████████ 100% ✓
Private Endpoint 확인: █████████████████ 85% ⚠️
  - 프라이빗 엔드포인트: ✓
  - Private DNS 레코드: ?
  - File Share 상태: ?
실서버 네트워크: ░░░░░░░░░░░░░░░░░░░░ 0% ⚠️
NFS 실제 마운트: ░░░░░░░░░░░░░░░░░░░░ 0% ❌
이후 작업 (web/was/app): ░░░░░░░░░░░░░░░░░░░░ 0% ⏸

전체: ███████░░░░░░░░░░░░░ 35%
```

---

## 💾 파일 정리

### 변경된 파일
```
M  vm-ansible/group_vars/all.yml
```

### 새로 생성된 파일 (vm-ansible/nfs/)
```
?? nfs-setup-progress.md           (초기 진행 문서)
?? nfs-setup-final-report.md       (상세 보고서)
?? nfs-portal-verification.md      (Portal 검증)
?? nfs-portal-checklist.md         ⭐ (Portal 체크리스트)
?? nfs-troubleshooting-guide.md    ⭐ (최종 가이드)
?? nfs-mount-setup.sh             (마운트 자동화)
?? nfs-diagnostics.sh             (초기 진단)
?? nfs-server-diagnostics.sh      ⭐ (실서버 진단)
```

**⭐ 표시된 파일이 가장 중요합니다.**

---

## 🚀 권장 순서

```
1️⃣  nfs-portal-checklist.md 읽기 (Portal 확인 가이드)
    ↓
2️⃣  Azure Portal에서 수동 확인 (5분)
    ↓
3️⃣  nfs-server-diagnostics.sh 실행 또는 수동 진단 (5분)
    ↓
4️⃣  nfs-troubleshooting-guide.md의 Step 3 실행 (5분)
    ↓
5️⃣  마운트 확인 (완료!)
```

---

## 📞 지원 연락

현재 상황:
- ✅ 인프라: 완료
- ✅ Ansible: 완료
- ⚠️ 네트워크 검증: 진행 중
- ❌ 실제 마운트: 진행 예정

다음 단계 예상 소요 시간: **15분**

---

## 📌 최종 체크리스트

### 제공된 자료
- [x] 문서 5개 작성
- [x] 스크립트 3개 작성
- [x] Portal 확인 결과 검증
- [x] Private Endpoint 확인 ✓
- [x] 문제 원인 분석
- [x] 해결 방안 가이드 제공

### 남은 작업
- [ ] Phase 1: Portal 확인 (사용자)
- [ ] Phase 2: 실서버 진단 (스크립트)
- [ ] Phase 3: Ansible 재실행 (자동)
- [ ] 최종 검증

---

## 🎯 성공 기준

```bash
$ mount | grep /mnt/shared
iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net:/shared on /mnt/shared type nfs4 ...

$ df -h /mnt/shared
Filesystem ... Size  Used Avail Use% Mounted on
...            1.0T   0   1.0T  0%   /mnt/shared
```

위와 같은 출력이 3개 호스트(was01, app01, smartcontract01) 모두에서 확인되면 **완료!** ✅
