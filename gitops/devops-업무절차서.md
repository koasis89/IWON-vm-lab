# GitOps 기반 DevOps 전체 업무 절차서

작성일: 2026-04-01
적용 저장소: IWON-vm-lab/gitops
적용 시나리오: GitHub Actions는 아직 미구성, Azure DevOps는 기본 설정만 완료(깃헙 연결 안됨)

---

## 0. 현재 상태와 목표

현재 상태:
1. GitHub: 워크플로우/시크릿/환경 보호 규칙 미설정
2. Azure DevOps: Organization 생성만 완료, GitHub 연결 미완료
3. 로컬 Terraform 실행 환경: 도구는 설치됨, 인증값은 미설정

목표:
1. Terraform + Ansible(YAML) 기반으로 실제 생성/배포 실행
2. Azure DevOps Portal에서 연결/권한/파이프라인 실행 기반 점검
3. GitHub에서 CI 트리거 및 CD 호출 준비

### 0.1 수행 순서 시뮬레이션/검증 결과

현재 조건(`create_project = true`, GitHub 미설정, ADO 기본만 설정)을 기준으로 시뮬레이션한 결과, 실행 순서는 `1 -> 2 -> 3`이 가장 안정적이다.

| 시나리오 | 결과 | 차단 원인 |
|---|---|---|
| `1 -> 2 -> 3` | 권장 | IaC 생성값(`project/feed/pipeline_id`) 확보 후 포털 점검/깃헙 연계 가능 |
| `2 -> 3 -> 1` | 비권장 | 포털에서 필요한 값 일부가 아직 미생성 상태일 수 있음 |
| `3 -> 2 -> 1` | 비권장 | GitHub Secrets에 필요한 `ADO_PIPELINE_ID`가 아직 없음 |

검증 결론:
1. 1단계에서 리소스 생성 및 출력값 확보
2. 2단계에서 포털 연결/권한 최종 점검
3. 3단계에서 GitHub 워크플로우/시크릿 반영

---

## 1. Terraform + Ansible(tf, yml)로 생성/배포하는 절차 (실행순서: 1단계, 최초)

이 절차는 로컬 또는 실행 에이전트에서 수행한다.

### 1.1 실행 전 필수 입력값 요청 시점

아래는 실행 목적별 필수값이다. 조건에 맞는 값만 요청한다.

1. 공통(항상 필요)
- `AZDO_PERSONAL_ACCESS_TOKEN`

2. Azure RM Service Connection 생성 또는 Terraform 인프라 작업 수행 시 추가 필요
- `ARM_CLIENT_ID`
- `ARM_CLIENT_SECRET`
- `ARM_TENANT_ID`
- `ARM_SUBSCRIPTION_ID`

요청 템플릿:
```text
Terraform 실행 전 아래 값을 전달/설정해 주세요.
- AZDO_PERSONAL_ACCESS_TOKEN
- ARM_CLIENT_ID
- ARM_CLIENT_SECRET
- ARM_TENANT_ID
- ARM_SUBSCRIPTION_ID
```

### 1.1.1 ARM 값 확보(az CLI)

여기서 ARM은 모바일 CPU가 아니라 Azure Resource Manager를 의미한다.

실행 순서:
1. 현재 구독/테넌트 확인
2. Terraform용 SP(`iwon-terraform-sp`) 존재 여부 확인
3. SP가 없으면 생성, 있으면 Secret 재발급
4. 확보한 값을 환경변수로 설정

실행 명령(PowerShell):
```powershell
$spName='iwon-terraform-sp'
$account=az account show --output json | ConvertFrom-Json
$subId=$account.id
$tenantId=$account.tenantId

$existingAppId=az ad sp list --display-name $spName --query "[0].appId" -o tsv
if ([string]::IsNullOrWhiteSpace($existingAppId)) {
	$sp=az ad sp create-for-rbac --name $spName --role Contributor --scopes "/subscriptions/$subId" --query "{appId:appId,password:password,tenant:tenant,displayName:displayName}" -o json | ConvertFrom-Json
} else {
	$sp=az ad app credential reset --id $existingAppId --append --display-name "terraform-$(Get-Date -Format yyyyMMddHHmmss)" --query "{appId:appId,password:password,tenant:tenant}" -o json | ConvertFrom-Json
}

Write-Host "ARM_CLIENT_ID=$($sp.appId)"
Write-Host "ARM_CLIENT_SECRET=<masked>"
Write-Host "ARM_TENANT_ID=$tenantId"
Write-Host "ARM_SUBSCRIPTION_ID=$subId"

$env:ARM_CLIENT_ID=$sp.appId
$env:ARM_CLIENT_SECRET=$sp.password
$env:ARM_TENANT_ID=$tenantId
$env:ARM_SUBSCRIPTION_ID=$subId
```

보안 주의:
- 문서/채팅/로그에 `ARM_CLIENT_SECRET` 실값을 남기지 않는다.
- 실값 노출 이력이 있으면 즉시 Secret 재발급 후 이전 값을 폐기한다.

