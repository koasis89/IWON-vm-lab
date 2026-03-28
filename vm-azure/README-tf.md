# vm-azure Terraform 상세 README

이 문서는 [readme-vm.md](readme-vm.md)의 목표 아키텍처를 기준으로, vm-azure 폴더의 실제 Terraform 코드 상태를 파일 단위로 분석한 상세 문서입니다.

대상 코드:
- [provider.tf](../provider.tf)
- [main.tf](../main.tf)
- [variables.tf](../variables.tf)
- [variables_vms.tf](../variables_vms.tf)
- [network.tf](../network.tf)
- [compute.tf](../compute.tf)
- [storage.tf](../storage.tf)
- [https_option_b.tf](../https_option_b.tf)
- [outputs.tf](../outputs.tf)

## 1. 현재 Terraform 아키텍처 요약

이 구성은 VM 직접 운영 모델에 아래 요소를 결합한 형태입니다.

- 네트워크: VNet 1개, Subnet 4개(ingress/app/mgmt/AzureFirewallSubnet)
- 보안: Subnet 단위 NSG 분리
- 컴퓨트: Ubuntu 22.04 Linux VM 7대(web/was/app/smartcontract/db/kafka/bastion)
- 외부 진입: Standard Load Balancer + Application Gateway(WAF v2) 병행
- 인증서/비밀: Key Vault + User Assigned Managed Identity + RBAC
- 파일 스토리지: Azure Files Premium NFS v4.1 + Private Endpoint + Private DNS

핵심 특징:
- App Gateway에서 TLS를 종단하고 내부는 HTTP(80/8080)로 전달
- bastion01만 Public IP 보유
- 나머지 VM은 Private IP 고정 할당

## 2. 파일별 분석

### 2.1 Provider 및 공통 설정

파일:
- [provider.tf](../provider.tf)
- [main.tf](../main.tf)

주요 내용:
- azurerm provider 버전: ~> 3.0
- time provider 버전: ~> 0.12
- Resource Group 생성
- 공통 태그 정의(env=poc, owner=platform-team 등)
- trusted_admin_cidr 고정: 175.197.170.13/32
- Subnet CIDR 고정:
  - ingress: 10.0.1.0/24
  - app: 10.0.2.0/24
  - mgmt: 10.0.3.0/24
  - fw: 10.0.254.0/26

검토 포인트:
- 관리자 공인 IP 변경 시 trusted_admin_cidr 업데이트가 필요
- 로컬 변수 기반 CIDR이라 환경별 분리(dev/stg/prod)가 아직 없음

### 2.2 변수 구조

파일:
- [variables.tf](../variables.tf)
- [variables_vms.tf](../variables_vms.tf)

주요 내용:
- 지역/리소스그룹 기본값 지정
- VM 로그인 변수(admin_username, admin_password, ssh_public_key_path)
- HTTPS 관련 변수(Key Vault명, App Gateway명, 인증서명, 인증서 모드 등)
- VM 정의를 map(object)로 선언해 for_each 생성

현재 VM 정의:
- app subnet: web01, was01, app01, smartcontract01, db01, kafka01
- mgmt subnet: bastion01

검토 포인트:
- admin_password 기본값이 코드에 존재함(운영 보안 리스크)
- tls_certificate_mode 기본값은 import
- tls_certificate_pfx_base64, tls_certificate_pfx_password 변수는 현재 리소스에서 직접 사용되지 않음

### 2.3 네트워크 및 NSG

파일:
- [network.tf](../network.tf)

리소스 구성:
- VNet: 10.0.0.0/16
- Subnet 4개 생성 후 NSG 3개(ingress/app/mgmt) 연결
- Ingress NSG:
  - 80, 443 전역 허용
  - App Gateway 관리 포트(65200-65535) 허용
  - AzureLoadBalancer 트래픽 허용
- App NSG:
  - ingress->app 8080 허용
  - ingress->app 80 허용
  - mgmt->app 22 허용
  - app 내부 3306, 9092 허용
  - app 내부 2049, 111 허용(NFS 관련)
