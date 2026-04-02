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

2. Library/Variable Group(`iwon-smart-ops-vg`) 사용 시 연결 여부 확인
	- 권장 변수 추가:
	  - `ANSIBLE_SSH_PRIVATE_KEY_SECURE_FILE = id_rsa`
1ㅂ	ㅂ	ㅂ		ㅂ	`1	11ㅂ1	1````````````````````````ㅂㅂㅁㅁㅂ	ㅂㄴㄴㄴㄴㄴㅋㅋㅁㄴㄵㅂ			11	````````````````111``ㅂㅂ11	  - `TFSTATE_RG = <backend-rg>`
	  - `TFSTATE_STORAGE = <backend-storage-account>`
3. Secure Files에 SSH 키 등록
	- 파일명은 `id_rsa`로 업로드(파이프라인 기본값과 동일)
	- 파이프라인의 `InstallSSHKey@0`는 `sshKeySecureFile: $(ANSIBLE_SSH_PRIVATE_KEY_SECURE_FILE)`를 사용

주의:
1. `AzureCLI@2`의 `azureSubscription` 입력은 실행 전 validation 단계에서 해석되므로 변수(`$(AZURE_SERVICE_CONNECTION)`) 대신 실제 Service Connection 이름을 직접 사용한다.
2. 현재 기준 하드코딩 값은 `iwon-smart-ops-sc` 이다.

정상 등록 방법:
1. Azure DevOps 포털 > Pipelines > Library > Secure files 에 `id_rsa` 업로드
2. 파이프라인 변수 `ANSIBLE_SSH_PRIVATE_KEY_SECURE_FILE` 값을 `id_rsa`로 설정
3. 첫 실행 시 리소스 권한 Authorize
4. 재실행 후 `InstallSSHKey` 단계 통과 확인

검증 기준:
- Pipeline 편집 화면에서 변수 참조 오류 없음
- 권한(Authorize resources) 완료

---

## 3. GitHub에서 해야 할 절차 

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

---

## 6. 실제 운영 전환 기준: 소스 저장소별 GitHub Actions 적용 순서

이 절차는 1단계(Terraform)와 2단계(ADO Portal)가 완료된 이후 수행한다.  
대상 저장소: `IWonPaymentWeb`, `IWonPaymentApp`, `IWonPaymentIntegration`

---

### 6.0 사전 조건 확인 (착수 전 필수)

| 항목 | 확인 방법 | 기대값 |
|---|---|---|
| ADO Pipeline ID 확보 | `terraform output pipeline_id` | 숫자 (예: `2`) |
| Azure Artifacts Feed 정상 | ADO > Artifacts > `iwon-smart-feed` | Feed 조회 가능 |
| ADO PAT 발급 완료 | 2.2절에서 생성 | Pipelines R&E + Artifacts R&W |
| Service Connection 준비 | `az devops service-endpoint list` → isReady=True | `iwon-smart-ops-sc` |
| 소스 저장소 Admin 또는 Write 권한 | GitHub 저장소 Settings 접근 가능 여부 | Secrets/Variables 탭 열림 |

착수 차단 조건:
- `ADO_PIPELINE_ID`가 없으면 REST API 호출 대상이 없으므로 3단계를 착수할 수 없다.
- Azure Artifacts Feed가 없으면 `publish` 단계에서 즉시 실패한다.

---

### 6.1 build.gradle 공통 설정 (maven-publish)

모든 소스 저장소에 아래 설정을 `build.gradle`에 적용한다.  
`publishing` 블록이 이미 있으면 `url`과 `credentials` 항목만 확인/교체한다.

```gradle
plugins {
    id 'java'
    id 'maven-publish'
}

