# NFS 마운트 문제 해결 - 최종 실행 가이드

**현재 상황:**
- ✅ Private Endpoint 생성 및 IP 할당 완료 (10.0.2.4)
- ❌ NFS 실제 마운트 실패 ("No such file or directory")

**해결 단계:** 3단계 (10~15분 소요)

---

## 🔧 Step 1: Azure Portal 추가 확인 (5분)

### 1-1. Private DNS Zone 레코드 확인
```
Azure Portal에서 다음 경로로 이동:
Private DNS Zones > privatelink.file.core.windows.net > A Records

찾을 항목:
  ☐ 이름: iwonsfskrciwonsvcrg01
  ☐ 값: 10.0.2.4
  ☐ 상태: Active

결과:
  ✓ 있음 → 1-2로 진행
  ❌ 없음 → 수동 추가 (아래 참고)
```

**Private DNS 레코드 없을 경우 수동 추가:**
```
1. Private DNS Zones > privatelink.file.core.windows.net
2. "+ Record Set" 버튼 클릭
3. 다음 정보 입력:
   - Name: iwonsfskrciwonsvcrg01
   - Type: A
   - IP address: 10.0.2.4
   - TTL: 300
   - Auto-register: Off
4. OK 클릭
5. 2~3분 대기 후 실서버에서 nslookup 테스트
```

### 1-2. Storage Account File Share 확인
```
Azure Portal에서 다음 경로로 이동:
스토리지 계정 > iwonsfskrciwonsvcrg01 > File shares

"shared" 공유 클릭 후 Properties 탭:
  ☐ 상태: Available (또는 Succeeded)
  ☐ Enabled protocols: NFS v4.1
  ☐ Access tier: Premium
  ☐ Provisioning state: Succeeded

결과:
  ✓ 모두 정상 → Step 2로 진행
  ❌ 상태 이상 → 30분 대기 후 새로고침
```

---

## 🔍 Step 2: 실서버 네트워크 진단 (5분)

### 2-1. 진단 스크립트 준비
```bash
# 스크립트 위치 확인
ls -la /c/Workspace/k8s-lab-dabin/vm-ansible/nfs/nfs-server-diagnostics.sh

# 권한 설정
chmod +x /c/Workspace/k8s-lab-dabin/vm-ansible/nfs/nfs-server-diagnostics.sh
```

### 2-2. 수동 진단 실행 (스크립트 미사용 시)
```bash
# Bastion 접속
ssh iwon@20.214.224.224

# was01에서 테스트
ssh -A iwon@10.0.2.20

# 테스트 1: DNS 해석
nslookup iwonsfskrciwonsvcrg01.file.core.windows.net

결과 해석:
  ✓ "Address: 10.0.2.4" 표시됨 → DNS 정상
  ❌ 응답 없음 또는 다른 IP → DNS 문제

# 테스트 2: 포트 연결
nc -zv iwonsfskrciwonsvcrg01.file.core.windows.net 2049

결과 해석:
  ✓ "succeeded" → 포트 열림
  ❌ "Connection refused" 또는 타임아웃 → 네트워크 문제

# 테스트 3: NFS 서버 공유 확인
showmount -e iwonsfskrciwonsvcrg01.file.core.windows.net

결과 해석:
  ✓ "/shared" 표시됨 → NFS 서버 정상
  ❌ "clnt_create: RPC: Port mapper failure" → NFS 서버 미응답

# 테스트 4: 현재 fstab 상태
cat /etc/fstab | grep /mnt/shared

결과:
  이전 fstab 항목 존재 확인
```

### 2-3. 진단 결과 판단

| 진단 항목 | 성공 | 실패 | 대응 방법 |
|---------|------|------|---------|
| DNS 해석 | ✓ | ❌ | Private DNS 레코드 추가 |
| 포트 연결 | ✓ | ❌ | NSG / Storage Network Rules 확인 |
| NFS 서버 | ✓ | ❌ | File Share "shared" 프로비저닝 확인 |
| fstab | ✓ 있음 | ❌ | Ansible이 추가함 (정상) |

