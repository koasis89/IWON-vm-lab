# Azure Portal 추가 확인 사항 - 체크리스트

**기반 정보:** Private Endpoint 확인 완료  
**추가 확인:** Storage Account NFS 설정 및 Private DNS

---

## ☐ Step 1: Private DNS Zone 레코드 확인

### 위치
```
Azure Portal > Private DNS Zones > privatelink.file.core.windows.net
```

### 확인할 항목

#### ☐ 1-1. 영역 존재 여부
- [ ] `privatelink.file.core.windows.net` 영역 존재
- [ ] Resource Group: `iwon-svc-rg`
- [ ] Status: `Active`

#### ☐ 1-2. A Records 탭 확인
```
탭: A Records

찾을 레코드:
  이름 (Name): iwonsfskrciwonsvcrg01
  IP 주소 (IP address): 10.0.2.4
  TTL: 300 또는 기본값
  유형 (Type): A
```

**확인 결과:**
- [ ] 레코드 존재함 → 정상 (DNS 해석 가능)
- [ ] 레코드 없음 → ⚠️ 문제! (DNS 해석 실패 원인)

#### ☐ 1-3. Virtual Network Links 탭
```
vnet 연결 확인:
  연결지명: (예: iwon-svc-rg-vnet-link)
  결접상태: "Linked"
  vnet: iwon-svc-rg-vnet
  자동 등록: (On/Off 상관없음)
```

**확인 결과:**
- [ ] vnet 연결됨 → 정상
- [ ] vnet 미연결 → ⚠️ 문제!

---

## ☐ Step 2: Storage Account 설정 확인

### 위치
```
Azure Portal > 스토리지 계정 > iwonsfskrciwonsvcrg01
```

### 확인할 항목

#### ☐ 2-1. 기본 정보 (Overview)
```
속성 확인:
  - 스토리지 계정 이름: iwonsfskrciwonsvcrg01 ✓
  - 계정 종류 (Account Kind): FileStorage ✓
  - 성능 (Performance): Premium ✓
  - 복제 유형 (Replication): LRS
  - 위치 (Location): Korea Central ✓
  - 구독: 아이티아이즈-sub-gtm-msp-ktpartners-17
```

**확인 결과:**
- [ ] 모두 정상 → 다음으로
- [ ] 비정상 항목 있음 → 재생성 필요

#### ☐ 2-2. File Shares 섹션

```
메뉴: Data management > File shares
```

**공유 목록 확인:**
```
☐ 공유명: shared
  ☐ 상태 (State): Available (또는 Healthy)
  ☐ 용량 (Quota): 1024 GiB
  ☐ 프로토콜 (Protocol): NFS
```

#### ☐ 2-3. NFS 프로토콜 활성화 여부

```
"shared" 공유를 클릭 > Properties 탭
```

**확인 사항:**
```
☐ 활성화된 프로토콜 (Enabled protocols): NFS v4.1
  또는 개별 확인:
  ☐ NFS: Enabled (체크됨)
  ☐ SMB: Disabled (또는 Enabled, 상관없음)

☐ 액세스 계층 (Access tier): Premium
  또는 Hot/Cool 중 선택됨

☐ 프로비저닝 상태 (Provisioning state): Succeeded
```

**확인 결과:**
- [ ] NFS Enabled → 정상
- [ ] NFS Disabled 또는 보이지 않음 → ⚠️ 문제! (NFS 미활성화)

#### ☐ 2-4. 네트워킹 (Networking)

```
메뉴: Security + networking > Networking
```

**방화벽(Firewall) 설정 확인:**
```
☐ 기본 작업 (Default action): Deny
☐ 예외 (Allow access from):
  ☐ Microsoft 서비스 허용 (Allow Azure services...): Checked
  ☐ 특정 가상 네트워크/서브넷 추가 (Add virtual network): 
      - (필요 시) app-subnet을 추가
  ☐ 특정 IP 주소 추가 (Add IP address): (필요 시)

☐ 프라이빗 엔드포인트 연결 (Private endpoint connections):
  ☐ 엔드포인트명: iwon-svc-rg-storage-pe
  ☐ 리소스 유형: Microsoft.Storage/storageAccounts/files (파일 공유용)
  ☐ 상태 (Status): Approved
  ☐ 프로비저닝 상태: Succeeded
```

