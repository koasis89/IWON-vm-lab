# OPS 개발자 배포 1페이지 요약

## 1. 핵심 원칙

- 개발자는 로컬에서 빌드 후 Feed에 업로드
- 파이프라인은 Feed에서 내려받아 배포만 수행
- 실행은 `bash deploy.sh` 한 번으로 요청

## 2. 준비물

- 운영자가 전달한 `deploy.conf`
- 업로드 완료된 패키지 버전
  - 기본: Universal Packages
  - 허용: Maven Feed

## 3. 실행 순서

1. 로컬 빌드 완료
2. Feed 업로드 완료
3. 프로젝트 루트에서 `bash deploy.sh` 실행
4. 출력된 Run URL에서 결과 확인

## 4. 실패 시 전달 정보

1. Run ID
2. 실패 단계 이름
3. 변경 내용 1줄 요약

## 5. 참고 문서

- 아티팩트 가이드: [ops/docs/readme-ado-artifacts.md](readme-ado-artifacts.md)
- 통합 허브: [ops/docs/readme-ado-pipeline.md](readme-ado-pipeline.md)