아래는 데브옵스 포털에서 PAT 생성 후 윈도우 파워셀에서 아래와 같이 수동으로 설정.
```powershell
$env:AZDO_PERSONAL_ACCESS_TOKEN = "<ado-pat>"
```
### 1.2 환경변수 설정

```powershell
$env:AZDO_PERSONAL_ACCESS_TOKEN = "<ado-pat>"
$env:ARM_CLIENT_ID = "<sp-client-id>"
$env:ARM_CLIENT_SECRET = "<sp-client-secret>"
$env:ARM_TENANT_ID = "<tenant-id>"
$env:ARM_SUBSCRIPTION_ID = "<subscription-id>"
```

검증:
```powershell
Set-Location C:/Workspace/IWON-vm-lab/gitops/terraform/azuredevops-bootstrap
Write-Host "AZDO_PERSONAL_ACCESS_TOKEN:" ($(if($env:AZDO_PERSONAL_ACCESS_TOKEN){'SET'}else{'NOT_SET'}))
Write-Host "ARM_CLIENT_ID:" ($(if($env:ARM_CLIENT_ID){'SET'}else{'NOT_SET'}))
Write-Host "ARM_CLIENT_SECRET:" ($(if($env:ARM_CLIENT_SECRET){'SET'}else{'NOT_SET'}))
Write-Host "ARM_TENANT_ID:" ($(if($env:ARM_TENANT_ID){'SET'}else{'NOT_SET'}))
Write-Host "ARM_SUBSCRIPTION_ID:" ($(if($env:ARM_SUBSCRIPTION_ID){'SET'}else{'NOT_SET'}))
```

### 1.3 Terraform 리소스 생성

1. tfvars 준비
```powershell
Set-Location C:/Workspace/IWON-vm-lab/gitops/terraform/azuredevops-bootstrap
Copy-Item terraform.tfvars.example terraform.tfvars
```

2. 필요 옵션 활성화 (`terraform.tfvars`)
- `create_project` (기존 프로젝트 재사용이면 false)
- `create_service_connection = true`
- `create_pipeline = true`
- `azure_subscription_name` 값 입력
- `github_pat` 입력(Repo 타입 GitHub인 경우)

3. 실행
```powershell
terraform init -input=false
terraform validate
terraform plan -input=false -out tfplan
terraform apply -auto-approve tfplan
```

4. 출력 확인
```powershell
terraform output project_id
terraform output feed_id
terraform output service_connection_id
terraform output pipeline_id
```

**현재 tfvars 기준으로 create_pipeline, create_service_connection은 아직 비활성이라 Pipeline ID는 아직 없음**
현재 프로젝트/피드 생성까지 완료된 상태


후속 조치:
- `terraform output pipeline_id` 값을 GitHub `ADO_PIPELINE_ID` 시크릿에 등록

### 1.4 Ansible 배포(YAML 기반) 실행

대상 YAML:
- `gitops/ansible/azure-pipelines-vm.yml`
- `gitops/ansible/deploy-playbook.yml`
- `gitops/ansible/tasks/deploy-*.yml`

실행 방식 A (권장): Azure DevOps Pipeline Run
1. Azure DevOps > Pipelines > `iwon-vm-cd` > Run pipeline
2. 파라미터 입력
- `runTerraform`: 일반 배포는 `false`
- `deployTarget`: `web|was|app|integration`
- `mavenPackageDefinition`: 대상 패키지명
- `mavenPackageVersion`: 고정 버전
- `artifactPattern`: web=`*.zip`, 나머지=`*.jar`

실행 방식 B: GitHub Actions에서 REST API로 자동 호출
- CI 성공 후 ADO Pipeline Runs API 호출
- 파라미터를 위와 동일하게 전달

### 1.5 결과 검증

1. Feed 다운로드 성공 여부
2. 아티팩트 경로 검증(find 실패 시 즉시 실패 처리)
3. 배포 대상 서비스 상태 확인
- web: nginx reload 및 endpoint 확인
- was/app/integration: systemd restart 및 health/log 확인

---

## 2. Azure DevOps Portal에서 해야 할 절차 (실행순서: 2단계)

현재 사용자 상태 반영: 기본 설정만 되어 있고 GitHub 연결은 안 되어 있으므로, 아래를 순차 수행한다.

### 2.1 Organization / Project 확인

1. Organization: `iteyes-ito` 확인
2. Project: `iwon-smart-ops` 확인

검증 기준:
- Project URL 접근 가능
- Project Settings 접근 가능

### 2.2 PAT 생성 (GitHub Actions 호출용)

1. Azure DevOps 우측 상단 사용자 메뉴 > Personal access tokens
2. New Token 생성
3. 최소 권한 권장:
- Pipelines: Read & execute
- Artifacts: Read & write
- (필요 시) Build: Read & execute
4. 만료 정책은 PoC는 단기, 운영은 순환 정책 적용

이 단계에서 확보할 값:
- `ADO_PAT` (GitHub 시크릿으로 등록)

### 2.3 GitHub 연결(Service Connection) 생성

경로:
- Project Settings > Service connections > New service connection

