# GitOps 작업계획서

작성일: 2026-04-04  
대상 저장소: `IWON-vm-lab/gitops`  
배포 대상:
- Web: `C:\Workspace\I-Won\IWonPaymentWeb\godiswebfront`
- WAS: `C:\Workspace\I-Won\IWonPaymentWeb\godiswebserver`

---

## 0. Web/WAS 자동배포 체크리스트

- [ ] `IWonPaymentWeb`의 **`main` 브랜치**에 커밋/푸시한다.
- [ ] 변경 파일이 `godiswebfront/**` 또는 `godiswebserver/**` 경로에 포함되어 있는지 확인한다.
- [ ] GitHub Actions 실행 결과가 **성공**인지 확인한다.
- [ ] Azure Artifacts 업로드 후 ADO `iwon-vm-cd`가 자동 호출되었는지 확인한다.
- [ ] ADO 배포 결과가 **`completed / succeeded`** 인지 확인한다.
- [ ] 배포 후 `https://www.iwon-smart.site/` 및 WAS 로그를 간단히 점검한다.

> 일반 소스 수정은 위 체크만 통과하면 `web`/`was`가 자동 반영된다.

---

## 1. 문서 목적

본 문서는 현재 `gitops` 저장소의 **Terraform / Ansible / 운영 문서**를 기준으로,
`godiswebfront`(web)와 `godiswebserver`(was)를 **Azure VM 환경에 GitOps 방식으로 배포하는 실제 진행 방안**을 정리한다.

핵심 목표는 아래와 같다.

1. VM 인프라 상태를 Terraform 기준으로 정합성 있게 유지한다.
2. Web/WAS 산출물을 Azure Artifacts Feed로 일원화한다.
3. Azure DevOps Pipeline + Ansible로 `web01`, `was01`에 반복 가능한 방식으로 배포한다.
4. 운영 검증 및 롤백 절차까지 포함한 실행 계획을 문서화한다.

---

## 2. 계획 수립 근거 파일

아래 파일들을 기준으로 본 계획을 작성했다.

| 기준 파일 | 확인 내용 | 계획 반영 포인트 |
|---|---|---|
| `gitops/gitops구성방안.md` | GitHub CI + Azure DevOps CD 하이브리드 구조 | 소스/배포 저장소 역할 분리 |
| `gitops/devops-업무절차서.md` | Terraform → ADO Portal → Ansible 배포 순서 | 실행 순서와 선행조건 반영 |
| `gitops/gitops-개발자작업.md` | `deployTarget`, 버전, Feed publish 규칙 | Web/WAS별 배포 파라미터 반영 |
| `gitops/ansible/azure-pipelines-vm.yml` | `runTerraform`, `deployTarget`, Maven feed precheck/download, Ansible 실행 | 실제 배포 엔진으로 사용 |
| `gitops/ansible/tasks/deploy-web.yml` | `web` 역할 호출, zip 산출물 배포, nginx 설정 반영 | Web는 `zip` 기준으로 진행 |
| `gitops/ansible/tasks/deploy-was.yml` | `/opt/apps/was/app.jar`, `was.service`, URL/Kafka 패치 | WAS는 `jar` 기준으로 진행 |
| `vm-ansible/inventory.ini` | `bastion01 -> web01/was01` ProxyJump 구조 | 운영 접속/배포 경로 반영 |
| `vm-azure/variables_vms.tf` | `web01`, `was01`, `bastion01` 등 VM 정의 | 대상 VM 확정 |
| `vm-azure/README-tf.md` | App Gateway, Bastion, 내부 사설망 구조 | 네트워크/보안 전제 반영 |
| `godiswebfront/vite.config.js` | Vite/React 프론트엔드 구조, 개발 포트 `3000` | Web 정적 빌드 후 zip 패키징 필요 |
| `godiswebserver/build.gradle` | Java 17 / Spring Boot 3.2.6 기반 WAS | JAR 빌드 및 Feed publish 필요 |

---

## 3. 대상 시스템 매핑

| 구분 | 소스 경로 | 산출물 | `deployTarget` | 대상 VM | 배포 위치/서비스 |
|---|---|---|---|---|---|
| Web | `C:\Workspace\I-Won\IWonPaymentWeb\godiswebfront` | `zip` | `web` | `web01 (10.0.2.10)` | `/var/www/html`, `nginx` |
| WAS | `C:\Workspace\I-Won\IWonPaymentWeb\godiswebserver` | `jar` | `was` | `was01 (10.0.2.20)` | `/opt/apps/was/app.jar`, `was.service` |

