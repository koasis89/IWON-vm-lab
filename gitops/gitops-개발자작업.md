# GitOps 개발자 작업 가이드

작성일: 2026-04-03  
적용 저장소: `IWON-vm-lab/gitops`

---

## 0. 문서 목적

이 문서는 **개발자가 소스 저장소를 수정하고 GitHub Actions로 빌드/배포를 연결할 때 필요한 준비사항과 진행 기준**을 정리한다.

핵심 원칙은 아래와 같다.

- 소스 저장소는 **코드/빌드/버전 관리**를 담당한다.
- `IWON-vm-lab/gitops` 는 **배포 정의(YAML/Terraform/Ansible)** 만 중앙 관리한다.
- PoC 산출물은 운영 공용 서비스에 직접 덮어쓰지 않는다.
- 배포 시에는 항상 `deployTarget`, `mavenPackageDefinition`, `mavenPackageVersion` 을 명시한다.

---

## 1. 작업 시작 전 준비 체크리스트

### 1.1 소스 저장소와 배포 대상 매핑

| 소스 위치 | 대상 서비스 | `deployTarget` |
|---|---|---|
| `IWonPaymentWeb/web` | Web | `web` |
| `IWonPaymentWeb/was` | WAS | `was` |
| `IWonPaymentApp` | App | `app` |
| `IWonPaymentIntegration` | Integration | `integration` |

### 1.2 개발 환경 준비

- `git`
- `java 17`
- `gradle` 또는 `./gradlew`
- `ssh`
- 필요 시 `az`

### 1.3 GitHub Secrets 준비
관련된 시크릿 항목의 값은 아키텍트에게 요청한다.
공통 시크릿:

- `ADO_ORG`
- `ADO_PROJECT`
- `ADO_PIPELINE_ID`
- `ADO_PAT`

> `ADO_PAT` 가 채팅/문서/로그에 노출되면 즉시 **폐기(revoke) 후 재발급**한다.

### 1.4 버전 전략

- `latest`, 가변 SNAPSHOT 의존 배포는 지양한다.
- 아래처럼 **불변 버전**을 사용한다.
  - `1.0.0-main.<shortsha>`
  - `1.4.2+build.381`

---

## 2. 권장 진행 순서

1. 소스 저장소에서 기능 수정
2. 로컬 또는 CI에서 빌드/기본 검증
3. GitHub Actions에서 Azure Artifacts Feed publish
4. Azure DevOps에서 `deployTarget`과 버전을 명시해 CD 실행
5. 대상 VM에서 서비스/포트/로그/헬스 확인
6. 이상 시 즉시 이전 고정 버전으로 롤백

---

## 3. 현재 `gitops` 폴더의 target별 구성

현재 `gitops` 는 이미 `web`, `was`, `app`, `integration` 기준으로 분리되어 있다.

| 대상 | ADO 파라미터 | Task 파일 | 적용 Role | 원격 경로/서비스 | 산출물 |
|---|---|---|---|---|---|
| Web | `deployTarget=web` | `gitops/ansible/tasks/deploy-web.yml` | `web` | nginx / 정적 웹 배포 | `*.zip` |
| WAS | `deployTarget=was` | `gitops/ansible/tasks/deploy-was.yml` | `java_service` | `/opt/apps/was`, `was.service` | `*.jar` |
| App | `deployTarget=app` | `gitops/ansible/tasks/deploy-app.yml` | `java_service` | `/opt/apps/app`, `app.service` | `*.jar` |
| Integration | `deployTarget=integration` | `gitops/ansible/tasks/deploy-integration.yml` | `java_service` | `/opt/apps/integration`, `integration.service` | `*.jar` |

### 3.1 target별 점검 포인트

- `web`
  - zip 산출물 확인
  - nginx 설정 반영 확인
  - 외부 URL 응답 확인
- `was`
  - `/opt/apps/was/app.jar` 반영 여부
  - `was.service` 상태 및 `:8080` 확인
  - DB/Kafka 연결 로그 확인
- `app`
  - `/opt/apps/app/app.jar` 반영 여부
  - `app.service` 상태 및 로그 확인
- `integration`
  - `/opt/apps/integration/IWonPaymentIntegration-0.0.1-SNAPSHOT.jar` 반영 여부
  - `integration.service` 상태 및 Kafka 연동 로그 확인

---

## 4. `web/was` 용 GitHub Actions 분리 기준

`IWonPaymentWeb` 저장소는 `web` 과 `was` 가 한 저장소에 공존하므로, **GitHub Actions 를 반드시 2개로 분리**한다.

### 4.1 `deploy-web.yml`

- 트리거 경로: `web/**`
- 고정값:
  - `deployTarget=web`
  - `mavenPackageDefinition=com.iteyes.smart:smart-web`
  - `artifactPattern=*.zip`

### 4.2 `deploy-was.yml`