publishing {
    publications {
        mavenJava(MavenPublication) {
            from components.java
            groupId = 'com.iteyes.smart'
            // artifactId는 각 모듈별로 지정 (아래 6.2~6.4 참조)
            artifactId = project.name
            version = System.getenv("APP_VERSION") ?: "0.0.0-local"
        }
    }
    repositories {
        maven {
            url 'https://pkgs.dev.azure.com/iteyes-ito/iwon-smart-ops/_packaging/iwon-smart-feed/maven/v1'
            credentials {
                username = "AZURE_DEVOPS_PAT"
                password = System.getenv("AZURE_ARTIFACTS_ENV_ACCESS_TOKEN")
            }
        }
    }
}
```

주의:
- `AZURE_ARTIFACTS_ENV_ACCESS_TOKEN`은 GitHub Secrets의 `ADO_PAT` 값으로 채운다.
- `APP_VERSION`은 GitHub Actions 워크플로우 내에서 `$GITHUB_ENV`로 주입한다 (예: `1.0.0-main.7c2d9a1`).
- `0.0.0-local`은 로컬 수동 빌드 시 버전 미설정 식별용이다. 실제 배포에는 사용되지 않는다.

---

### 6.2 IWonPaymentWeb 저장소 (web + was 폴더 분리)

#### 6.2.1 build.gradle 모듈 artifactId 지정

`web/build.gradle`:
```gradle
publishing {
    publications {
        mavenJava(MavenPublication) {
            artifactId = 'smart-web'
        }
    }
}
```

`was/build.gradle`:
```gradle
publishing {
    publications {
        mavenJava(MavenPublication) {
            artifactId = 'smart-was'
        }
    }
}
```

#### 6.2.2 시크릿 등록 (GitHub > Settings > Secrets and variables > Actions)

| 시크릿 이름 | 값 | 비고 |
|---|---|---|
| `ADO_PAT` | Azure DevOps PAT | Pipelines R&E + Artifacts R&W |
| `ADO_PIPELINE_ID` | `2` (terraform output 기준) | 파이프라인 ID |

고정값(변수 또는 시크릿 중 선택):
- `ADO_ORG = iteyes-ito`
- `ADO_PROJECT = iwon-smart-ops`
- Secrets 대신 Actions > Variables에 등록 가능 (비민감 값)

#### 6.2.3 `.github/workflows/deploy-web.yml` 생성

```yaml
name: Deploy Web Artifact

on:
  push:
    branches: [ "main" ]
    paths:
      - "web/**"