참고:
- 배포는 외부에서 직접 각 VM으로 붙는 방식이 아니라, **`bastion01`을 경유한 Ansible 배포**로 수행한다.
- `azure-pipelines-vm.yml`은 기본적으로 **Azure Artifacts Maven Feed**에서 산출물을 내려받아 Ansible에 전달한다.

---
### 3.1 ADO Pipeline 배포 파라미터 매핑
1. `ADO_ORG` (`iteyes-ito`)
2. `ADO_PROJECT` (`iwon-smart-ops`)
3. `ADO_PAT` (`<GitHub Secret에만 저장 / 문서에는 기재하지 않음>`)
4. `ADO_PIPELINE_ID` (2)

## 4. 권장 배포 흐름

```text
소스 수정
→ GitHub/Git local build 검증
→ Azure Artifacts Feed publish
→ Azure DevOps Pipeline(iwon-vm-cd) 실행
→ bastion01 self-hosted agent/Ansible 수행
→ web01 / was01 반영
→ 서비스 검증 및 필요 시 롤백
```

운영상 가장 안전한 순서는 아래와 같다.

1. **인프라 상태 확인** (`vm-azure`)
2. **배포 엔진 상태 확인** (`azure-pipelines-vm.yml`, self-hosted agent, SSH key)
3. **Web/WAS 산출물 표준화 및 Feed publish**
4. **Web 먼저 배포 후 검증**
5. **WAS 배포 후 검증**
6. **문제 발생 시 WAS는 `rollback.sh`로 즉시 롤백**

> 권장: 첫 적용 시에는 `web`과 `was`를 한 번에 동시에 배포하지 말고, **`web → 검증 → was`** 순서로 진행한다.

---

## 5. 상세 작업 방안

### 5.1 1단계 - 인프라/접속 기반 점검

#### A. Terraform 기준 인프라 확인
- 기준 폴더: `vm-azure/`
- 확인 대상:
  - `bastion01` Public IP
  - `web01`, `was01` Private IP
  - App Gateway / Load Balancer / NSG 상태

권장 확인 명령:

```powershell
terraform -chdir="./vm-azure" validate
terraform -chdir="./vm-azure" output
```

추가 확인 포인트:
- `web01 = 10.0.2.10`
- `was01 = 10.0.2.20`
- `bastion01 = 10.0.3.10`
- 외부 SSH는 `bastion01`만 허용

#### B. 정적 inventory 또는 Terraform output inventory 확인
- 기준 파일: `vm-ansible/inventory.ini`
- 현재 구조는 아래와 같다.
  - `web` 그룹: `web01`
  - `was` 그룹: `was01`
  - `internal_vms`는 `ProxyJump=iwon@20.214.224.224` 사용

#### C. self-hosted Azure DevOps agent 확인
- `azure-pipelines-vm.yml`은 `ADO_AGENT_POOL`의 self-hosted agent를 기준으로 동작한다.
- 필요 시 `bootstrapAdoAgent=true`로 `bastion01`에 agent를 재설치/등록한다.

---

### 5.2 2단계 - Web/WAS 산출물 표준화

현재 배포 파이프라인은 산출물을 직접 빌드하지 않고, **Feed에서 다운로드**한다.
따라서 소스 저장소에서 아래 작업이 선행되어야 한다.

#### A. Web (`godiswebfront`) 준비
`vite.config.js` 기준으로 Vite/React 정적 프론트엔드 구조이므로 아래 방식이 적합하다.

권장 절차:
1. 프론트 빌드 수행
2. `dist/` 결과물을 zip 패키징
3. 패키지명을 `smart-web-<version>.zip` 형식으로 관리
4. Azure Artifacts Feed `iwon-smart-feed`에 publish

예시 명령:

```powershell
cd C:\Workspace\I-Won\IWonPaymentWeb\godiswebfront
npm ci
npm run build
Compress-Archive -Path .\dist\* -DestinationPath .\smart-web-<version>.zip -Force
```

#### B. WAS (`godiswebserver`) 준비
`build.gradle` 기준으로 Java 17 / Spring Boot 3.2.6 애플리케이션이며, Ansible은 이를 `/opt/apps/was/app.jar`로 배포한다.

권장 절차:
1. `./gradlew clean build` 또는 `bootJar` 수행
2. 산출물 JAR 생성
3. Azure Artifacts Feed에 `smart-was`로 publish