- Mgmt NSG:
  - trusted_admin_cidr -> 22 허용

Load Balancer:
- Public IP + Standard LB
- 프론트 80/443 -> web01 백엔드
- Probe는 TCP 80

검토 포인트:
- App Gateway와 Load Balancer가 동시에 외부 엔드포인트를 보유하는 구조
- 운영 시 단일 진입점을 App Gateway로 통합할지 정책 정리가 필요
- app_nfs_rpcbind(111)는 NFS v4.1 전용 운영이면 불필요할 수 있어 재검토 권장

### 2.4 컴퓨트(VM/NIC)

파일:
- [compute.tf](../compute.tf)

주요 내용:
- bastion 전용 Public IP 생성
- 모든 VM NIC를 for_each로 생성
- bastion01에만 public_ip_address_id 연결
- VM OS 이미지: Canonical Ubuntu 22.04 LTS Gen2
- OS Disk: Premium_LRS
- 인증 방식:
  - SSH 공개키 설정
  - 비밀번호 인증도 활성화(disable_password_authentication = false)
- web01 NIC를 LB 백엔드 풀에 연결

검토 포인트:
- 운영 보안 기준상 비밀번호 로그인 비활성화 권장
- VM role 태그는 name 기반으로 일관되게 부여됨

### 2.5 HTTPS Option B(App Gateway + Key Vault)

파일:
- [https_option_b.tf](../https_option_b.tf)

주요 흐름:
1. Key Vault 생성(RBAC 모드)
2. 현재 실행 주체에게 Key Vault Administrator 부여
3. RBAC 전파 대기(time_sleep 60초)
4. 인증서 소스 결정
   - mode=import: 기존 Key Vault Secret ID 사용
   - mode=self: Terraform이 self-signed 인증서 생성
