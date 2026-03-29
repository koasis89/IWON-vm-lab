# Azure OPS 배포 가이드 (개발자용)

이 문서는 개발자가 로컬 터미널에서 `bash deploy.sh`로 OPS 배포를 실행하는 방법만 설명합니다.

## 1. 개발자가 하는 일

1. 코드 수정 후 main 반영
2. `bash deploy.sh` 실행
3. 성공/실패 확인 후 공유

## 2. 배포 실행 순서 (CLI)

1. 터미널 열기
2. 환경변수 설정
   - `deploy.conf` 또는 직접 설정
3. `bash deploy.sh` 실행
4. 출력된 Run URL에서 결과 확인

## 3. 실행 원칙

- OPS 담당자가 전달한 값만 사용
- PAT를 코드/문서에 저장하지 않음

선택값:
- `ADO_BRANCH` 지정 가능 (기본 `refs/heads/main`)

## 4. 성공/실패 판단

- 모든 단계가 초록색: 성공
- 빨간 단계 존재: 실패

실패 시 전달 정보:
1. 실행 번호(Run ID)
2. 실패 단계 이름
3. 변경 기능 1줄 요약

## 5. DB 관련 정책

- DB 변경은 파이프라인에서 하지 않음
- DBeaver 기반 별도 운영 절차 사용

## 6. 참고

- OPS Quick Start: [ops/docs/readme-ops-developer-quickstart.md](readme-ops-developer-quickstart.md)
- 통합 허브: [ops/docs/readme-ado-pipeline.md](readme-ado-pipeline.md)
