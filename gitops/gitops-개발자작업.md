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
관련된 시크릿 항목의 값은 아키텍트에게 요청하여 깃헙 리파지토리에 등록한다.
공통 시크릿:

1. `ADO_ORG` (`iteyes-ito`)
2. `ADO_PROJECT` (`iwon-smart-ops`)
3. `ADO_PAT` (개인 액세스 토큰)
4. `ADO_PIPELINE_ID` (2)

> `ADO_PAT` 가 채팅/문서/로그에 노출되면 즉시 **폐기(revoke) 후 재발급**한다.

### 1.4 버전 전략

- `latest`, 가변 SNAPSHOT 의존 배포는 지양한다.
- 아래처럼 **불변 버전**을 사용한다.
  - `1.0.0-main.<shortsha>`
  - `1.4.2+build.381`

---

## 2. 권장 진행 순서

1. 소스 저장소에서 기능 수정
2. 로컬 에서 빌드/기본 검증
3. git push and merge to main
4. GitHub Actions에서 Azure Artifacts Feed publish
   →개발자가 push/merge(main) 하면 workflow가 실행되면서 자동 수행
5. Azure DevOps에서 `deployTarget`과 버전을 명시해 CD 실행
   → GitHub Actions가 publish 직후 REST API로 ADO pipeline을 호출해서 자동 수행
6. 대상 VM에서 서비스/포트/로그/헬스 확인
7. 이상 시 즉시 이전 고정 버전으로 롤백

### 2.0 git main merge 기준
- 개발용 브랜치에서 작업한 내용을 `main` 브랜치로 병합한다. 병합 후에는 `main` 브랜치가 최신 상태로 유지되도록 원격 저장소에 푸시한다.
- branch 명 예시: `dev`
- 병합 명령 예시:
```Powershell
git checkout main
git pull origin main
git merge <branch명> #dev
git push origin main
```
### 2.1 `build.gradle` 에 `publish` 설정이 왜 필요한가

현재 구조에서는 **소스 저장소에서 산출물을 Azure Artifacts Feed로 올린 뒤**, Azure DevOps가 그 버전을 내려받아 배포한다.
즉, 애플리케이션 소스 저장소의 `build.gradle` 에 `maven-publish` 설정이 없으면 **Feed publish 자체가 되지 않으므로 CD가 이어지지 않는다.**

정리하면:
- `IWonPaymentWeb/web`, `IWonPaymentWeb/was`, `IWonPaymentApp`, `IWonPaymentIntegration`의 `build.gradle` 에는 `publish` 설정이 필요하다.
- `IWON-vm-lab/gitops` 저장소에는 Java 산출물을 만들지 않으므로 `build.gradle publish` 설정이 필요 없다.

### 2.2 `build.gradle` publish 템플릿

아래 템플릿은 `gitops/gitops구성방안.md` 기준으로 바로 적용 가능한 최소 예시다.

```gradle
plugins {
    id 'java'
    id 'maven-publish'
}

group = 'com.iteyes.smart'
version = System.getenv("APP_VERSION") ?: "0.0.0-local"

publishing {
    publications {
        mavenJava(MavenPublication) {
            from components.java
            artifactId = 'smart-was' // 예: smart-web / smart-was / smart-app / smart-integration
        }
    }
    repositories {
        maven {
            name = "AzureArtifacts"
            url = uri("https://pkgs.dev.azure.com/iteyes-ito/iwon-smart-ops/_packaging/iwon-smart-feed/maven/v1")
            credentials {
                username = "AZURE_DEVOPS_PAT"
                password = System.getenv("AZURE_ARTIFACTS_ENV_ACCESS_TOKEN") ?: ""
            }
        }
    }
}
```

### 2.3 저장소별 적용 포인트

| 저장소/모듈 | `artifactId` 예시 | 비고 |
|---|---|---|
| `IWonPaymentWeb/web` | `smart-web` | 산출물 패턴 `*.zip` 또는 웹 빌드 산출물 구조에 맞게 조정 |
| `IWonPaymentWeb/was` | `smart-was` | 기본 `*.jar` |
| `IWonPaymentApp` | `smart-app` | 기본 `*.jar` |
| `IWonPaymentIntegration` | `smart-integration` | 기본 `*.jar` |