**확인 결과:**
- [ ] Private Endpoint Approved → 정상
- [ ] Private Endpoint Pending 또는 Rejected → ⚠️ 문제!

---

## ☐ Step 3: 고급 설정 확인 (선택)

### ☐ 3-1. 스토리지 계정 Properties
```
메뉴: Settings > Properties
```

**확인 사항:**
```
☐ Azure Services 설정: 
  ☐ "Allow access from Azure services": Enabled
```

### ☐ 3-2. Endpoints 확인
```
메뉴: Settings > Endpoints
```

**NFS 엔드포인트:**
```
☐ File service (NFS) endpoint: 
  iwonsfskrciwonsvcrg01.file.core.windows.net (공용)
  또는
  iwonsfskrciwonsvcrg01.privatelink.file.core.windows.net (프라이빗)
```

---

## 🔍 진단 규칙

### 정상 시나리오 ✅
```
✓ Private DNS 레코드: 있음 (10.0.2.4)
✓ Storage File Share: Available, NFS Enabled
✓ Private Endpoint: Approved, Succeeded
✓ vnet 연결: Linked
→ 실서버 마운트 테스트 진행
```

### 비정상 시나리오 ⚠️

#### 현상 1: Private DNS 레코드 없음
```
증상: nslookup 실패 또는 공용 IP 반환
원인: Private DNS Zone 동기화 지연 또는 레코드 미생성
해결: 
  1. 수동으로 A 레코드 추가: iwonsfskrciwonsvcrg01 = 10.0.2.4
  2. 또는 Terraform 재배포: terraform apply -auto-approve
```

#### 현상 2: File Share 상태 이상
```
증상: "Creating" 상태 지속 또는 "Failed"
원인: 프로비저닝 미완료 또는 실패
해결:
  1. 30분 대기 후 새로고침
  2. 다시 생성: az storage share create ...
  3. 또는 Terraform 재배포
```

#### 현상 3: NFS 프로토콜 비활성화
```
증상: File Share Properties에서 NFS 보이지 않음
원인: 스토리지 계정이 FileStorage 타입이 아님
해결:
  1. 스토리지 계정 재생성 (Account kind: FileStorage)
  2. Terraform 재배포: terraform apply -auto-approve
```

#### 현상 4: Private Endpoint 상태 이상
```
증상: Status가 "Pending" 또는 "Failed"
원인: 승인 미완료 또는 연결 설정 오류
해결:
  1. Pending인 경우: 승인 버튼 클릭
  2. Failed인 경우: Endpoint 삭제 후 Terraform 재배포
```

---

## 📋 최종 체크리스트

### 포탈 확인 (수동)
- [ ] Private DNS Zone 레코드 존재 확인
- [ ] File Share "shared" 상태: Available + NFS Enabled
- [ ] Private Endpoint 상태: Approved + Succeeded

### 실서버 확인 (자동 스크립트)
```bash
bash vm-ansible/nfs/nfs-server-diagnostics.sh
```

확인할 출력:
- [ ] was01: DNS 해석 성공 → 10.0.2.4
- [ ] was01: 포트 2049 연결 성공
- [ ] was01: showmount 결과: /shared
- [ ] app01: 동일 확인
- [ ] smartcontract01: 동일 확인

### Ansible 재실행 (성공 후)
```bash
cd vm-ansible
ansible-playbook site.yml --limit was,app,integration
```

확인할 결과:
- [ ] 모든 호스트: failed=0
- [ ] 모든 호스트: changed=1 or changed=0 (마운트됨)

---

## 💾 포탈 확인 결과 기록

**확인 일시:** ___________  
**확인자:** ___________

### Private DNS Zone
- [ ] 레코드 존재: YES / NO
- 레코드 값: ___________
- 상태: ___________

### File Share
- [ ] 상태: ___________
- [ ] Protocol: ___________
- [ ] Access Tier: ___________

### Private Endpoint
- [ ] Status: ___________
- [ ] Provisioning State: ___________

### 결론
- [ ] 정상 → 실서버 테스트 진행
- [ ] 비정상 → 해결 필요 항목: ___________

---

## 📞 추가 지원

```
포탈 확인이 어려운 경우:
1. 다음 정보 수집:
   - 스토리지 계정 이름
   - 리소스 그룹명
   - 구독 ID
   
2. Azure Support에 문의 또는
3. Terraform 재배포 고려
   cd vm-azure
   terraform refresh
   terraform plan
   terraform apply
```