예시 명령:

```powershell
cd C:\Workspace\I-Won\IWonPaymentWeb\godiswebserver
.\gradlew.bat clean build
```

#### C. 선행 보완 사항
현재 확인 기준으로는 아래 보완이 필요하다.

1. `godiswebserver/build.gradle`에 **`maven-publish` 설정이 아직 없음**  
   → Azure Artifacts Feed publish용 설정 추가 필요
2. `godiswebfront`는 Ansible이 `zip`을 기대하므로  
   → `dist/`를 zip으로 만들고 Feed에 올리는 workflow 필요
3. Web/WAS 모두 **가변 버전(`latest`, `SNAPSHOT`) 대신 고정 버전** 사용 필요
   - 예: `1.0.0-prod.<shortsha>`

---

### 5.3 3단계 - GitOps 배포 실행

배포는 Azure DevOps Pipeline `iwon-vm-cd`에서 수행한다.

#### A. Web 배포 실행값

| 항목 | 값 |
|---|---|
| `runTerraform` | `false` (인프라 변경 없을 때) |
| `deployTarget` | `web` |
| `artifactFeedName` | `iwon-smart-feed` |
| `mavenPackageDefinition` | `com.iteyes.smart:smart-web` |
| `mavenPackageVersion` | `<배포 버전>` |
| `artifactPattern` | `*.zip` |

배포 결과:
- `deploy-web.yml` → `web` role 실행
- zip을 `/var/www/html`에 풀고
- `backup/dev-web/nginx.conf`를 `/etc/nginx/sites-available/default`로 반영
- `nginx` 재시작/적용

#### B. WAS 배포 실행값

| 항목 | 값 |
|---|---|
| `runTerraform` | `false` (인프라 변경 없을 때) |
| `deployTarget` | `was` |
| `artifactFeedName` | `iwon-smart-feed` |
| `mavenPackageDefinition` | `com.iteyes.smart:smart-was` |
| `mavenPackageVersion` | `<배포 버전>` |
| `artifactPattern` | `*.jar` |

배포 결과:
- `deploy-was.yml` → `java_service` role 실행
- `app.jar`를 `/opt/apps/was/`에 업로드
- `was.service` 재시작
- 사전 백업 및 `rollback.sh` 생성
- URL/웹소켓 상수 값 패치 및 Kafka 환경변수 주입

#### C. Terraform 동시 수행이 필요한 경우
아래 경우에만 `runTerraform=true`로 실행한다.

- VM 또는 네트워크 구성이 변경된 경우
- 신규 환경을 처음 띄우는 경우
- NSG / App Gateway / Public IP 정책을 수정한 경우

그 외 일반 배포는 **`runTerraform=false`** 로 애플리케이션만 배포하는 것이 안전하다.

---

### 5.4 4단계 - 배포 후 검증

#### Web 검증

```bash
curl -I https://iwon-smart.site
ssh bastion01
ssh web01
sudo nginx -t
sudo systemctl status nginx
```

확인 항목:
- 메인 페이지 정상 응답
- 정적 파일 누락 없음
- nginx 설정 오류 없음

#### WAS 검증

```bash
ssh bastion01
ssh was01
sudo systemctl status was
sudo journalctl -u was -n 200 --no-pager
tail -f /var/log/syslog 
```

가능 시 추가 확인:
- `/app` 또는 API 엔드포인트 응답
- 웹소켓 연결 정상 여부
- DB / Kafka 연결 오류 여부

---

### 5.5 5단계 - 롤백 방안

#### WAS 롤백
`java_service` role은 자동으로 기존 JAR를 백업하고 `rollback.sh`를 생성하므로 아래 방식으로 즉시 롤백 가능하다.

```bash
cd /opt/apps/was
./rollback.sh list
sudo ./rollback.sh
```

#### Web 롤백
현재 `web` role은 **WAS처럼 자동 백업 스크립트를 만들지 않는다.**  
따라서 아래 방식 중 하나를 운영 기준으로 채택해야 한다.

1. **직전 zip 버전을 Feed에서 재배포**
2. 또는 `deploy-web` 전에 `/var/www/html` 백업 단계를 추가

> 운영 안정성을 위해 Web도 WAS와 동일하게 백업/롤백 단계를 보강하는 것을 권장한다.

---

## 6. 실행 우선순위 제안

### 6.1 1차 적용(권장)

