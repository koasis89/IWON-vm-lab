# Azure Portal Private Endpoint 확인 결과 검증

**확인 일시:** 2026-03-28  
**확인자:** 사용자 수동 확인  
**대상:** iwon-svc-rg-storage-pe (Storage Account NFS Private Endpoint)

---

## 📊 확인된 정보 분석

### Private Endpoint 정보
```
프라이빗 엔드포인트: iwon-svc-rg-storage-pe
위치: Korea Central
리소스 그룹: iwon-svc-rg
상태: 활성 (화면에 표시됨)
```

### 네트워크 연결 정보
```
가상 네트워크: iwon-svc-rg-vnet
서브넷: app-subnet
프라이빗 IP: 10.0.2.4
공용 IP: - (없음, 정상)
```

### 연결 대상
```
프라이빗 엔드포인트가 연결된 리소스: iwonsfskrciwonsvcrg01 (Storage Account)
연결 상태: 연결됨
```

---

## ✅ 정상 확인 사항

| 항목 | 예상값 | 실제값 | 상태 |
|------|--------|--------|------|
| Private Endpoint 이름 | iwon-svc-rg-storage-pe | ✓ 일치 | ✓ |
| 서브넷 위치 | app-subnet | ✓ 일치 | ✓ |
| 가속화된 네트워킹 | 사용 안 함 (정상) | ✓ 사용 안 함 | ✓ |
| 공용 IP | 없음 (정상) | ✓ 없음 | ✓ |
| vnet | iwon-svc-rg-vnet | ✓ 존재 | ✓ |

---

## ⚠️ 확인 필요 사항

### 1. Private DNS Zone 레코드 동기화 여부
현재 확인 정보:
- ✓ Private Endpoint: 생성됨
- ✓ Private IP: 할당됨 (10.0.2.4)
- ? Private DNS 레코드: **미확인**

**검증 필요:**
```
Azure Portal > Private DNS Zones > privatelink.file.core.windows.net
> A Records 탭에서 다음 확인:

1. 레코드명: iwonsfskrciwonsvcrg01
2. 값: 10.0.2.4 (위에서 확인한 Private IP)
3. TTL: 300 초 (기본값)

⚠️ 이 레코드가 없으면 DNS 해석이 실패하여 마운트 에러 발생
```

### 2. Storage Account 자체 설정 확인
```
Azure Portal > 스토리지 계정 "iwonsfskrciwonsvcrg01" 접속

확인 사항:
1. 프로토콜 설정
   □ File Shares > "shared" > Properties
   □ Enabled protocols: "NFS" 활성화 확인

2. 액세스 계층
   □ Account > Properties
   □ Access Tier: "Premium" 확인

3. 네트워크 설정
   □ Networking > Firewalls and virtual networks
   □ Default action: "Deny" (제한적 정책)
   □ Private Endpoints: "iwon-svc-rg-storage-pe" 연결 확인

4. NFS 공유 상태
   □ File Shares > "shared"
   □ Provisioning State: "Succeeded" 확인
```

---

## 🔍 현재 마운트 실패 원인 분석

### NFS 마운트 에러 상황
```
Error: mount.nfs4: mounting iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net:/shared 
       failed, reason given by server: No such file or directory
```

### 원인 추적 (단계별)

#### 1단계: DNS 해석 확인 ⚠️ 중요
```
hostname: iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net
resolution: ? → 10.0.2.4 (또는 실패?)

현재 상황:
- Private Endpoint IP가 할당됨: ✓ (10.0.2.4)
- Private Endpoint DNS 레코드: ? 미확인

⚠️ DNS 레코드가 동기화되지 않으면:
   nslookup iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net
   → 응답 없음 또는 PUBLIC IP 반환
   → NFS 연결 실패
```

#### 2단계: NFS 서버 상태 확인 ⚠️ 중요
```
NFS 공유 경로: /shared
현재 상태: Azure에서 프로비저닝 중일 가능성

확인 필요:
- Storage Share 프로비저닝 완료 여부
- NFS 프로토콜 활성화 여부
- 공유 크기 할당 여부 (현재 1024MB 설정)
```