jobs:
  build-publish-trigger:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    env:
      ADO_ORG: iteyes-ito
      ADO_PROJECT: iwon-smart-ops
      ADO_PIPELINE_ID: ${{ secrets.ADO_PIPELINE_ID }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Compute immutable version
        run: |
          SHORT_SHA=$(echo "${GITHUB_SHA}" | cut -c1-7)
          echo "APP_VERSION=1.0.0-main.${SHORT_SHA}" >> "$GITHUB_ENV"

      - name: Build web module
        run: chmod +x gradlew && ./gradlew :web:build -x test

      - name: Publish web package to Azure Artifacts
        run: ./gradlew :web:publish
        env:
          APP_VERSION: ${{ env.APP_VERSION }}
          AZURE_ARTIFACTS_ENV_ACCESS_TOKEN: ${{ secrets.ADO_PAT }}

      - name: Trigger Azure DevOps deploy (web)
        env:
          ADO_PAT: ${{ secrets.ADO_PAT }}
        run: |
          set -euo pipefail
          API_URL="https://dev.azure.com/${ADO_ORG}/${ADO_PROJECT}/_apis/pipelines/${ADO_PIPELINE_ID}/runs?api-version=7.1"
          cat > run-pipeline.json <<EOF
          {
            "resources": {
              "repositories": {
                "self": {
                  "refName": "refs/heads/main"
                }
              }
            },
            "templateParameters": {
              "runTerraform": "false",
              "deployTarget": "web",
              "artifactFeedName": "iwon-smart-feed",
              "artifactFeedView": "",
              "mavenPackageDefinition": "com.iteyes.smart:smart-web",
              "mavenPackageVersion": "${APP_VERSION}",
              "artifactPattern": "*.zip"
            }
          }
          EOF
          RESPONSE=$(curl --fail --silent --show-error \
            -u ":${ADO_PAT}" \
            -H "Content-Type: application/json" \
            -X POST \
            --data @run-pipeline.json \
            "${API_URL}")
          echo "ADO Pipeline Run ID: $(echo "${RESPONSE}" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("id","unknown"))')"
```

#### 6.2.4 `.github/workflows/deploy-was.yml` 생성

```yaml
name: Deploy WAS Artifact

on:
  push:
    branches: [ "main" ]
    paths:
      - "was/**"

jobs:
  build-publish-trigger:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    env:
      ADO_ORG: iteyes-ito
      ADO_PROJECT: iwon-smart-ops
      ADO_PIPELINE_ID: ${{ secrets.ADO_PIPELINE_ID }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Compute immutable version
        run: |
          SHORT_SHA=$(echo "${GITHUB_SHA}" | cut -c1-7)
          echo "APP_VERSION=1.0.0-main.${SHORT_SHA}" >> "$GITHUB_ENV"

      - name: Build was module
        run: chmod +x gradlew && ./gradlew :was:build -x test

      - name: Publish was package to Azure Artifacts
        run: ./gradlew :was:publish
        env:
          APP_VERSION: ${{ env.APP_VERSION }}
          AZURE_ARTIFACTS_ENV_ACCESS_TOKEN: ${{ secrets.ADO_PAT }}

      - name: Trigger Azure DevOps deploy (was)
        env:
          ADO_PAT: ${{ secrets.ADO_PAT }}
        run: |
          set -euo pipefail
          API_URL="https://dev.azure.com/${ADO_ORG}/${ADO_PROJECT}/_apis/pipelines/${ADO_PIPELINE_ID}/runs?api-version=7.1"
          cat > run-pipeline.json <<EOF
          {
            "resources": {
              "repositories": {
                "self": {
                  "refName": "refs/heads/main"
                }
              }
            },
            "templateParameters": {
              "runTerraform": "false",
              "deployTarget": "was",
              "artifactFeedName": "iwon-smart-feed",
              "artifactFeedView": "",
              "mavenPackageDefinition": "com.iteyes.smart:smart-was",
              "mavenPackageVersion": "${APP_VERSION}",
              "artifactPattern": "*.jar"
            }
          }
          EOF
          RESPONSE=$(curl --fail --silent --show-error \
            -u ":${ADO_PAT}" \
            -H "Content-Type: application/json" \
            -X POST \
            --data @run-pipeline.json \
            "${API_URL}")
          echo "ADO Pipeline Run ID: $(echo "${RESPONSE}" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("id","unknown"))')"
```

---

### 6.3 IWonPaymentApp 저장소

#### 6.3.1 build.gradle artifactId 지정

```gradle
publishing {
    publications {
        mavenJava(MavenPublication) {
            artifactId = 'smart-app'
        }
    }
}
```

#### 6.3.2 시크릿 등록

IWonPaymentWeb와 동일 항목(`ADO_PAT`, `ADO_PIPELINE_ID`).

#### 6.3.3 `.github/workflows/deploy-app.yml` 생성

```yaml
name: Deploy App Artifact

on:
  push:
    branches: [ "main" ]

jobs:
  build-publish-trigger:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    env:
      ADO_ORG: iteyes-ito
      ADO_PROJECT: iwon-smart-ops
      ADO_PIPELINE_ID: ${{ secrets.ADO_PIPELINE_ID }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Compute immutable version
        run: |
          SHORT_SHA=$(echo "${GITHUB_SHA}" | cut -c1-7)
          echo "APP_VERSION=1.0.0-main.${SHORT_SHA}" >> "$GITHUB_ENV"

      - name: Build
        run: chmod +x gradlew && ./gradlew build -x test

      - name: Publish app package to Azure Artifacts
        run: ./gradlew publish
        env:
          APP_VERSION: ${{ env.APP_VERSION }}
          AZURE_ARTIFACTS_ENV_ACCESS_TOKEN: ${{ secrets.ADO_PAT }}

      - name: Trigger Azure DevOps deploy (app)
        env:
          ADO_PAT: ${{ secrets.ADO_PAT }}
        run: |
          set -euo pipefail
          API_URL="https://dev.azure.com/${ADO_ORG}/${ADO_PROJECT}/_apis/pipelines/${ADO_PIPELINE_ID}/runs?api-version=7.1"
          cat > run-pipeline.json <<EOF
          {
            "resources": {
              "repositories": {
                "self": {
                  "refName": "refs/heads/main"
                }
              }
            },
            "templateParameters": {
              "runTerraform": "false",
              "deployTarget": "app",
              "artifactFeedName": "iwon-smart-feed",
              "artifactFeedView": "",
              "mavenPackageDefinition": "com.iteyes.smart:smart-app",
              "mavenPackageVersion": "${APP_VERSION}",
              "artifactPattern": "*.jar"
            }
          }
          EOF
          RESPONSE=$(curl --fail --silent --show-error \
            -u ":${ADO_PAT}" \
            -H "Content-Type: application/json" \
            -X POST \
            --data @run-pipeline.json \
            "${API_URL}")
          echo "ADO Pipeline Run ID: $(echo "${RESPONSE}" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("id","unknown"))')"
```

---

### 6.4 IWonPaymentIntegration 저장소

#### 6.4.1 build.gradle artifactId 지정

```gradle
publishing {
    publications {
        mavenJava(MavenPublication) {
            artifactId = 'smart-integration'
        }
    }
}
```

#### 6.4.2 시크릿 등록

IWonPaymentWeb와 동일 항목(`ADO_PAT`, `ADO_PIPELINE_ID`).

#### 6.4.3 `.github/workflows/deploy-integration.yml` 생성

```yaml
name: Deploy Integration Artifact

on:
  push:
    branches: [ "main" ]

jobs:
  build-publish-trigger:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    env:
      ADO_ORG: iteyes-ito
      ADO_PROJECT: iwon-smart-ops
      ADO_PIPELINE_ID: ${{ secrets.ADO_PIPELINE_ID }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Compute immutable version
        run: |
          SHORT_SHA=$(echo "${GITHUB_SHA}" | cut -c1-7)
          echo "APP_VERSION=1.0.0-main.${SHORT_SHA}" >> "$GITHUB_ENV"

      - name: Build
        run: chmod +x gradlew && ./gradlew build -x test

      - name: Publish integration package to Azure Artifacts
        run: ./gradlew publish
        env:
          APP_VERSION: ${{ env.APP_VERSION }}
          AZURE_ARTIFACTS_ENV_ACCESS_TOKEN: ${{ secrets.ADO_PAT }}

      - name: Trigger Azure DevOps deploy (integration)
        env:
          ADO_PAT: ${{ secrets.ADO_PAT }}
        run: |
          set -euo pipefail
          API_URL="https://dev.azure.com/${ADO_ORG}/${ADO_PROJECT}/_apis/pipelines/${ADO_PIPELINE_ID}/runs?api-version=7.1"
          cat > run-pipeline.json <<EOF
          {
            "resources": {
              "repositories": {
                "self": {
                  "refName": "refs/heads/main"
                }
              }
            },
            "templateParameters": {
              "runTerraform": "false",
              "deployTarget": "integration",
              "artifactFeedName": "iwon-smart-feed",
              "artifactFeedView": "",
              "mavenPackageDefinition": "com.iteyes.smart:smart-integration",
              "mavenPackageVersion": "${APP_VERSION}",
              "artifactPattern": "*.jar"
            }
          }
          EOF
          RESPONSE=$(curl --fail --silent --show-error \
            -u ":${ADO_PAT}" \
            -H "Content-Type: application/json" \
            -X POST \
            --data @run-pipeline.json \
            "${API_URL}")
          echo "ADO Pipeline Run ID: $(echo "${RESPONSE}" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("id","unknown"))')"
```

---

### 6.5 PAT 발급 권한 기준 (운영 전환 시 필수)

| PAT 용도 | 필요 권한 범위 | 권장 만료 |
|---|---|---|
| Azure Artifacts publish | `Artifacts: Read & Write` | 90일, 자동 순환 |
| ADO Pipeline REST 호출 | `Pipelines: Read & execute` | 90일, 자동 순환 |
| GitHub 서비스 커넥션 (iwon-github-sc) | `repo: full` 또는 `repo: status` | 90일, 자동 순환 |

PoC에서는 위 3가지 권한을 단일 PAT에 통합 가능하다.  
운영 전환 시에는 publish 전용 PAT와 pipeline 호출 전용 PAT를 분리한다.

PAT 순환 절차:
1. ADO Portal에서 신규 PAT 발급
2. 각 소스 저장소 GitHub Secrets의 `ADO_PAT` 값을 신규 PAT로 교체
3. 구 PAT 즉시 revoke

---

### 6.6 브랜치 보호 규칙 (운영 전환 시 필수)

각 소스 저장소(IWonPaymentWeb / IWonPaymentApp / IWonPaymentIntegration) 공통 적용:

1. `main` 브랜치 보호 설정 경로:
   - GitHub > Repository > Settings > Branches > Add branch protection rule
   - Branch name pattern: `main`

2. 권장 설정:

| 항목 | 설정값 | 이유 |
|---|---|---|
| Require a pull request before merging | ON | 직접 push 차단 |
| Require approvals | 1명 이상 | 코드 리뷰 보장 |
| Require status checks to pass before merging | ON | CI 통과 강제 |
| Do not allow bypassing the above settings | ON | Admin 포함 우회 차단 |

PoC 단계에서는 status checks 항목을 먼저 OFF로 유지하고, 워크플로우 정상 동작 확인 후 ON으로 전환한다.

---

### 6.7 적용 순서 요약 (저장소별 작업 체크리스트)

아래 체크리스트를 저장소별로 순서대로 수행한다.

#### IWonPaymentWeb

- [ ] 1. `terraform output pipeline_id` 값 확인 → `ADO_PIPELINE_ID = 2` 확보
- [ ] 2. ADO PAT 발급 (Artifacts R&W + Pipelines R&E)
- [ ] 3. GitHub Secrets 등록: `ADO_PAT`, `ADO_PIPELINE_ID`
- [ ] 4. GitHub Variables 등록 (선택): `ADO_ORG=iteyes-ito`, `ADO_PROJECT=iwon-smart-ops`
- [ ] 5. `web/build.gradle` 및 `was/build.gradle`에 `maven-publish` 설정 추가/확인
- [ ] 6. `.github/workflows/deploy-web.yml` 생성 및 커밋
- [ ] 7. `.github/workflows/deploy-was.yml` 생성 및 커밋
- [ ] 8. `web/**` 경로 파일 변경 후 main 머지 → deploy-web.yml 실행 확인
- [ ] 9. ADO Pipeline 실행 로그에서 `deployTarget=web` 배포 정상 확인
- [ ] 10. `was/**` 경로 파일 변경 후 main 머지 → deploy-was.yml 실행 확인
- [ ] 11. ADO Pipeline 실행 로그에서 `deployTarget=was` 배포 정상 확인
- [ ] 12. (운영 전환 시) main 브랜치 보호 규칙 설정

#### IWonPaymentApp

- [ ] 1. GitHub Secrets 등록: `ADO_PAT`, `ADO_PIPELINE_ID`
- [ ] 2. `build.gradle`에 `maven-publish` 설정 추가/확인 (`artifactId = smart-app`)
- [ ] 3. `.github/workflows/deploy-app.yml` 생성 및 커밋
- [ ] 4. main 머지 후 Actions 탭에서 워크플로우 실행 확인
- [ ] 5. ADO Pipeline 로그에서 `deployTarget=app` 배포 정상 확인
- [ ] 6. (운영 전환 시) main 브랜치 보호 규칙 설정

#### IWonPaymentIntegration

- [ ] 1. GitHub Secrets 등록: `ADO_PAT`, `ADO_PIPELINE_ID`
- [ ] 2. `build.gradle`에 `maven-publish` 설정 추가/확인 (`artifactId = smart-integration`)
- [ ] 3. `.github/workflows/deploy-integration.yml` 생성 및 커밋
- [ ] 4. main 머지 후 Actions 탭에서 워크플로우 실행 확인
- [ ] 5. ADO Pipeline 로그에서 `deployTarget=integration` 배포 정상 확인
- [ ] 6. (운영 전환 시) main 브랜치 보호 규칙 설정

---

### 6.8 트리거 연결 검증 기준

각 저장소별로 아래 3가지 단계가 순서대로 통과되어야 완료로 간주한다.

| 단계 | 검증 항목 | 확인 위치 |
|---|---|---|
| 1. 빌드 성공 | Gradle build 성공, `-x test` 기준 | GitHub Actions > 해당 워크플로우 로그 |
| 2. Feed publish 성공 | `APP_VERSION` 기준 버전이 Feed에 등록됨 | ADO > Artifacts > `iwon-smart-feed` > 버전 목록 |
| 3. ADO 파이프라인 기동 | curl 호출 후 `Run ID` 반환, ADO에서 실행 내역 확인 | ADO > Pipelines > `iwon-vm-cd` > 최근 실행 |

3단계가 모두 통과하면 GitOps 자동 배포 체인이 정상 연결된 것이다.
