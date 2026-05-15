# Azure Portal Key Vault Secret 등록 절차서

> 본 문서는 Azure Key Vault에 새로운 secret을 등록하는 절차를 기술합니다.
> 신규 secret 변수가 추가될 때마다 본 절차를 재수행합니다. **(변수등록시 재수행)**

---

## 필요 항목(개발자에게 요청)

| 항목 | 값 |예시 |
|------|-----|-----|
| Key Vault 이름 | Key 값 | `iwonsvckvkrc001` |
| 리소스 그룹 | 리소스 그룹 이름 | `iwon-svc-rg` |
| 위치 | 리젼 | Korea Central |
| 액세스 제어 방식 | - | RBAC |


## [표2] Azure KeyVault 요청 Key Vault 이름, key 값, 설명

| Key Vault 이름 | Key 값  | Description |
| :--- | :--- | :--- |
| **IWON_WALLET_AES_KEY_BASE64** | `YBZKoOzR6eRW/2ZBfcBxmiN5bDhzXptxHnue69U20+0=` | [cite_start]지갑 주소 암호화 키 [cite: 1] |
| **IWON_API_KEY_HEADER** | `X-IWON-API-KEY` | [cite_start]API Key 헤더 명칭 [cite: 1] |
| **IWON_CHAIN_ID** | `11155111` | [cite_start]Sepolia 네트워크 ID [cite: 1] |
| **IWON_RPC_URL** | `wss://eth-sepolia.g.alchemy.com/v2/OEZ8vjlRi-Qf4KcdiLIDo` | [cite_start]RPC 접속 URL [cite: 1] |
| **IWON_TOKEN_ADDRESS** | `0xf6f411F7B59591b22D22a0681E0f8CE6C746220c` | [cite_start]토큰 컨트랙트 주소 [cite: 1] |
| **IWON_TOKEN_DECIMALS** | `18` | [cite_start]토큰 소수점 자리수 [cite: 1] |
| **IWON_ADMIN_PRIVATE_KEY** | `0x244fb223130ef3ac6d53be4f87dff9daff23dcdca18a024387ee8b26e8361c0c` | [cite_start]관리자 개인키 (보안 주의) [cite: 1] |
| **IWON_COMPANY_PRIVATE_KEY** | `0x7653b6146e102004cd8813a06341a7c507e1386be5c93fa00a39f90e6d17aab9` | [cite_start]운영용 개인키 (보안 주의) [cite: 1] |
| **SPRING_DATASOURCE_URL** | `jdbc:mariadb://10.0.2.50:3306/appdb?serverTimezone=Asia/Seoul&useUnicode=true&characterEncoding=utf8` | [cite_start]통합: 메인 및 Maria120 DB URL [cite: 1] |
| **SPRING_DATASOURCE_USERNAME** | `appuser` | [cite_start]통합: DB 접속 공용 계정 [cite: 1] |
| **SPRING_DATASOURCE_PASSWORD** | `appuserpassword123!` | [cite_start]통합: DB 접속 공용 암호 [cite: 1] |
| **IWON_WALLET_API_BASE_URL** | `http://10.0.2.40:8080` | [cite_start]통합: Wallet/Token API 공용 주소 [cite: 1] |
| **TOKEN_API_BASE_PATH** | `/api/token` | [cite_start]토큰 API 기본 경로 [cite: 1] |
| **IWON_KAFKA_BOOTSTRAP_SERVERS** | `10.0.2.60:9092` | [cite_start]Kafka 브로커 주소 [cite: 1] |
| **IWON_COMPANY_WALLET_USER_ID** | `ITEyes` | [cite_start]통합: 법인 지갑/Treasury 사용자 ID [cite: 1] |
| **SERVER_SERVLET_CONTEXT_PATH** | `/app` | [cite_start]애플리케이션 컨텍스트 경로 [cite: 1] |
| **SPRING_SESSION_TIMEOUT** | `30m` | [cite_start]세션 만료 시간 [cite: 1] |
| **LOGGING_FILE_NAME** | `logs/app.log` | [cite_start]로그 파일 저장 경로 [cite: 1] |
| **LOG_MAX_FILE_SIZE** | `50MB` | [cite_start]로그 개별 파일 최대 크기 [cite: 1] |
| **LOG_TOTAL_SIZE_CAP** | `2GB` | [cite_start]전체 로그 용량 제한 [cite: 1] |
| **LOG_MAX_HISTORY** | `14` | [cite_start]로그 보관 기간 (일 단위) [cite: 1] |
| **IWON_P6SPY_LOG_LEVEL** | `INFO` | [cite_start]SQL 쿼리 로깅 레벨 [cite: 1] |
| **IWON_API_AUTH_ENABLED** | `FALSE` | [cite_start]API 인증 활성화 여부 [cite: 1] |