1. `vm-azure`, `inventory.ini`, self-hosted agent 상태 점검
2. `godiswebserver/build.gradle`에 publish 설정 추가
3. `godiswebfront` 빌드/zip/publish workflow 추가
4. Azure Artifacts Feed에 `smart-web`, `smart-was` 업로드 확인
5. `iwon-vm-cd`로 `web` 먼저 배포
6. Smoke test 통과 후 `was` 배포
7. 운영 검증 결과를 `gitops-report.md`에 반영

### 6.2 2차 고도화

1. GitHub Actions에서 Web/WAS 자동 publish
2. publish 성공 후 Azure DevOps REST API 자동 호출
3. Web 롤백 자동화 추가
4. `prod` 브랜치/`main` 브랜치 운영 기준 명확화

---

## 7. 작업 분장안

| 작업 | 담당 권장 | 산출물 |
|---|---|---|
| Terraform/VM 상태 확인 | DevOps/Infra | 인프라 점검 결과 |
| Feed/ADO 파이프라인 점검 | DevOps | 배포 가능 상태 확인 |
| Web build/zip/publish | Front 개발 + DevOps | `smart-web-<version>.zip` |
| WAS build/publish | Backend 개발 + DevOps | `smart-was-<version>.jar` |
| Web 배포 및 검증 | DevOps + QA | 웹 응답 점검 결과 |
| WAS 배포 및 검증 | DevOps + Backend | 서비스/로그 점검 결과 |
| 롤백/장애 대응 문서화 | DevOps | 운영 체크리스트 |

---

## 8. 사전 확인 체크리스트

- [ ] `vm-azure` 기준으로 `web01`, `was01`, `bastion01` 상태 정상
- [ ] `vm-ansible/inventory.ini` 접속 정보 최신화 완료
- [ ] Azure DevOps `iwon-vm-cd` 파이프라인 실행 가능
- [ ] `ADO_PAT`, Service Connection, SSH key 등록 완료
- [ ] `godiswebfront` 빌드 및 zip 패키징 확인
- [ ] `godiswebserver` JAR 빌드 확인
- [ ] Azure Artifacts Feed에 배포 버전 업로드 확인
- [ ] Web 선배포 후 Smoke test 통과
- [ ] WAS 배포 후 로그/헬스체크 통과
- [ ] 롤백 시나리오 사전 확인

---

## 9. 2026-04-05 야간 자동 실행 결과

### 9.1 적용 완료 항목

- `godiswebfront`
  - `package.json` 신규 구성 및 누락 의존성 보완
  - Vite 기준 프로덕션 빌드 성공
- `godiswebserver`
  - `build.gradle`에 Azure Artifacts publish 설정 추가
  - Java 파일명 정합성(`IwonDistributionHandler.java`) 수정 후 Gradle 빌드 성공
- `IWonPaymentWeb/.github/workflows`
  - `deploy-web.yml`, `deploy-was.yml`를 실제 폴더 구조 기준으로 보정
- `IWON-vm-lab/gitops`
  - `deploy-was.yml`에 VM 내부 DB/서비스 환경변수 반영
  - `backup/dev-web/nginx.conf`의 `root` 경로를 `/var/www/html`로 수정

### 9.2 실제 검증 결과

아래 항목은 실제 명령 실행으로 확인했다.

1. WAS 로컬 빌드
   - 명령: `./gradlew.bat clean build -x test`
   - 결과: `BUILD SUCCESSFUL`

2. Web 로컬 빌드
   - 명령: `npm run build`
   - 결과: `vite build ... ✓ built in 27.66s`

3. Web VM 배포
   - playbook: `gitops/ansible/deploy-playbook.yml --limit web`
   - 결과: `failed=0`

4. WAS VM 배포
   - playbook: `gitops/ansible/deploy-playbook.yml --limit was`
   - 결과: `failed=0`

5. 외부 서비스 응답
   - 명령: `curl -I https://iwon-smart.site`
   - 결과: `HTTP/1.1 200 OK`

6. API 프록시 응답
   - 명령: `curl -i -X POST https://iwon-smart.site/api/auth/session -d "{}"`
   - 결과: `{"success":false,"message":"인증되지 않은 사용자입니다"}`

7. WAS 내부 헬스체크
   - 명령: `curl http://127.0.0.1:8080/actuator/health` on `was01`
   - 결과: `{"status":"UP"}`

### 9.3 후속 메모