---

## ✅ Step 3: 마운트 재시도 (5분)

### 3-1. Step 1-2 모두 ✓ 통과한 경우

#### 기존 마운트 정리
```bash
# was01에서 실행
ssh -A iwon@10.0.2.20

# 기존 마운트 해제
sudo umount /mnt/shared 2>/dev/null || true

# fstab에서 비정상 항목 제거 (안전 확인 후)
sudo sed -i '/\/mnt\/shared/d' /etc/fstab

# 상태 확인
grep /mnt/shared /etc/fstab
  ⚠️ 아무것도 표시되지 않으면 정상
```

#### Ansible 재실행
```bash
# 로컬 PC에서 (C:\Workspace\k8s-lab-dabin)
cd C:\Workspace\k8s-lab-dabin\vm-ansible

# 문법 검사
ansible-playbook -i inventory.ini nfs-only.yml --syntax-check

# 실행
ansible-playbook -i inventory.ini nfs-only.yml

# 결과 확인
# PLAY RECAP에서:
#   failed=0 ✓ 성공
#   failed=1 이상 ❌ 다시 실패
```

#### 마운트 확인
```bash
# 각 호스트에서 확인
ansible app_vms -i inventory.ini -m shell -a "mount | grep /mnt/shared"

예상 결과:
was01  | CHANGED | rc=0 >>
127.0.0.1:/iwonsfskrciwonsvcrg01/shared on /mnt/shared type nfs4

app01  | CHANGED | rc=0 >>
127.0.0.1:/iwonsfskrciwonsvcrg01/shared on /mnt/shared type nfs4

smartcontract01  | CHANGED | rc=0 >>
127.0.0.1:/iwonsfskrciwonsvcrg01/shared on /mnt/shared type nfs4

------

전부 표시되면 ✅ 성공!
```

### 3-2. 진단 결과 ❌ 실패한 경우

#### DNS 해석 실패
```
원인: Private DNS 레코드 없음 또는 ttl 미동기화
해결:
  1. Step 1-1에서 수동으로 레코드 추가
  2. 2~3분 대기
  3. was01에서 nslookup 재시도
  4. 성공 후 Step 3-1로 진행
```

#### 포트 연결 실패
```
원인: 네트워크 경로 차단 (NSG, SG)
해결:
  1. Azure Portal에서 확인:
     - Storage Account > Networking > Firewall
     - 설정: "Allow access from" > "All networks" (임시)
  2. NSG 확인:
     - app-subnet의 NSG에서 2049 포트 허용 규칙 확인
  3. 변경 후 다시 테스트
```

#### NFS 서버 미응답
```
원인: File Share 프로비저닝 미완료 또는 NFS 미활성화
해결:
  1. Step 1-2에서 File Share 상태 다시 확인
  2. 상태 "Creating" → 30분 대기 후 새로고침
  3. NFS protocol 미활성화 → Storage Account 재점검
  4. 해결 안 되면 Terraform 재배포:
     cd vm-azure
     terraform apply -auto-approve
```

---

## 📊 최종 체크리스트

### Before (현재)
- [x] Terraform 리소스 생성
- [x] Private Endpoint 생성 + IP 할당
- [x] Ansible fstab 설정
- [ ] 실제 NFS 마운트
- [ ] 서비스 정상 작동

### During (이제 진행)
- [ ] Step 1: Portal 확인
  - [ ] 1-1: Private DNS 레코드 확인/추가
  - [ ] 1-2: File Share 상태 확인
- [ ] Step 2: 실서버 진단
  - [ ] DNS ✓
  - [ ] Port ✓
  - [ ] NFS ✓
- [ ] Step 3: 마운트 재시도
  - [ ] 에러 정리
  - [ ] Ansible 재실행
  - [ ] 마운트 확인