---
사전 작업: Secret 등록 전에 [Azure_KeyVault_RBAC_역할_할당절차.md](Azure_KeyVault_RBAC_역할_할당절차.md)를 참조하여 RBAC 역할 할당을 먼저 완료한다.

## 1. Azure Portal에서 Secret 등록 (변수등록시 재수행)

1. [Azure Portal](https://portal.azure.com) 접속 후 로그인
2. 상단 검색창에 `iwonsvckvkrc001` 입력 후 **키 자격 증명 모음** 선택
3. 왼쪽 메뉴에서 **비밀(Secrets)** 클릭
4. 상단 **+ 생성/가져오기(Generate/Import)** 클릭
5. 아래 값 입력 후 **만들기(Create)** 저장

   | 항목 | 값 |
   |------|-----|
   | 업로드 옵션 | 수동(Manual) |
   | 이름(Name) | 등록할 secret 이름 (예: `iwon-wallet-aes-key-base64`) |
   | 비밀 값(Value) | secret 값 입력 |
   | 사용(Enabled) | Yes |

6. 생성된 secret을 클릭하여 **Enabled** 상태와 최신 버전 생성 여부 확인

---

## 2. Azure CLI로 Secret 생성 또는 갱신 (변수등록시 재수행)

`$secretValue`에 등록할 secret 값을 대입하여 실행한다.

~~~powershell
az keyvault secret set --vault-name iwonsvckvkrc001 --name <SECRET_NAME> --value "$secretValue"
~~~

AES 키처럼 32바이트 랜덤 값이 필요한 경우 아래 명령으로 생성 후 사용한다.

~~~powershell
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$secretValue = [Convert]::ToBase64String($bytes)
$secretValue

az keyvault secret set --vault-name iwonsvckvkrc001 --name iwon-wallet-aes-key-base64 --value "$secretValue"
~~~

---

## 3. Secret 등록 결과 검증 (변수등록시 재수행)

~~~powershell
az keyvault secret show --vault-name iwonsvckvkrc001 --name <SECRET_NAME> --query "{name:name,enabled:attributes.enabled,updated:attributes.updated,id:id}" -o json
~~~

정상 결과 예시:

~~~json
{
  "enabled": true,
  "id": "https://iwonsvckvkrc001.vault.azure.net/secrets/<SECRET_NAME>/<VERSION>",
  "name": "<SECRET_NAME>",
  "updated": "2026-04-12T..."
}
~~~

---

## 4. Azure DevOps 권한 설정 (RBAC/IAM 기준)

중요: iwonsvckvkrc001은 Access Policy 방식이 아니라 RBAC 방식이다. 따라서 Access Policies 메뉴가 아니라 액세스 제어(IAM)에서 역할을 부여해야 한다.

1. Azure DevOps > Project settings > Service connections에서 iwon-smart-ops-sc 연결을 열고 App ID(Client ID) 확인
2. Azure Portal > Key Vault iwonsvckvkrc001 > 액세스 제어(IAM) > 역할 할당 추가 이동
3. 역할에서 Key Vault 비밀 사용자(Key Vault Secrets User) 선택
4. 구성원 유형은 사용자, 그룹 또는 서비스 주체 선택
5. 서비스 연결 SPN을 검색하여 선택 후 검토 + 할당 수행
6. 역할 할당 탭에서 Key Vault 비밀 사용자 필터로 대상 SPN이 표시되는지 확인

CLI 검증/부여 절차:
~~~powershell
az ad sp show --id <SERVICE_CONNECTION_APP_ID> --query "{appId:appId,id:id,displayName:displayName}" -o json
$kvId = az keyvault show --name iwonsvckvkrc001 --query id -o tsv
az role assignment create --assignee-object-id <SP_OBJECT_ID> --assignee-principal-type ServicePrincipal --role "Key Vault Secrets User" --scope $kvId
az role assignment list --assignee-object-id <SP_OBJECT_ID> --scope $kvId --query "[].{role:roleDefinitionName,scope:scope,principalId:principalId}" -o table
~~~

현재 환경 확인값:
- Service connection App ID: fef01f57-4763-428d-b19d-9f31b0490213
- SPN displayName: iwon-terraform-sp
- SPN objectId: 86cbf4bc-58a1-4e0a-8401-aa515e08687a
- Key Vault scope에서 Key Vault Secrets User 역할 할당 확인 완료

---

## 5. Azure DevOps 파이프라인 연동

- 연동 방식: Variable Group + Key Vault Link 방법 사용
- 선택 이유: YAML 수정 없이 Azure DevOps UI에서 빠르게 설정 가능하며 운영자가 유지보수하기 쉽다.

### 5.1 Variable Group + Key Vault Link 사용
1. Azure DevOps > Pipelines > Library > Variable group 생성 또는 기존 그룹(IWON-KV-SECRETS) 선택
2. Link secrets from an Azure key vault as variables 토글 ON
3. Service connection으로 iwon-smart-ops-sc 선택 후 Authorize
4. Key Vault로 iwonsvckvkrc001 선택 후 Authorize
5. + Add에서 secret iwon-wallet-aes-key-base64 선택 후 Save (변수등록시 재수행)
6. 파이프라인(또는 Release)에 Variable Group 연결
7. 배포 대상 런타임 환경변수 매핑 (변수등록시 재수행)
  - IWON_WALLET_AES_KEY_BASE64 = $(iwon-wallet-aes-key-base64)

**변수등록시 반복 수행 항목**
- 5.1-5 단계: Key Vault에 새 secret 추가/삭제 후 Variable Group에 반영할 때마다 (변수등록시 재수행)
- 5.1-7 단계: 신규 secret을 앱 환경변수로 주입할 때마다 (변수등록시 재수행)

주의사항
- Key Vault에 secret이 새로 추가/삭제되면 Variable Group 매핑 목록은 자동 갱신되지 않는다. + Add에서 수동 갱신이 필요하다.
- Service Connection SPN이 변경되면 4장의 RBAC 절차로 권한을 재부여해야 한다.

공식 문서 및 화면 캡처 참고
- 가이드 문서: https://learn.microsoft.com/en-us/azure/devops/pipelines/library/link-variable-groups-to-key-vaults?view=azure-devops
- UI 캡처(Variable Group + Key Vault): https://learn.microsoft.com/en-us/azure/devops/pipelines/library/media/link-azure-key-vault-variable-group.png?view=azure-devops
- RBAC 연동 캡처: https://learn.microsoft.com/en-us/azure/devops/pipelines/library/media/link-rbac-key-vault-secret-to-variable-group.png?view=azure-devops

### 5.2 수행 결과
✅ 완료된 단계:

1. Key Vault Secret 생성: iwon-wallet-aes-key-base64
2. Service Connection(iwon-smart-ops-sc) SPN 식별 및 RBAC 확인
3. Key Vault Secrets User 역할이 Key Vault 범위에 할당됨 확인
4. Variable Group에서 Key Vault 연동 구성(서비스 연결/Key Vault 선택) 완료

진행 필요 단계:

1. Variable Group + Add에서 iwon-wallet-aes-key-base64가 선택되어 저장되었는지 최종 확인
2. 파이프라인 환경변수 IWON_WALLET_AES_KEY_BASE64 매핑 적용 확인

### 5.3 신규 secret 등록 시 재수행 항목
신규 secret 등록 시 재수행이 필요한 전체 흐름은 이렇습니다:

| 장 | 단계 | 재수행 여부 |
|---|---|---|
| **1~3장** | Key Vault Secret 등록 (Portal/CLI/검증) | ✅ 변수등록시 재수행 |
| **4장** | RBAC 역할 부여 | 최초 1회 (SPN 변경 시만 재수행) |
| **5.1** | 5단계: Variable Group + Add | ✅ 변수등록시 재수행 |
| **5.1** | 6단계: 파이프라인에 Variable Group 연결 | 최초 1회 |
| **5.1** | 7단계: 환경변수 매핑 | ✅ 변수등록시 재수행 |

---

## 6. 배포 후 검증 체크리스트
1. 배포 로그에 Secret 평문값이 노출되지 않는지 확인
2. 애플리케이션 기동 후 암복호화 동작 확인
3. 키 누락 시 예외 메시지로 원인 식별 가능한지 확인
4. 키 교체 절차 문서화
   - Key Vault Secret 값 갱신
   - 재배포
   - 기능 재검증

---

## 7. 보안 운영 원칙
1. 저장소에 실제 AES 키 커밋 금지
2. application.yml 기본값에 비밀값 하드코딩 금지
3. 환경별(개발/스테이징/운영) Key Vault 분리 권장
4. 최소 권한 원칙 적용
