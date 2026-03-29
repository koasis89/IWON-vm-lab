# OPS 개발자 배포 가이드

이 문서는 자바 개발자가 로컬 터미널에서 `bash deploy.sh`로 OPS 배포를 요청하는 방법을 설명합니다.

중요 원칙:
- 개발자는 Terraform, Ansible, 인프라 코드를 다루지 않습니다.
- 개발자는 코드 반영 후 `bash deploy.sh`만 실행합니다.
- 인프라 설정/권한/연결 문제는 OPS 담당자가 처리합니다.

## 1. 개발자가 실제로 하는 일

개발자가 하는 일은 아래 3가지뿐입니다.

1. VS Code에서 코드 수정 후 저장소에 반영
2. 로컬에서 `bash deploy.sh` 실행
3. 성공/실패 결과 확인 후 공유

## 2. 준비 (한 번만)

### 2.1 VS Code 확장 설치

아래 확장만 설치하면 됩니다.

- Azure Repos
- Azure Pipelines

### 2.2 배포 스크립트용 값 준비

OPS 담당자로부터 아래 값을 저장한 `deploy.conf`를 전달받습니다.

- `ADO_ORG`
- `ADO_PROJECT`
- `ADO_PIPELINE_ID`
- `ADO_PAT`

전달 방식:
- OPS 담당자가 `bash ops/scripts/make-deploy-conf.sh`로 생성한 `deploy.conf`를 전달
- 개발자는 프로젝트 루트에 저장 후 아래 순서로 실행

```bash
bash deploy.sh
```

## 3. 일상 배포 절차 (매번 동일)

### 3.1 코드 반영

1. 기능 개발 완료
2. main 브랜치 반영 정책에 따라 PR 머지 또는 직접 반영
3. Azure DevOps Repos에서 커밋 확인

### 3.2 배포 실행 (로컬 CLI)

1. 터미널 열기
2. `bash deploy.sh` 실행 (`deploy.conf` 자동 로드)
3. 출력된 Run URL로 결과 화면 이동

참고:
- 브랜치 지정이 필요하면 `ADO_BRANCH`를 설정합니다.
- 기본 브랜치는 `refs/heads/main`입니다.

### 3.3 결과 확인

1. 실행 화면에서 각 단계 상태 확인
2. 전체가 초록색이면 배포 성공
3. 실패 시 Failed 단계 클릭 후 로그 확인
4. 로그 링크를 OPS 담당자에게 전달

## 4. 실패했을 때 개발자 대응

개발자는 아래만 수행합니다.

1. 같은 커밋으로 1회 재실행
2. 다시 실패하면 OPS 담당자에게 전달
3. 전달 내용:
   - 파이프라인 실행 번호
   - 실패 단계 이름
   - 변경한 기능 요약 1줄

개발자가 하지 않는 일:
- 인프라 수정
- 서버 접속 설정 변경
- Terraform/Ansible 파일 편집
- 파이프라인/인프라 변수 임의 변경

## 5. DB 관련 정책

- 이 배포 가이드는 DB 작업을 포함하지 않습니다.
- DB 변경은 DBeaver 기반 별도 절차로 진행합니다.

## 6. 자주 묻는 질문

Q1. 배포 버튼만 누르면 되나요?
- 현재 방식은 버튼 대신 `bash deploy.sh` 실행이 핵심입니다.

Q2. 파이프라인 옵션을 바꿔도 되나요?
- 기본적으로 변경하지 않습니다. 환경변수 값도 OPS 담당자 가이드값만 사용합니다.

Q3. 실패 로그를 이해 못하겠습니다.
- 정상입니다. 실행 번호와 실패 단계만 전달하면 OPS 담당자가 이어서 처리합니다.

## 7. 빠른 링크

- 운영자용 가이드: [ops/docs/readme-ado-artifacts.md](readme-ado-artifacts.md)
- 개발자 환경설정 가이드: [ops/docs/readme-ado-setup-developer.md](readme-ado-setup-developer.md)
