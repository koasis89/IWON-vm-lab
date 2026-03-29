## 로컬 배포 스크립트 (CLI 호출)

개발자가 Azure 포털에 로그인하지 않고 터미널에서 `bash deploy.sh`를 실행하여 배포를 수동으로 제어하는 방식입니다.

### 🛠️ Azure DevOps에서 할 일
1.  **PAT 생성 (개발자용 또는 공용):**
    * Azure DevOps 우측 상단 `User settings > Personal access tokens` 클릭.
    * **Build: Read & Execute** 권한이 포함된 토큰을 생성합니다.
2.  **Definition ID 확인:**
    * 파이프라인 실행 API에 사용하는 Pipeline ID를 확인합니다.
3.  **전달 정보 표준화:**
    * 개발자에게 아래 값만 전달합니다.
      * `ADO_ORG`
      * `ADO_PROJECT`
      * `ADO_PIPELINE_ID`
      * `ADO_PAT`

### 🛠️ Azure 포털에서 할 일
1.  **배포 대상 리소스 확인:**
    * 배포 대상 구독/리소스 그룹이 운영 환경으로 맞는지 확인합니다.
    * VM, 네트워크, 스토리지 리소스 상태가 정상(Running/Healthy)인지 확인합니다.
2.  **Service Connection 권한 확인:**
    * Azure DevOps Service Connection이 사용하는 서비스 주체에 필요한 RBAC 권한이 있는지 확인합니다.
    * 최소 범위 원칙으로 운영 리소스 그룹 범위 권한을 유지합니다.
3.  **Terraform 상태 저장소 확인(사용 시):**
    * tfstate 저장용 Storage Account/Container 접근 가능 여부를 확인합니다.
    * 잠금/권한 오류가 없는지 확인합니다.
4.  **비밀값/인증서 점검:**
    * Key Vault의 인증서/시크릿 만료 여부를 점검합니다.
    * 배포에 필요한 참조값이 최신인지 확인합니다.
5.  **모니터링/경고 확인:**
    * Azure Monitor 경고 상태를 확인합니다.
    * 배포 직후 확인할 대시보드(App Gateway/VM/App 로그)를 사전 준비합니다.

### 🛠️ GitHub/로컬 스크립트 작성 (`deploy.sh`)
개발자들은 아래 방식으로 실행합니다.

```bash
#!/bin/bash
# deploy.sh

# 1. 환경변수 설정 (OPS가 전달)
export ADO_ORG="ITEYES-ORG"
export ADO_PROJECT="MyProject"
export ADO_PIPELINE_ID="123"
export ADO_PAT="아까_생성한_Azure_DevOps_PAT"
# export ADO_BRANCH="refs/heads/main"  # 선택

# 2. Azure DevOps API 호출 (파이프라인 실행)
echo "🚀 운영 서버 배포를 시작합니다..."

curl -u :$ADO_PAT -X POST \
-H "Content-Type: application/json" \
-d "{ \"resources\": { \"repositories\": { \"self\": { \"refName\": \"refs/heads/main\" } } } }" \
"https://dev.azure.com/$ADO_ORG/$ADO_PROJECT/_apis/pipelines/$ADO_PIPELINE_ID/runs?api-version=7.0"

echo -e "\n✅ 배포 요청이 완료되었습니다. 잠시 후 서버를 확인하세요."
```

> 보안 주의: PAT는 코드 저장소에 커밋하지 않습니다.

---