### After (완료)
- [ ] 모든 호스트 /mnt/shared 마운트 확인
- [ ] 파일 시스템 읽기/쓰기 테스트
- [ ] 서비스 롤아웃 (web/was/app)
- [ ] Smoke test 실행

---

## 🚀 빠른 시작 명령어 세트

### 1단계 명령어
```bash
# Portal 확인 - 수동 (아래 경로 방문)
# https://portal.azure.com/#@outlook.com/resource/subscriptions/51be5183-cf60-4f1f-8b9f-fb4b31daa579/resourceGroups/iwon-svc-rg/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net/overview

# 또는 Azure CLI (설치된 경우)
az network private-dns record-set a list \
  --zone-name privatelink.file.core.windows.net \
  --resource-group iwon-svc-rg
```

### 2단계 명령어
```bash
# 실서버 진단 (통합 스크립트)
bash /c/Workspace/k8s-lab-dabin/vm-ansible/nfs/nfs-server-diagnostics.sh

# 또는 수동 진단
ssh iwon@20.214.224.224  # Bastion
ssh -A iwon@10.0.2.20    # was01
nslookup iwonsfskrciwonsvcrg01.file.core.windows.net
nc -zv iwonsfskrciwonsvcrg01.file.core.windows.net 2049
showmount -e iwonsfskrciwonsvcrg01.file.core.windows.net
```

### 3단계 명령어
```bash
# 기존 마운트 제거
ansible app_vms -i vm-ansible/inventory.ini -m shell \
  -a "sudo umount /mnt/shared 2>/dev/null || true"

# fstab 정리
ansible app_vms -i vm-ansible/inventory.ini -m shell \
  -a "sudo sed -i '/privatelink.file.core.windows.net/d' /etc/fstab"

# Ansible 재실행
cd vm-ansible
ansible-playbook site.yml --limit was,app,integration

# 결과 확인
ansible app_vms -i inventory.ini -m shell -a "mount | grep /mnt/shared"
```

---

## 📞 트러블슈팅 통합 테이블

| 증상 | 원인 | 해결 |
|------|------|------|
| DNS 해석 실패 | Private DNS record 없음 | Portal에서 수동 추가 |
| 포트 2049 연결 안 됨 | NSG/Firewall 차단 | Storage Account Firewall 확인 |
| showmount 응답 없음 | NFS 프로토콜 미활성화 | File Share properties 확인 |
| 여전히 mount 실패 | 위 3개 모두 완료되었을 때 | Terraform 재배포 고려 |

---

## ⏱️ 예상 소요 시간

| 단계 | 작업 | 소요시간 |
|------|------|---------|
| 1-1 | Private DNS 확인 | 2분 |
| 1-2 | File Share 확인 | 2분 |
| 2 | 실서버 진단 | 3분 |
| 3 | 마운트 재시도 | 3분 |
| **합계** | | **10분** |

(DNS sync 대기 제외)

---

## ✨ 성공 지표

마운트 성공 시 다음이 표시됩니다:

```bash
$ mount | grep /mnt/shared
iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net:/shared on /mnt/shared type nfs4 (rw,relatime,vers=4.1,rsize=262144,wsize=262144,namlen=255,hard,proto=tcp,port=2049,timeo=600,retrans=2,sec=sys,clientaddr=10.0.2.20,local_lock=openlock,addr=10.0.2.4)

$ df -h /mnt/shared
Filesystem                                                    Size  Used Avail Use% Mounted on
iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net:/shared 1.0T   0  1.0T   0% /mnt/shared
```

---

## 📝 진행 상황 기록

**Step 1 완료 시간:** ___________  
**Step 2 완료 시간:** ___________  
**Step 3 완료 시간:** ___________  
**최종 완료:** ___________

**문제 발생 여부:** YES / NO  
**발생 시 원인:** ___________  
**해결 방법:** ___________
