# 인증서 작업 절차서 (readme-cert)

이 문서는 본 세션에서 수행한 HTTPS 인증서 관련 작업을 시간순으로 정리한 절차서입니다.
요청사항은 다음이었습니다.

- DNS A 레코드 연결 완료 확인
- 브라우저 인증서 경고 원인 분석
- Key Vault/App Gateway 연동 상태 점검
- iwon-smart.site, www.iwon-smart.site 기준 인증서 적용 방안 정리
- Terraform 코드/문서 반영 및 검증 결과 기록

## 1. 작업 대상 및 기준 정보

- 리포지토리: k8s-lab-dabin
- 작업 경로: vm-azure
- Azure Resource Group: iwon-svc-rg
- Application Gateway: iwon-svc-appgw
- App Gateway Public IP: 20.194.3.246
- Key Vault: iwonsvckvkrc001
- Key Vault 인증서명: iwon-web-tls-cert

## 2. 1차 사실 확인 (DNS/백엔드/인증서 상태)

### 2.1 DNS 확인

실행 명령어:

```powershell
nslookup iwon-smart.site
```

결과:

```text
Server:  kns.kornet.net
Address:  168.126.63.1

Non-authoritative answer:
Name:    iwon-smart.site
Address:  20.194.3.246
```

판정:

- DNS A 레코드는 App Gateway 공인 IP로 정상 연결됨

### 2.2 App Gateway 백엔드 헬스 확인

실행 명령어:

```powershell
az network application-gateway show-backend-health -g iwon-svc-rg -n iwon-svc-appgw --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address,health:health,reason:healthProbeLog}" -o table
```

결과:

```text
Address    Health    Reason
---------  --------  ---------------------------------
10.0.2.10  Healthy   Success. Received 200 status code
```

판정:

- App Gateway -> web01(10.0.2.10) 경로 정상

### 2.3 Key Vault 인증서 상태 확인

실행 명령어:

```powershell
az keyvault certificate show --vault-name iwonsvckvkrc001 --name iwon-web-tls-cert --query "{name:name,issuer:policy.issuerParameters.name,subject:policy.x509CertificateProperties.subject,sans:policy.x509CertificateProperties.subjectAlternativeNames.dnsNames,secretId:sid}" -o json
```

결과:

```json
{
  "issuer": "Self",
  "name": "iwon-web-tls-cert",
  "sans": null,
  "secretId": "https://iwonsvckvkrc001.vault.azure.net/secrets/iwon-web-tls-cert/87ff7910f12d4bc1a3c204cb5224defa",
  "subject": "CN=dev.iteyes.co.kr"
}
```

판정:

- 인증서 경고 원인은 DNS가 아니라 인증서 내용 불일치
- 현재 인증서는 Self-signed + SAN 없음 + Subject 불일치

### 2.4 Key Vault 공개 CA issuer 연동 여부 확인

실행 명령어:

```powershell
az keyvault certificate issuer list --vault-name iwonsvckvkrc001 -o json
```

결과:

```json
[]
```

판정:

- Key Vault에 공개 CA issuer(DigiCert/GlobalSign) 미연동
- 현재 환경에서는 Key Vault 단독으로 공개 브라우저 신뢰 인증서 자동 발급 불가

## 3. 원인 분석 결론

브라우저 경고 원인은 다음 3가지 조합으로 확정됨.

1. Issuer가 Self
2. Subject가 CN=dev.iteyes.co.kr (운영 도메인 불일치)
3. SAN에 iwon-smart.site, www.iwon-smart.site 미포함

즉, DNS 작업은 완료되었고 인증서 교체가 남은 상태임.

## 4. 코드 변경 절차 (Terraform)

아래 변경은 기존 인프라를 유지하면서 인증서 운영 경로를 확장하기 위해 수행함.

### 4.1 변수 확장

수정 파일:

- variables.tf

변경 내용:

- tls_certificate_mode 추가
  - 허용값: self, import
  - 기본값: self (기존 배포 호환성 유지)
- tls_certificate_subject 기본값 변경
  - CN=iwon-smart.site
- tls_certificate_san_dns_names 추가
  - 기본값: iwon-smart.site, www.iwon-smart.site
- tls_certificate_pfx_base64 추가 (sensitive)
- tls_certificate_pfx_password 추가 (sensitive)

의도:

- 테스트용(self)과 운영용(import) 경로를 분리
- 운영 전환 시 공개 CA PFX를 Key Vault로 반입 가능하도록 설계

### 4.2 인증서 리소스 로직 확장

수정 파일:

- https_option_b.tf

변경 내용:

- local.use_imported_tls_certificate 추가
- local.tls_certificate_secret_id 추가
  - mode=import: web_tls_imported secret_id 사용
  - mode=self: web_tls secret_id 사용
- 기존 self-signed 리소스 유지
  - resource azurerm_key_vault_certificate.web_tls
  - count로 import 모드 시 생성 비활성화
- import 리소스 추가
  - resource azurerm_key_vault_certificate.web_tls_imported
  - certificate.contents/password 사용
  - precondition: import 모드에서 pfx_base64 필수
- Application Gateway ssl_certificate 블록이 local.tls_certificate_secret_id 참조하도록 변경

의도:

- 동일한 App Gateway 리스너 구성에서 인증서 소스만 전환 가능하도록 구성

### 4.3 문서 갱신

수정 파일:

- readme-https.md
- readme-tf.md

변경 내용:

- DNS 완료 상태 반영
- 인증서 경고 원인(Subject/SAN/Issuer) 명시
- 공개 CA 인증서 교체 절차 추가
- PowerShell 기반 명령어로 검증 절차 정리

## 5. Terraform 검증 절차 및 결과

### 5.1 validate

실행 명령어:

```powershell
terraform validate
```

결과:

```text
Success! The configuration is valid.
```

판정:

- 문법/스키마 유효

### 5.2 plan

실행 명령어:

```powershell
terraform plan -input=false
```

핵심 결과:

```text
Plan: 0 to add, 2 to change, 0 to destroy.
```

변경 요약:

- azurerm_key_vault_certificate.web_tls[0] in-place 변경
  - subject: CN=dev.iteyes.co.kr -> CN=iwon-smart.site
  - SAN 추가: iwon-smart.site, www.iwon-smart.site
- azurerm_application_gateway.https in-place 변경
  - 인증서 참조 및 probe 블록 재동기화(동일 구성 재계산)

판정:

- 파괴(destroy) 없이 in-place 변경으로 수렴
- 즉시 적용 가능한 상태

## 6. 검증 체크리스트 (완료/미완료)

완료:

- DNS A 레코드 연결 확인
- App Gateway 백엔드 헬스 확인
- Key Vault/App Gateway 인증서 참조 관계 확인
- Terraform validate 통과
- Terraform plan 영향 범위 확인

미완료(운영 마무리 단계):

- 공개 CA 인증서(PFX) 반입 및 import 모드 적용
- 브라우저 자물쇠 최종 확인

## 7. 운영 전환 절차 (공개 CA 인증서 적용)

### 7.1 PFX 준비

- iwon-smart.site + www.iwon-smart.site SAN 포함
- full chain 포함된 PFX 권장

### 7.2 Base64 변환

```powershell
$pfxPath = "C:\certs\iwon-smart.site.pfx"
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes($pfxPath))
```

### 7.3 tfvars 또는 환경변수로 주입

예시:

```hcl
tls_certificate_mode         = "import"
tls_certificate_name         = "iwon-web-tls-cert"
tls_certificate_pfx_base64   = "<base64-encoded-pfx>"
tls_certificate_pfx_password = "<pfx-password>"
```

### 7.4 적용

```powershell
terraform validate
terraform plan
terraform apply -auto-approve
```

