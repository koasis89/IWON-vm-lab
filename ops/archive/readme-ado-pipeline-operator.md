# Azure OPS 배포 가이드 (운영자용)

이 문서는 OPS 운영 담당자를 위한 설정/운영 절차를 설명합니다.

## 1. 운영 범위

- Azure DevOps 파이프라인 구성 및 권한 관리
- PAT 발급 정책 및 만료 관리
- 배포 파라미터 정책 관리
- 실패 원인 분석 및 복구
- 개발자 지원

## 2. 핵심 파일

- `ops/azure-pipelines-vm.yml`
- `deploy.sh`
- `ops/scripts/deploy.sh`
- `ops/ansible/site-app.yml`
- `ops/scripts/generate_inventory_from_tf.py`
- `ops/scripts/reconnect-ado-pipeline.ps1`

## 3. 초기 셋업 체크리스트

0. IaC/수동 범위 분리 확인
  - IaC: `vm-azure/*.tf`, `ops/azure-pipelines-vm.yml`, `ops/ansible/*.yml`
  - 수동: Azure DevOps Organization/Project/Service Connection/Environment 승인/권한 정책
1. Service Connection 준비
2. Secure File(SSH private key) 등록
3. 필수 변수 설정
   - AZURE_SERVICE_CONNECTION
   - ANSIBLE_SSH_PRIVATE_KEY_SECURE_FILE
   - TFSTATE_RG
   - TFSTATE_STORAGE
4. Environment 승인 정책 확인
5. 대상 파이프라인 YAML 경로 확인
6. 파이프라인 ID 확정

## 3.2 Self-hosted Agent 자동 설치

자동 설치 플레이북:
- `ops/ansible/install-ado-agent.yml`

필수 변수:
- `ado_url` (예: `https://dev.azure.com/iteyes-ito/`)
- `ado_pool` (예: `iwon-selfhosted-pool`)
- `ado_pat` (Agent 등록 권한 PAT)

실행 예시:

```bash
ansible-playbook -i <inventory> ops/ansible/install-ado-agent.yml \
  --limit bastion01 \
  --extra-vars "ado_url=https://dev.azure.com/<org> ado_pool=iwon-selfhosted-pool ado_pat=<PAT>"
```

검증:
1. Azure DevOps Agent Pool에서 Online 확인
2. 대상 VM에서 `svc.sh status` 확인
3. 테스트 파이프라인 1회 실행

## 3.1 Azure 포털 운영 체크

1. 운영 구독/리소스 그룹 대상 확인
2. VM/네트워크/스토리지 상태 확인
3. Service Connection 서비스 주체 RBAC 확인
4. tfstate 저장소 접근 및 잠금 상태 확인
5. Key Vault 시크릿/인증서 만료 확인
6. Azure Monitor 경고 상태 확인

## 4. 개발자 배포 호출 방식 (PAT)

개발자에게 아래 4개 값을 전달합니다.

- `ADO_ORG`
- `ADO_PROJECT`
- `ADO_PIPELINE_ID`
- `ADO_PAT`

PAT 권한:
- Build: Read & Execute

포털/CLI 역할 분리:
- Azure DevOps 포털에서 수행: PAT 발급, 파이프라인 ID 확인
- 로컬 CLI에서 수행: `deploy.conf` 생성/배포

권장 전달 방식(deploy.conf):
1. `bash ops/scripts/make-deploy-conf.sh` 실행
2. 입력값(`ADO_ORG`, `ADO_PROJECT`, `ADO_PIPELINE_ID`, `ADO_PAT`) 입력
3. 생성된 `deploy.conf` 권한 600 확인
4. 저장소 커밋 금지
5. 안전한 채널로 개발자에게 전달
6. PAT 교체 시 `deploy.conf` 재배포

운영 권장:
- 개인 PAT 대신 전용 서비스 계정 PAT 사용
- 만료 주기 운영 캘린더 등록
- 유출 시 즉시 폐기/재발급

## 5. 파이프라인 재연결

대상 YAML은 `ops/azure-pipelines-vm.yml`입니다.

```powershell
pwsh ./ops/scripts/reconnect-ado-pipeline.ps1 \
  -Organization "https://dev.azure.com/<org>" \
  -Project "<project>" \
  -PipelineName "<pipeline-name>"
```

## 6. 운영 기본 정책

- 개발자 기본 실행값은 `ops/scripts/ops-defaults.env`에서 중앙 관리
- 파이프라인은 실행 초기에 기본값 로드 후 semver 검증 수행
- 파이프라인 자동 트리거는 사용하지 않음(`trigger: none`)
- Terraform 반영은 변경 요청 시에만 허용
- DB 작업은 배포 파이프라인에서 제외
- 개발자 배포는 `bash deploy.sh`로만 수행
- Feed-only 정책: 소스 빌드 단계를 파이프라인에서 수행하지 않음

업로드 자동화 표준:
- `bash ops/scripts/publish-universal-package.sh`

## 7. 실패 대응 표준

1. 실패 단계 식별
2. 로그 근거 수집
3. 재시도 가능 여부 판단
4. 권한/연결/아티팩트 경로 확인
5. 필요 시 개발자에게 재배포 요청

## 8. 운영자 참고 문서

- Day-1 통합 구축: [ops/docs/readme-ado-day1.md](readme-ado-day1.md)
- 운영 체크리스트: [ops/docs/readme-ado-ts-chklist.md](readme-ado-ts-chklist.md)
- Terraform 단계: [ops/docs/readme-ado-step1-terraform.md](readme-ado-step1-terraform.md)
- Ansible 단계: [ops/docs/readme-ado-step2-ansible.md](readme-ado-step2-ansible.md)
- 릴리즈 산출물: [ops/docs/readme-ado-step3-release.md](readme-ado-step3-release.md)
