# Azure DevOps Artifacts 중심 운영자 가이드

이 문서는 OPS 운영자를 위한 단일 운영 가이드입니다.

운영 기준:
- Feed-only 배포 (소스 빌드 금지)
- Universal Packages 기본, Maven 허용
- 개발자 직접 Feed 업로드
- 파이프라인은 Feed 다운로드 + Ansible 배포만 수행

## 1. 운영자가 관리할 핵심 파일

- `ops/azure-pipelines-vm.yml`
- `ops/scripts/ops-defaults.env`
- `ops/scripts/publish-universal-package.sh`
- `ops/scripts/artifacts.conf.example`
- `ops/ansible/site-app.yml`
- `ops/ansible/install-ado-agent.yml`

## 2. 운영 설정

1. Azure DevOps 프로젝트/피드 확인
   - Organization: `iteyes-ito`
   - Project: `iwon-ops`
   - Feed: `iwon-feed`
2. 파이프라인 변수 설정
   - `AZURE_SERVICE_CONNECTION`
   - `ANSIBLE_SSH_PRIVATE_KEY_SECURE_FILE`
   - `TFSTATE_RG`, `TFSTATE_STORAGE` (Terraform 사용 시)
3. 중앙 기본값 관리
   - `ops/scripts/ops-defaults.env`에서 기본값 일원화
4. 파이프라인은 수동 실행만 허용 (`trigger: none`)

## 3. 운영 실행 흐름

1. 개발자가 피드에 아티팩트 업로드
2. 운영자가 필요 시 파라미터 점검
3. 개발자/운영자가 `bash deploy.sh`로 실행
4. 파이프라인 동작
   - 기본값 로드 (`ops-defaults.env`)
   - 버전 semver 검증
   - Feed 다운로드 (Universal/Maven)
   - 산출물 검증
   - Ansible 배포

## 4. Feed 및 패키지 정책

필수 구성요소(패키지 내부):
- web 정적 리소스 zip 1종
- was 애플리케이션 jar 1종
- app 애플리케이션 jar 1종
- integration 애플리케이션 jar 1종

파일명은 고정하지 않아도 됩니다. 다만 파이프라인이 실제 파일을 찾을 수 있도록 상대경로 매핑을 반드시 지정해야 합니다.

매핑 기준:
- Universal 기본값: `ops/scripts/ops-defaults.env`
   - 명시 경로(선택): `OPS_DEFAULT_*_RELATIVE`
   - 자동탐색(권장): `OPS_DEFAULT_*_COMPONENT_DIR` + `OPS_DEFAULT_*_FILE_PATTERN`
- Maven 사용 시 실행 파라미터:
   - `webHtmlZipRelative`
   - `wasJarRelative`
   - `appJarRelative`
   - `integrationJarRelative`

운영 권장:
- 파일명이 자주 바뀌는 팀은 `ops-defaults.env`에서 `OPS_DEFAULT_*_RELATIVE`를 비워두고,
   컴포넌트 디렉터리/패턴(`*.zip`, `*.jar`)만 관리합니다.

운영 기본값은 `ops/scripts/ops-defaults.env`에서 관리합니다.

## 5. Universal 업로드 자동화

표준 실행:

```bash
cp ops/scripts/artifacts.conf.example ops/scripts/artifacts.conf
bash ops/scripts/publish-universal-package.sh
```

명시 버전 실행:

```bash
bash ops/scripts/publish-universal-package.sh --version 2026.3.29-main
```

릴리즈 노트:
- 자동 생성 경로: `release/notes/universal-<version>.md`

## 6. Maven 모드 운영

Maven Feed 사용 시 아래 파라미터를 사용합니다.
- `artifactFeedType=maven`
- `artifactFeedName`
- `mavenPackageDefinition`
- `mavenPackageVersion`
- `webHtmlZipRelative`, `wasJarRelative`, `appJarRelative`, `integrationJarRelative`

경로 매핑 템플릿:
- `ops/scripts/maven-path-mapping.template.env`

## 7. Terraform/Ansible 운영 포인트

Terraform(선택):
- `runTerraform=true`일 때만 실행
- `TFSTATE_RG`, `TFSTATE_STORAGE` 필수

Ansible 배포:
- `deployTarget=all|web|was|app|integration|kafka`
- DB 작업은 파이프라인 범위에서 제외

## 8. 보안 원칙

1. PAT는 저장소에 커밋 금지
2. `deploy.conf`, `ops/scripts/artifacts.conf`는 안전 채널로만 배포
3. PAT 권한 분리
   - 배포 실행용
   - 패키지 업로드용
   - Agent 등록용

## 9. 관련 문서

- 개발자용 가이드: [ops/docs/readme-ops-developer-quickstart.md](readme-ops-developer-quickstart.md)
- 개발자 환경설정 가이드: [ops/docs/readme-ado-setup-developer.md](readme-ado-setup-developer.md)