### 7.5 적용 후 검증

```powershell
az keyvault certificate show --vault-name iwonsvckvkrc001 --name iwon-web-tls-cert --query "{subject:policy.x509CertificateProperties.subject,sans:policy.x509CertificateProperties.subjectAlternativeNames.dnsNames,issuer:policy.issuerParameters.name}" -o json

curl.exe -vI --max-time 10 https://iwon-smart.site
curl.exe -vI --max-time 10 https://www.iwon-smart.site
```

정상 기준:

- Subject가 CN=iwon-smart.site
- SAN에 iwon-smart.site, www.iwon-smart.site 포함
- 브라우저 경고 없음(자물쇠 표시)

## 8. 최종 결론

- DNS 연결 작업은 완료됨
- 네트워크/백엔드 경로도 정상
- 현재 브라우저 경고는 인증서 메타데이터 불일치가 원인
- Terraform은 공개 CA 인증서 반입(import)까지 지원하도록 확장 완료
- 남은 실작업은 공개 CA 인증서 PFX 준비 후 import 모드 apply 1회

## 9. Let’s Encrypt 실제 작업 절차 및 결과

아래는 실제 수행한 무료 CA 적용 절차를 순차적으로 정리한 로그입니다.

### 9.1 사전 연결성 확인

실행 명령어:

```powershell
curl.exe -I --max-time 10 http://iwon-smart.site/.well-known/acme-challenge/precheck
ssh -o StrictHostKeyChecking=no iwon@20.214.224.224 "hostname; whoami"
```

결과:

```text
HTTP/1.1 301 Moved Permanently
Location: https://iwon-smart.site/.well-known/acme-challenge/precheck

bastion01
iwon
```

판정:

- 도메인 라우팅 및 Bastion 접근은 정상
- web01 직접 SSH는 권한 이슈로 실패하여 Azure VM Run Command 방식으로 진행

### 9.2 web01에서 Let’s Encrypt 인증서 발급

실행 명령어(요약):

```bash
sudo apt-get update -y
sudo apt-get install -y certbot openssl
sudo systemctl stop nginx || true
sudo certbot certonly --standalone --non-interactive --agree-tos --register-unsafely-without-email -d iwon-smart.site -d www.iwon-smart.site
sudo openssl pkcs12 -export -in /etc/letsencrypt/live/iwon-smart.site/fullchain.pem -inkey /etc/letsencrypt/live/iwon-smart.site/privkey.pem -out /tmp/iwon-smart.pfx -passout pass:TempPfx2026!
sudo systemctl start nginx
```

결과(핵심):

```text
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/iwon-smart.site/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/iwon-smart.site/privkey.pem
This certificate expires on 2026-06-25.
```

판정:

- iwon-smart.site, www.iwon-smart.site SAN 포함 인증서 발급 성공

### 9.3 PFX 전달/변환 이슈 및 해결

초기 fullchain PFX를 원격 출력으로 회수하는 과정에서 출력 파싱 이슈가 발생했습니다.

증상:

- 로컬 복원 파일 길이 0 바이트 또는 손상
- Key Vault import 시 PKCS#12 읽기 오류

해결:

1. VM 내부 원본 PFX 유효성 확인
2. leaf 기반 PFX(`cert.pem + privkey.pem`)를 별도로 생성
3. run-command 출력 전체를 파일 저장 후 `[stdout] ... [stderr]` 구간만 정규식으로 추출하여 복원

검증 결과:

- 로컬 PFX 복원 파일 길이 3043 바이트
- 이후 Key Vault import 성공

### 9.4 Key Vault import

실행 명령어:

```powershell
az keyvault certificate import --vault-name iwonsvckvkrc001 --name iwon-web-tls-cert --file c:\Workspace\k8s-lab-dabin\vm-azure\iwon-smart-leaf.pfx --password "TempPfx2026!"
```

결과(핵심):

