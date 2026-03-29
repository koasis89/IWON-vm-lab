# Azure DevOps Day-1 구축 문서 (Feed-only)

이 문서는 운영 1일차에 Feed-only 배포 체계를 구축하는 절차를 설명합니다.

## 1. 범위 정의 (IaC vs 수동)

### 1.1 IaC 범위

현재 저장소에서 자동화되는 범위:
- `ops/azure-pipelines-vm.yml` 파이프라인 정의
- `ops/ansible/site-app.yml` 애플리케이션 배포
- `ops/ansible/install-ado-agent.yml` self-hosted agent 설치 자동화

### 1.2 수동 범위

Day-1에 수동으로 수행해야 하는 범위:
- Azure DevOps Organization/Project 생성
- Artifacts Feed 생성(Universal 기본, Maven 허용)
- Azure Resource Manager Service Connection 생성
- Environment 승인 정책 설정
- PAT 발급 및 만료 정책 설정
- Agent Pool 생성 및 에이전트 등록

## 2. 사전 준비

1. Azure 구독/리소스그룹 접근 권한
2. Azure DevOps Organization/Project 관리자 권한
3. 배포 대상 VM SSH 접근 가능 상태
4. 표준값 확정
   - Organization
   - Project
   - Feed 이름
   - Agent Pool
   - Pipeline 이름

## 3. Day-1 체크리스트

### 3.1 Azure DevOps 기본 구성 (수동)

1. Organization 생성 또는 선택
2. Project 생성
3. Feed 생성
   - Artifacts -> Create Feed
   - 기본 Feed 타입 운영: Universal Packages
4. Service Connection 생성
   - 유형: Azure Resource Manager
   - 배포 대상 구독 권한 확인
5. Environment 생성 및 승인자 등록
6. Pipeline 생성 후 YAML 연결
   - 경로: `ops/azure-pipelines-vm.yml`

### 3.2 인프라 준비 (필요 시)

1. Terraform plan/apply 실행
2. 출력값 검증(리소스/VM/IP)
3. 네트워크 접근 경로 점검

### 3.3 Self-hosted Agent 설치/등록

자동화 플레이북:
- `ops/ansible/install-ado-agent.yml`

필수 변수:
- `ado_url`
- `ado_pool`
- `ado_pat`

실행 예시:

```bash
ansible-playbook -i <inventory> ops/ansible/install-ado-agent.yml \
  --limit bastion01 \
  --extra-vars "ado_url=https://dev.azure.com/<org> ado_pool=iwon-selfhosted-pool ado_pat=<PAT>"
```

검증:
1. Agent Pool에서 Online 확인
2. 대상 VM에서 서비스 상태 확인
3. 테스트 파이프라인 실행

### 3.4 개발자 배포 준비

1. 운영자가 `bash ops/scripts/make-deploy-conf.sh` 실행
2. 생성된 `deploy.conf`를 안전 채널로 전달
3. 개발자는 로컬 빌드 후 Feed 업로드
4. 개발자는 `bash deploy.sh`로 배포 요청

## 4. 권한 체크리스트

1. Service Connection: 배포 리소스 접근 RBAC 보유
2. PAT 최소 권한
   - 배포 실행용: Build Read & Execute
   - Feed 업로드용: Packaging Read & Write
   - Agent 등록용: Agent Pools 관련 권한
3. 저장소 권한: main 반영 정책 준수

## 5. 운영 안정화 체크

1. 파이프라인 자동 트리거 비활성 (`trigger: none`)
2. Feed-only 원칙 유지 (파이프라인 내 소스 빌드 금지)
3. `deploy.conf` 커밋 차단 확인
4. PAT 만료 일정 등록

## 6. 관련 문서

- 아티팩트 가이드: [ops/docs/readme-ado-artifacts.md](readme-ado-artifacts.md)
- 운영자 가이드: [ops/docs/readme-ado-pipeline-operator.md](readme-ado-pipeline-operator.md)
- 개발자 가이드: [ops/docs/readme-ops-developer-quickstart.md](readme-ops-developer-quickstart.md)
- 1페이지 요약: [ops/docs/readme-ops-developer-1page.md](readme-ops-developer-1page.md)