5. App Gateway용 UAMI 생성
6. UAMI에 Key Vault Secrets User 부여
7. App Gateway(WAF_v2) 생성
   - HTTP/HTTPS listener
   - HTTP->HTTPS 리다이렉트
   - Path 기반 라우팅(/app, /app/* -> app01:8080)
   - 기본 경로는 web01:80
   - WAF Detection, OWASP 3.2

백엔드 풀 정의:
- web-backend-pool: web01
- was-backend-pool: was01
- app-backend-pool: app01

검토 포인트:
- 현재 라우팅 규칙에서는 was-backend-pool이 실제 요청 경로에 사용되지 않음
- probe host가 127.0.0.1로 고정되어 있어 애플리케이션 실제 host 헤더 기반 점검이 필요할 수 있음
- Key Vault purge_protection_enabled=false는 운영 규정에 따라 강화 필요 가능

### 2.6 스토리지(Azure Files NFS)

파일:
- [storage.tf](../storage.tf)

주요 내용:
- Premium FileStorage 계정 생성
- file 서브리소스용 Private Endpoint 생성(app-subnet)
- Private DNS Zone(privatelink.file.core.windows.net) 및 VNet 링크 구성
- Storage Share 생성:
  - name: shared
  - protocol: NFS
  - quota: 1024 GiB
- Storage account network rule:
  - default_action = Deny
  - bypass = [AzureServices]

검토 포인트:
- Private Endpoint 사용 구조이므로 VM은 Private DNS 해석이 선행되어야 정상 마운트됨
- Network rule에서 explicit subnet allowlist 없이 Private Endpoint 기반 접근 모델로 운영

### 2.7 출력값

파일:
- [outputs.tf](../outputs.tf)

제공 정보:
- 리소스그룹, VNet 이름
- LB, Bastion, App Gateway Public IP
- Key Vault 이름
- VM별 Private IP map
- NFS 마운트 정보(host/path/명령)

운영 활용:
- 배포 후 점검 자동화 스크립트 입력값으로 사용 가능

## 3. readme-vm 기준 대비 구현 상태

정합성이 높은 항목:
- 계층 분리용 subnet 구조 반영
- bastion 중심 관리 접속 모델 반영
- Key Vault + App Gateway 기반 HTTPS 종단 구조 반영
- Azure Files NFS 사설 접근 구조 반영

차이 또는 보완이 필요한 항목:
- readme-vm의 관리자 허용 IP 예시와 현재 코드 CIDR 값이 다름
- Azure Firewall 리소스는 아직 미구현(Subnet만 선점)
- LB와 App Gateway가 병행되어 단일 진입점 원칙이 불명확
- VM 인증에서 password auth가 활성화되어 보안 기준과 상충 가능

## 4. 리소스 의존성 흐름

1. main.tf
2. network.tf
3. compute.tf
4. storage.tf
5. https_option_b.tf
6. outputs.tf

중요 의존 관계:
- App Gateway는 vm_definitions의 고정 IP(web01/was01/app01)에 의존
- App Gateway 인증서는 Key Vault Secret ID에 의존
- Key Vault RBAC 전파 지연 완화를 위해 time_sleep 사용
- NFS 출력값은 Storage Account/Share/Private DNS 구성에 의존

## 5. 배포 및 검증 절차

사전 준비:
- Azure 로그인 및 올바른 subscription 설정
- vm-azure 실행 폴더에서 terraform init 완료
- 운영 시 민감값은 tfvars 또는 환경변수로 외부 주입

기본 명령:

```powershell
terraform -chdir="./vm-azure" fmt -recursive
terraform -chdir="./vm-azure" validate
terraform -chdir="./vm-azure" plan -out=tfplan
terraform -chdir="./vm-azure" apply tfplan
terraform -chdir="./vm-azure" output
```

핵심 검증:

```powershell
az network application-gateway show-backend-health -g iwon-svc-rg -n iwon-svc-appgw
az network public-ip show -g iwon-svc-rg -n iwon-svc-rg-bastion-pip --query ipAddress -o tsv
az network private-endpoint list -g iwon-svc-rg -o table
```

NFS 마운트 예시(앱 계층 VM):

```bash
sudo mkdir -p /mnt/shared
sudo mount -t nfs -o vers=4,minorversion=1,sec=sys <storage-account>.privatelink.file.core.windows.net:/shared /mnt/shared
```

## 6. 운영 개선 권장사항

1. 보안 강화
- admin_password 기본값 제거
- disable_password_authentication = true 전환
- Key Vault purge protection 활성화 검토

2. 네트워크 단순화
- 외부 진입점을 App Gateway로 일원화할지 결정
- 필요 없는 LB 규칙 또는 리소스 정리 검토

3. HTTPS 운영 안정화
- mode=import 사용 시 실제 공개 인증서 Secret ID 명시
- Probe 경로를 서비스 헬스 엔드포인트로 세분화

4. 환경 분리
- dev/stg/prod tfvars 분리
- VM SKU, CIDR, 인증서명, 도메인 값 환경별 분기

5. 코드 유지보수
- 사용되지 않는 변수(tls_certificate_pfx_*) 정리 여부 결정
- README와 실제 코드 간 차이를 정기 점검

## 7. 참조 문서

- [vm-azure/docs/readme-vm.md](docs/readme-vm.md) - Azure VM 기반 전체 아키텍처, 보안 기준, 운영 원칙.
- [vm-azure/docs/readme-vm-ip.md](docs/readme-vm-ip.md) - VM별 IP/네트워크 매핑 및 접속 기준.
- [vm-azure/docs/readme-shell.md](docs/readme-shell.md) - 서버 운영 시 자주 사용하는 쉘 명령 모음.
- [vm-azure/docs/readme-https.md](docs/readme-https.md) - App Gateway/Key Vault 기반 HTTPS 구성 및 점검 절차.
- [vm-azure/docs/readme-docker.md](docs/readme-docker.md) - VM 환경의 Docker 활용 가이드 및 운영 팁.
- [vm-azure/docs/readme-cert.md](docs/readme-cert.md) - 인증서 발급/반입/갱신 및 Key Vault 연동 가이드.
