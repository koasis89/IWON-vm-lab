# 배포 스모크 테스트 가이드 (PowerShell)

이 문서는 `iwon-ops` 프로젝트에서 실제 아티팩트 발행 및 배포 동작을 점검하기 위한 실행 순서를 정리합니다.

## 1. PAT 세션 설정

```powershell
$env:AZURE_DEVOPS_EXT_PAT = "여기에_PAT"
```

## 2. Azure DevOps 기본 컨텍스트 확인

```powershell
az devops configure --list
```

기대값:
- organization: `https://dev.azure.com/iteyes-ito`
- project: `iwon-ops`

## 3. 테스트 산출물 4종 확인

```powershell
Get-Item release\web\html.zip, release\was\app.jar, release\app\app.jar, release\integration\app.jar | Select-Object FullName,Length
```

## 4. Universal 패키지 발행 테스트

```powershell
bash ops/scripts/publish-universal-package.sh --feed iwon-feed --name iwon-ops-bundle --version 2026.3.29-smoke.1
```

## 5. 발행 결과 확인

```powershell
$org="https://dev.azure.com/iteyes-ito"
$project="iwon-ops"
$feed="iwon-feed"
$feedsJson = az devops invoke --organization $org --area packaging --resource feeds --route-parameters project=$project -o json
$feeds = $feedsJson | ConvertFrom-Json
$target = $feeds.value | Where-Object { $_.name -eq $feed } | Select-Object -First 1
az devops invoke --organization $org --area packaging --resource packages --route-parameters project=$project feedId=$($target.id) --query-parameters protocolType=upack includeAllVersions=true --query "value[].{name:name,latestVersion:versions[0].version}" -o table
```

## 6. 배포 파이프라인 확인

```powershell
az pipelines list --organization https://dev.azure.com/iteyes-ito --project iwon-ops --query "[].{id:id,name:name}" -o table
```

## 7. deploy.conf 준비

루트 `deploy.conf` 파일에 아래 값을 설정합니다.

```bash
ADO_ORG="iteyes-ito"
ADO_PROJECT="iwon-ops"
ADO_PIPELINE_ID="<조회한 파이프라인 ID>"
ADO_PAT="<PAT>"
# Optional
# ADO_BRANCH="refs/heads/main"
```

## 8. 배포 실행

```powershell
bash deploy.sh
```

## 9. 실패 시 체크포인트

1. PAT 인증 오류: `$env:AZURE_DEVOPS_EXT_PAT` 재설정 후 재시도
2. Feed/패키지 미존재: 4단계 발행 성공 여부 확인
3. 파이프라인 목록 비어 있음: Azure DevOps에서 `ops/azure-pipelines-vm.yml` 연결 파이프라인 먼저 생성
4. deploy.sh 실패: `deploy.conf` 값(`ADO_PIPELINE_ID`, `ADO_PAT`) 재확인