- 트리거 경로: `was/**`
- 고정값:
  - `deployTarget=was`
  - `mavenPackageDefinition=com.iteyes.smart:smart-was`
  - `artifactPattern=*.jar`

### 4.3 분리 이유

- 동일 저장소여도 배포 대상이 다르다.
- `web` 변경이 `was01` 로 잘못 나가거나, `was` 변경이 `web01` 로 가는 것을 방지해야 한다.
- 운영 안정성을 위해 **workflow 파일 분리 + path 필터 분리 + deployTarget 고정**이 필요하다.

---

## 5. `app/integration` publish/deploy workflow 정리

`IWonPaymentApp`, `IWonPaymentIntegration` 은 저장소별로 하나의 배포 타깃이 명확하므로, 저장소별 workflow 1개씩으로 정리한다.

### 5.1 App

파일 예시:
- `.github/workflows/deploy-app.yml`

고정값:
- `deployTarget=app`
- `mavenPackageDefinition=com.iteyes.smart:smart-app`
- `artifactPattern=*.jar`

흐름:
1. checkout
2. JDK 17 설정
3. 버전 계산
4. `./gradlew build` 또는 `./gradlew publish`
5. Azure Artifacts publish
6. ADO Pipeline REST 호출

### 5.2 Integration

파일 예시:
- `.github/workflows/deploy-integration.yml`

고정값:
- `deployTarget=integration`
- `mavenPackageDefinition=com.iteyes.smart:smart-integration`
- `artifactPattern=*.jar`

추가 확인:
- Kafka 환경변수 연동 여부
- 배포 후 `integration.service` 로그 확인

---

## 6. `deployTarget`별 시크릿/버전 규칙 고정

### 6.1 공통 시크릿 규칙

모든 저장소에서 공통으로 아래 값은 동일하게 유지한다.

| 시크릿 | 값 예시 | 비고 |
|---|---|---|
| `ADO_ORG` | `iteyes-ito` | 고정 |
| `ADO_PROJECT` | `iwon-smart-ops` | 고정 |
| `ADO_PIPELINE_ID` | `2` | 배포 파이프라인 ID |
| `ADO_PAT` | 비공개 | 노출 즉시 폐기 |

### 6.2 타깃별 고정 규칙

| 타깃 | `deployTarget` | 패키지 정의 | 패턴 | 권장 버전 형식 |
|---|---|---|---|---|
| Web | `web` | `com.iteyes.smart:smart-web` | `*.zip` | `1.0.0-web.<shortsha>` |
| WAS | `was` | `com.iteyes.smart:smart-was` | `*.jar` | `1.0.0-was.<shortsha>` |
| App | `app` | `com.iteyes.smart:smart-app` | `*.jar` | `1.0.0-app.<shortsha>` |
| Integration | `integration` | `com.iteyes.smart:smart-integration` | `*.jar` | `1.0.0-int.<shortsha>` |

### 6.3 안전 규칙

- workflow 안에서 `deployTarget` 을 동적으로 바꾸지 않는다.
- repo/폴더별 workflow 에서 값을 **하드고정**한다.
- 운영 배포는 `main` 직접 실험이 아니라 **검증 브랜치 → 승인 → 반영** 순서로 진행한다.
- PoC 배포는 운영 공용 VM/서비스명과 분리한다.

---

## 7. 개발자용 최종 체크리스트

배포 전:
- [ ] 어떤 저장소/폴더를 수정했는지 명확한가?
- [ ] 해당 workflow 의 `deployTarget` 이 고정되어 있는가?
- [ ] `mavenPackageVersion` 이 불변 버전인가?
- [ ] 운영 대상과 PoC 대상을 혼동하지 않았는가?
- [ ] `ADO_PAT` 노출 여부를 점검했는가?

배포 후:
- [ ] ADO run result 확인
- [ ] 대상 서비스 `systemctl status` 확인
- [ ] 포트 리슨 여부 확인
- [ ] 애플리케이션 헬스 및 로그 확인
- [ ] 이상 시 즉시 이전 버전 롤백

---

## 8. GitHub Actions workflow 초안 파일

바로 복사해 사용할 수 있는 초안 파일은 아래 경로에 정리했다.

- `gitops/workflow-templates/deploy-web.yml`
- `gitops/workflow-templates/deploy-was.yml`
- `gitops/workflow-templates/deploy-app.yml`
- `gitops/workflow-templates/deploy-integration.yml`
- `gitops/workflow-templates/README.md`

사용 방법:
1. 각 파일을 대상 저장소의 `.github/workflows/` 로 복사
2. 실제 모듈 경로/빌드 명령(`gradlew`, `npm build` 등)에 맞게 한 번 조정
3. GitHub Secrets 등록 후 `main` 또는 `workflow_dispatch` 로 검증

다음 단계가 필요하면 이 초안을 기준으로 **저장소별 실제 workflow 형태로 바로 구체화**하면 된다.