- 현재 public `/actuator/health` 는 별도 프록시 location이 없어 SPA index로 응답한다.
- 외부 헬스체크를 분리하려면 nginx에 `/actuator/` location을 추가하는 것이 좋다.
- `godiswebfront` 번들 크기 경고와 `npm audit` 취약점은 차후 최적화 대상으로 남겨둔다.

## 10. 2026-04-07 로그인 요청 프론트 수정 및 재배포 절차

### 10.1 원인 및 수정 내용

로그인 화면에서 아이디/비밀번호가 입력되어 보여도, 브라우저 자동완성/상태 불일치로 인해 `/api/auth/login`에 **빈 body**가 전달될 수 있는 문제가 확인되었다.

이번 수정에서는 아래 2개 파일을 보완했다.

| 파일 | 수정 내용 |
|---|---|
| `godiswebfront/src/login.jsx` | 제출 시 `FormData`로 실제 입력값을 다시 읽고 `trim()` 후 검증하도록 보강 |
| `godiswebfront/src/libs/Protocol.jsx` | `/auth/login` POST 요청에서 빈 body 전송을 사전에 차단하도록 방어 로직 추가 |

적용 커밋:
- `IWonPaymentWeb` `main` 브랜치 `c00830f` — `fix: harden frontend login submission`

### 10.2 실제 빌드/배포 절차

#### A. 프론트 수정 반영 후 로컬 빌드 검증

```powershell
cd C:\Workspace\I-Won\IWonPaymentWeb\godiswebfront
npm ci
npm run build
```

실행 결과:
- `vite build`
- `✓ built in 34.41s`

#### B. GitHub Actions 기반 자동 배포 트리거

프론트 소스 수정 후 아래와 같이 `main`에 push하면 `.github/workflows/deploy-web.yml`이 자동 실행된다.

```powershell
cd C:\Workspace\I-Won\IWonPaymentWeb
git add godiswebfront/src/login.jsx godiswebfront/src/libs/Protocol.jsx
git commit -m "fix: harden frontend login submission"
git push origin main
```

자동 배포 흐름:
1. GitHub Actions에서 `npm install`, `npm run build` 수행
2. `dist/`를 `smart-web-<version>.zip`으로 패키징
3. Azure Artifacts Feed `iwon-smart-feed`에 `com.iteyes.smart:smart-web`로 publish
4. Azure DevOps Pipeline `iwon-vm-cd`를 `deployTarget=web`으로 자동 호출
5. bastion self-hosted agent가 Ansible로 `web01`에 반영

#### C. 배포 성공 확인

2026-04-07 실제 확인 결과:

```powershell
az pipelines runs show \
  --organization https://dev.azure.com/iteyes-ito \
  --project iwon-smart-ops \
  --id 38 \
  --output table

curl -I https://www.iwon-smart.site/
```

검증 결과:
- Azure DevOps Run `38` → `completed / succeeded`
- `https://www.iwon-smart.site/` → `HTTP/1.1 200 OK`

### 10.3 운영 체크 포인트

- 로그인 관련 수정은 **Web 정적 번들 재배포만으로 반영 가능**하다.
- WAS/DB 재배포 없이도 프론트 단 수정으로 빈 body 전송 문제를 완화할 수 있다.
- 재현 확인 시 브라우저 개발자도구 `Network` 탭에서 `/api/auth/login`의 `Request Payload`가 비어 있지 않은지 함께 확인한다.

---

## 11. 최종 제안

현재 저장소 구조를 기준으로 보면, **이미 VM 인프라(`vm-azure`)와 VM 배포 자동화(`gitops/ansible/azure-pipelines-vm.yml`)는 상당 부분 준비되어 있다.**
따라서 이번 작업의 핵심은 **소스 저장소(web/was)에서 산출물을 표준 버전으로 Feed에 올리는 단계**를 먼저 안정화하는 것이다.

즉, 이번 Web/WAS VM 배포는 아래 방향으로 진행하는 것이 가장 현실적이다.

1. **Terraform은 인프라 변경 시에만 수행**
2. **평상시에는 Feed publish + Ansible 배포 중심으로 운영**
3. **Web → 검증 → WAS 순서로 단계 배포**
4. **WAS는 즉시 롤백 가능, Web은 백업 절차 보강 후 운영 전환**

이 계획대로 진행하면 현재 `gitops` 구성과 가장 잘 맞고, 운영 리스크도 최소화할 수 있다.