생성 대상:
1. GitHub Service Connection
- 용도: Azure Pipeline이 gitops 저장소의 YAML 소스를 읽기 위해 사용

2. Azure Resource Manager Service Connection
- 용도: Terraform/AzureCLI/배포 작업에서 Azure 리소스 접근

이 단계에서 필요한 값(ARM - Azure Resource Manager 연결 시 필요):
1. `ARM_CLIENT_ID`
2. `ARM_CLIENT_SECRET`
3. `ARM_TENANT_ID`
4. `ARM_SUBSCRIPTION_ID`

ARM 값 확보 절차/명령은 IaC 실행 단계인 1.1.1에서 수행한다.

### 2.4 Pipeline 등록

1. Pipelines > New Pipeline
2. Source: GitHub 선택 후 gitops 저장소 연결
3. YAML 경로 지정: `gitops/ansible/azure-pipelines-vm.yml`
4. Pipeline 이름 확인(예: `iwon-vm-cd`)
5. 최초 저장 후 ID 확인

확보할 값:
- `ADO_PIPELINE_ID`

역주입 작업:
- GitHub 각 저장소에 `ADO_PIPELINE_ID` 등록

### 2.5 변수/시크릿/Secure File 점검

1. Pipeline 변수 점검
- `AZURE_SERVICE_CONNECTION`
- `TFSTATE_RG`
- `TFSTATE_STORAGE`
- `ANSIBLE_SSH_PRIVATE_KEY_SECURE_FILE`

2. Library/Variable Group 사용 시 연결 여부 확인
3. Secure Files에 SSH 키 등록

검증 기준:
- Pipeline 편집 화면에서 변수 참조 오류 없음
- 권한(Authorize resources) 완료

---

## 3. GitHub에서 해야 할 절차 (실행순서: 3단계, 마지막)

주의: 이 단계는 Azure DevOps에서 발급한 정보(특히 PAT, Pipeline ID)가 필요하므로 1번/2번 절차와 연동된다.

### 3.1 저장소별 워크플로우 파일 배치

1. Web/WAS 단일 저장소(IWonPaymentWeb)
- `.github/workflows/deploy-web.yml`
- `.github/workflows/deploy-was.yml`

2. App 저장소(IWonPaymentApp)
- `.github/workflows/deploy-app.yml`

3. Integration 저장소(IWonPaymentIntegration)
- `.github/workflows/deploy-integration.yml`

검증 기준:
- web는 `*.zip`, was/app/integration은 `*.jar`를 publish 하도록 설정
- main 머지 기준 path filter가 서비스별로 분리되어야 함

### 3.2 GitHub Secrets 등록

각 저장소에 아래 시크릿 등록:
1. `ADO_ORG` (예: `iteyes-ito`)
2. `ADO_PROJECT` (예: `iwon-smart-ops`)
3. `ADO_PAT` (Azure DevOps PAT)
4. `ADO_PIPELINE_ID` (Azure DevOps Pipeline ID)

등록 위치:
- GitHub Repository > Settings > Secrets and variables > Actions > New repository secret

중요:
- `ADO_PAT`와 `ADO_PIPELINE_ID`는 1번/2번 절차에서 생성 후 역주입한다.

### 3.3 브랜치/실행 정책

1. `main` 보호 규칙 설정
2. PR 머지 방식 통일(merge/squash 중 팀 기준 1개)
3. Actions 권한 최소화(`Read repository contents` + 필요한 항목만)

검증 기준:
- main 머지 시 해당 워크플로우가 자동 시작
- Feed publish 이후 ADO REST API 호출 단계가 실행

---

## 4. 단계별 완료 기준

### 4.1 GitHub 완료 기준
1. 저장소별 워크플로우 파일 생성
2. `ADO_ORG`, `ADO_PROJECT`, `ADO_PAT`, `ADO_PIPELINE_ID` 등록
3. main 머지 시 CI 동작 확인

### 4.2 Azure DevOps 완료 기준
1. GitHub/AzureRM Service Connection 생성 완료
2. `gitops/ansible/azure-pipelines-vm.yml` 기반 파이프라인 등록 완료
3. Pipeline ID 확보 완료

### 4.3 Terraform/Ansible 완료 기준
1. `terraform apply` 성공
2. `terraform output pipeline_id` 확인 및 GitHub 반영 완료
3. 파이프라인 1회 수동 실행 성공(대상 1개 이상)

---

## 5. 이번 상태에 대한 즉시 실행 우선순위

현재 상태(깃헙 미설정, 데브옵스 기본만 설정, `create_project=true`)를 기준으로 다음 순서로 진행:
1. Terraform 단계(1장) 먼저 수행: `plan -> apply -> output`으로 Project/Feed/Pipeline ID 확보
2. Azure DevOps Portal 단계(2장) 수행: Service Connection/변수/Secure File/Authorize resources 점검
3. GitHub 단계(3장) 수행: 워크플로우 파일 반영 + `ADO_PAT`/`ADO_PIPELINE_ID` 시크릿 등록
4. ADO Pipeline 수동 1회 실행 후 정상 확인
5. 이후 GitHub main 머지 기반 자동 실행 전환
