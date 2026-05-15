
# Azure Key Vault RBAC 역할 할당 절차

## 개요

| 항목 | 값 |
|------|-----|
| Key Vault 이름 | `iwonsvckvkrc001` |
| 리소스 그룹 | `iwon-svc-rg` |
| 위치 | Korea Central |
| 액세스 제어 방식 | RBAC (역할 기반 액세스 제어) |
| 부여할 역할 | Key Vault 비밀 사용자 (Key Vault Secrets User) |
| 대상 서비스 주체 | `iwon-terraform-sp` |

---

## 사전 요구사항

- Azure Portal 접근 권한 (`jhko@iteyes.co.kr`)
- Key Vault 리소스에 대한 `소유자` 또는 `사용자 액세스 관리자` 역할 보유
- 대상 SPN(`iwon-terraform-sp`)의 App ID 확인

---

## 절차

### 1. Azure Portal 접속

1. [https://portal.azure.com](https://portal.azure.com) 접속
2. `jhko@iteyes.co.kr` 계정으로 로그인

---

### 2. Key Vault 리소스 이동

1. 상단 검색창에 `iwonsvckvkrc001` 입력
2. 검색 결과에서 **키 자격 증명 모음** 유형의 `iwonsvckvkrc001` 클릭

---

### 3. 액세스 제어(IAM) 메뉴 이동

1. 왼쪽 메뉴에서 **액세스 제어(IAM)** 클릭
2. 상단의 **+ 추가** 버튼 클릭
3. 드롭다운에서 **역할 할당 추가** 선택

---

### 4. 역할 선택

1. **역할** 탭에서 검색창에 `Key Vault Secrets` 입력
2. 목록에서 **Key Vault 비밀 사용자** 선택 (라디오 버튼 체크)
3. **다음** 버튼 클릭

---

### 5. 구성원(SPN) 선택

1. **구성원** 탭에서 액세스 할당 대상: **사용자, 그룹 또는 서비스 주체** 선택
2. **+ 구성원 선택** 클릭
3. 오른쪽 패널 검색창에 `iwon-terraform-sp` 입력
4. 검색 결과에서 `iwon-terraform-sp` 선택
5. **선택** 버튼 클릭
6. **다음** 버튼 클릭

---

### 6. 검토 및 할당

1. **검토 + 할당** 탭에서 설정 내용 확인

   | 항목 | 확인 값 |
   |------|---------|
   | 역할 | Key Vault 비밀 사용자 |
   | 범위 | `/subscriptions/.../resourceGroups/iwon-svc-rg/providers/Microsoft.KeyVault/vaults/iwonsvckvkrc001` |
   | 구성원 | `iwon-terraform-sp` |

2. **검토 + 할당** 버튼 클릭하여 저장

---

### 7. 할당 결과 확인

1. **액세스 제어(IAM)** > **역할 할당** 탭으로 이동
2. 역할 필터에서 **Key Vault 비밀 사용자** 선택
3. `iwon-terraform-sp`가 목록에 표시되는지 확인

---

### 8. Azure DevOps 서비스 연결(`iwon-smart-ops-sc`) SPN에 동일 역할 부여

`iwon-smart-ops-sc`가 `iwon-terraform-sp`와 동일한 SPN을 사용하지 않는 경우를 대비해, 아래 절차로 서비스 연결 SPN에도 동일 역할을 확인/부여한다.

1. Azure DevOps > Project settings > Service connections > `iwon-smart-ops-sc` 이동
2. 서비스 연결 상세에서 Service Principal의 App ID(또는 Client ID) 확인
3. Azure CLI에서 App ID로 SPN 식별

~~~powershell
az ad sp show --id <SERVICE_CONNECTION_APP_ID> --query "{appId:appId,id:id,displayName:displayName}" -o json
~~~

4. Key Vault 범위 ID 조회

~~~powershell
$kvId = az keyvault show --name iwonsvckvkrc001 --query id -o tsv
~~~

5. 서비스 연결 SPN에 `Key Vault Secrets User` 역할 부여

~~~powershell
az role assignment create --assignee-object-id <SP_OBJECT_ID> --assignee-principal-type ServicePrincipal --role "Key Vault Secrets User" --scope $kvId
~~~

6. 역할 부여 결과 확인

~~~powershell
az role assignment list --assignee-object-id <SP_OBJECT_ID> --scope $kvId --query "[].{role:roleDefinitionName,scope:scope,principalId:principalId}" -o table
~~~

7. 이미 동일 역할이 존재하면 추가 부여 없이 유지한다.

현재 환경 확인 결과
- Service connection App ID: `fef01f57-4763-428d-b19d-9f31b0490213`
- SPN displayName: `iwon-terraform-sp`
- SPN objectId: `86cbf4bc-58a1-4e0a-8401-aa515e08687a`
- Key Vault `iwonsvckvkrc001` 범위에 `Key Vault Secrets User` 역할 할당 확인 완료

---

## 참고

> **주의**: 해당 Key Vault(`iwonsvckvkrc001`)는 **Vault Access Policy** 방식이 아닌 **RBAC(역할 기반 액세스 제어)** 방식으로 구성되어 있습니다.  
> 따라서 "액세스 정책" 메뉴에서는 권한 부여가 불가능하며, 반드시 **액세스 제어(IAM)** 메뉴를 통해 역할을 할당해야 합니다.

### Key Vault 비밀 사용자 역할 권한 범위

| 권한 | 설명 |
|------|------|
| `Microsoft.KeyVault/vaults/secrets/getSecret/action` | 비밀 값 조회 |
| `Microsoft.KeyVault/vaults/secrets/readMetadata/action` | 비밀 메타데이터 조회 |

이 역할은 Azure DevOps Variable Group의 Key Vault 연동 시 Secret 목록 조회 및 값 읽기에 필요한 최소 권한입니다.

위 문서는 실제 환경 기준으로 작성되었습니다. 서비스 연결이 교체되거나 신규 생성되면, 본 문서의 8번 절차로 SPN 권한을 재확인합니다.