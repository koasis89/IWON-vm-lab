# Azure OPS 배포 가이드 허브

이 문서는 역할별 가이드로 분리되었습니다.

현재 기본 실행 방식:
- 개발자 로컬에서 `bash deploy.sh` 실행
- Azure DevOps Pipeline Run API(PAT) 호출 방식

## 1. 개발자용

- [ops/docs/readme-ado-pipeline-developer.md](readme-ado-pipeline-developer.md)
- 대상: 자바 개발자
- 특징: Azure DevOps 화면 기준 실행 절차만 안내

## 2. 운영자용

- [ops/docs/readme-ado-pipeline-operator.md](readme-ado-pipeline-operator.md)
- 대상: OPS 운영 담당자
- 특징: 파이프라인 설정, 권한, 운영 정책, 장애 대응 포함

## 3. 관련 문서

- [ops/docs/readme-ado-artifacts.md](readme-ado-artifacts.md)
- [ops/docs/readme-ado-day1.md](readme-ado-day1.md)
- [ops/docs/readme-ops-developer-quickstart.md](readme-ops-developer-quickstart.md)
- [ops/docs/readme-ado-step1-terraform.md](readme-ado-step1-terraform.md)
- [ops/docs/readme-ado-step2-ansible.md](readme-ado-step2-ansible.md)
- [ops/docs/readme-ado-step3-release.md](readme-ado-step3-release.md)
- [ops/docs/readme-ado-ts-chklist.md](readme-ado-ts-chklist.md)