### 2.4 개발자 적용 체크포인트

- `plugins` 에 `id 'maven-publish'` 가 포함되어 있는가?
- `artifactId` 가 배포 대상과 일치하는가?
- `version` 이 `APP_VERSION` 기반 불변 버전인가?
- GitHub Actions 에서 `./gradlew publish` 를 실제 호출하는가?
- `AZURE_ARTIFACTS_ENV_ACCESS_TOKEN` 이 GitHub Secret 또는 환경변수로 주입되는가?

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

### 3.2 VM 장애 시 반자동 롤백 방식

Java 서비스 VM(`was01`, `app01`, `smartcontract01`)에는 배포 시 아래가 자동 반영된다.

1. 새 버전 배포 전에 현재 JAR를 `backup/` 폴더에 사전 백업
2. 직전 버전을 빠르게 되돌릴 수 있도록 `rollback.sh` 생성
3. 운영자(개발자)가 VM에서 `rollback.sh` 를 실행해 이전 버전으로 즉시 복구 가능

예시 경로:
- `was01` → `/opt/apps/was/backup/`, `/opt/apps/was/rollback.sh`
- `app01` → `/opt/apps/app/backup/`, `/opt/apps/app/rollback.sh`
- `smartcontract01` → `/opt/apps/integration/backup/`, `/opt/apps/integration/rollback.sh`

사용 예시:

```bash
cd /opt/apps/was
./rollback.sh list               # 백업 버전 목록 확인
sudo ./rollback.sh               # 가장 최근 백업본으로 롤백
sudo ./rollback.sh app.jar.previous
```

> 현재 구조의 롤백은 **완전 자동**이 아니라, 운영자/개발자가 VM에서 상태를 확인한 뒤 `rollback.sh` 를 실행하는 **반자동 방식**이다.

### 3.3 수동 롤백 절차

장애 발생 시에는 아래 순서로 **수동 롤백**을 수행한다.

#### 3.3.1 Web 수동 롤백

Web(`web01`)은 현재 `rollback.sh` 가 없으므로, **직전 정상 zip 버전을 다시 배포**하는 방식으로 되돌린다.

```bash
ssh bastion01
ssh iwon@10.0.2.10

sudo mkdir -p /opt/apps/web/manual-backup
sudo cp -r /var/www/html /opt/apps/web/manual-backup/html_$(date +%Y%m%d_%H%M%S)

# 직전 정상 zip 확보 후
sudo rm -rf /var/www/html/*
sudo unzip -oq /opt/vm-lab/html.zip -d /var/www/html
sudo nginx -t
sudo systemctl reload nginx
```

확인 포인트:
- `curl -I https://iwon-smart.site`
- `sudo systemctl status nginx`
- `/var/log/nginx/error.log`

#### 3.3.2 WAS/App/Integration 수동 롤백

Java 서비스는 `rollback.sh` 를 이용하는 것이 가장 빠르다.

예시(WAS):

```bash
ssh bastion01
ssh was01

cd /opt/apps/was
./rollback.sh list
sudo ./rollback.sh
sudo systemctl status was
```

예시(App):

```bash
ssh bastion01
ssh app01
cd /opt/apps/app
./rollback.sh list
sudo ./rollback.sh
sudo systemctl status app
```

예시(Integration):

```bash
ssh bastion01
ssh smartcontract01
cd /opt/apps/integration
./rollback.sh list
sudo ./rollback.sh
sudo systemctl status integration
```

#### 3.3.3 수동 롤백 공통 체크리스트

- [ ] 현재 장애 증상과 시각을 기록했는가?
- [ ] 직전 정상 버전을 확인했는가?
- [ ] 롤백 후 `systemctl status` 를 확인했는가?
- [ ] 포트 리슨/헬스체크를 확인했는가?
- [ ] 로그(`/var/log/iwon/*.log`, `journalctl`)를 확인했는가?
- [ ] 필요 시 ADO 배포 이력에 장애 원인을 메모했는가?

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