- 새 인증서 버전 생성: `991ab9153c3e459a9f3c245c1faf16e8`
- `sid`: `https://iwonsvckvkrc001.vault.azure.net/secrets/iwon-web-tls-cert/991ab9153c3e459a9f3c245c1faf16e8`
- subject: `CN=iwon-smart.site`
- SAN: `iwon-smart.site`, `www.iwon-smart.site`
- expires: `2026-06-25T03:10:44+00:00`

### 9.5 App Gateway 인증서 참조 갱신

실행 명령어:

```powershell
$sid = az keyvault certificate show --vault-name iwonsvckvkrc001 --name iwon-web-tls-cert --query sid -o tsv
az network application-gateway ssl-cert update -g iwon-svc-rg --gateway-name iwon-svc-appgw -n iwon-web-tls-cert --key-vault-secret-id $sid -o json
az network application-gateway ssl-cert list -g iwon-svc-rg --gateway-name iwon-svc-appgw -o table
```

결과:

- `keyVaultSecretId`가 `.../secrets/iwon-web-tls-cert/991ab9153c3e459a9f3c245c1faf16e8`로 변경
- `ProvisioningState: Succeeded`

### 9.6 최종 동작 검증

실행 명령어:

```powershell
Invoke-WebRequest https://iwon-smart.site -UseBasicParsing -TimeoutSec 20
az network application-gateway show-backend-health -g iwon-svc-rg -n iwon-svc-appgw --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address,health:health,reason:healthProbeLog}" -o table
```

결과:

```text
HTTPS_STATUS:200

Address    Health    Reason
---------  --------  ------------------------------
10.0.2.10  Healthy   Success. Received  status code
```

판정:

- 도메인 HTTPS 정상(200)
- App Gateway 백엔드 헬스 정상 유지

## 10. Terraform import 모드 고정(재적용 시 Let’s Encrypt 유지)

목표:

- 수동/자동 갱신으로 Key Vault에 들어간 Let’s Encrypt 인증서를 Terraform 재적용이 덮어쓰지 않도록 고정

적용한 코드 정책:

1. `tls_certificate_mode` 기본값을 `import`로 변경
2. import 모드에서는 Terraform이 인증서를 새로 만들지 않고, 기존 Key Vault secret ID를 참조
3. 기본 참조는 버전리스(versionless) ID
  - `https://<keyvault>.vault.azure.net/secrets/<cert-name>`
4. 필요 시 `tls_certificate_existing_secret_id`로 명시적 override 가능

효과:

- Terraform 재적용 시 self-signed 재생성으로 되돌아가지 않음
- Key Vault에 최신 버전이 올라와도 App Gateway는 같은 인증서명(versionless) 기준으로 유지 가능

운영 권장:

- 인증서 import/갱신은 운영 스크립트(Azure CLI 또는 배포 파이프라인)에서 수행
- Terraform은 인프라 참조만 담당

### 10.1 실제 적용 명령 및 결과

실행 명령어:

```powershell
terraform state rm azurerm_key_vault_certificate.web_tls[0]
terraform apply -auto-approve
az network application-gateway ssl-cert list -g iwon-svc-rg --gateway-name iwon-svc-appgw -o table
```

결과(핵심):

```text
Removed azurerm_key_vault_certificate.web_tls[0]
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.

KeyVaultSecretId                                                   Name               ProvisioningState
-----------------------------------------------------------------  -----------------  -----------------
https://iwonsvckvkrc001.vault.azure.net/secrets/iwon-web-tls-cert  iwon-web-tls-cert  Succeeded
```

판정:

- Terraform이 Key Vault 인증서를 직접 생성/삭제하지 않도록 상태 분리 완료
- App Gateway가 버전리스 Key Vault secret ID를 참조하도록 반영 완료
- 향후 Key Vault 내 동일 인증서명(`iwon-web-tls-cert`)의 새 버전 import 시 재적용 안정성 확보