#### 3단계: 네트워크 정책 확인 ⚠️ 중요
```
현재 설정: 
- Private Endpoint: ✓ 생성됨
- Network Rules: Deny (제한적)

확인 필요:
- Bypass: AzureServices (설정되어 있나?)
- Private Endpoint 등록: 필수
```

---

## 🚀 다음 진단 단계 (우선순위)

### ⚠️ 긴급 (즉시 실행)

**Step 1: Private DNS Zone 레코드 확인**
```
Azure Portal 경로:
1. 포탈 > Private DNS Zones
2. privatelink.file.core.windows.net 선택
3. A Records 탭 확인
4. 레코드: iwonsfskrciwonsvcrg01 = 10.0.2.4

✓ 있음 → Step 2로 진행
❌ 없음 → Portal에서 수동 추가 또는 Terraform 재배포
```

**Step 2: Storage Account NFS 설정 확인**
```
Azure Portal 경로:
1. 스토리지 계정 "iwonsfskrciwonsvcrg01" 이동
2. File Shares 섹션 > "shared" 클릭
3. Properties 탭 > "NFS 프로토콜" 토글 확인 (활성)
4. Status: "Available" 확인
5. Access tier: "Premium" 확인
```

**Step 3: 실서버 DNS 및 연결성 테스트**
```bash
# Bastion 접근
ssh iwon@20.214.224.224

# was01에서 DNS 테스트
ssh -A iwon@10.0.2.20

# DNS 해석
nslookup iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net
# 예상 응답: 10.0.2.4

# 포트 연결
nc -zv iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net 2049
# 예상 응답: succeeded

# 경로 확인
showmount -e iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net
# 예상 응답: /shared
```

---

## 📋 현재 아키텍처 상황

```
┌─────────────────────────────────────┐
│  Azure Storage Account              │
│  iwonsfskrciwonsvcrg01              │
│  (Premium FileStorage + NFS)        │
│  - File Share: "shared"             │
│  - Protocol: NFS (?)                │
└────────────┬────────────────────────┘
             │ Private Endpoint
             │ iwon-svc-rg-storage-pe
             │ IP: 10.0.2.4
             │
    ┌────────▼──────────┐
    │  Private DNS Zone │
    │  privatelink.file │
    │  Record: ?        │ ⚠️ 동기화 확인 필요
    └────────┬──────────┘
             │ DNS Resolution
             │ 실패 가능성
             │
    ┌────────▼──────────────┐
    │  application-subnet   │
    │  - was01 (10.0.2.20)  │
    │  - app01 (10.0.2.30)  │
    │  - smart01 (10.0.2.40)│
    └───────────────────────┘
             │ mount -a
             │ FAILED: No such file or directory
             ▼
```

---

## ✅ 최종 체크리스트 (검증 완료 항목)

- [x] Private Endpoint 생성: iwon-svc-rg-storage-pe
- [x] Private IP 할당: 10.0.2.4
- [x] 서브넷 위치: app-subnet (정상)
- [x] vnet 연결: iwon-svc-rg-vnet (정상)
- [ ] Private DNS 레코드 동기화
- [ ] Storage Account NFS 프로토콜 활성화
- [ ] Storage Share 프로비저닝 완료
- [ ] 실서버 DNS 해석
- [ ] 실서버 포트 연결 (2049)
- [ ] 실서버 NFS 마운트

---

## 🔧 권장 조치

**1순위 - 즉시 실행:**
- [ ] Private DNS Zone A 레코드 존재 여부 확인
- [ ] Storage Account > File Shares > "shared" 상태 확인
- [ ] NFS 프로토콜 활성화 상태 확인

**2순위 - 실서버 진단:**
- [ ] was01에서 `nslookup` 테스트
- [ ] was01에서 `nc -zv` 포트 테스트
- [ ] was01에서 `showmount -e` 경로 확인

**3순위 - 마운트 재시도:**
- [ ] 위 모든 확인 통과 후 Ansible 재실행

---

## 📝 추적 메모

**포탈 확인 결과 상태: 부분 정상**
- Private Endpoint: ✓ 생성 및 IP 할당됨
- Private DNS: ? 확인 필요

**다음 작업 담당:**
- Azure Portal에서 Private DNS Zone 확인
- 실서버에서 DNS 및 네트워크 진단
