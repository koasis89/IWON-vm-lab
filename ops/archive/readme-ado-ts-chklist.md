# OPS 배포 체크리스트

## 1. 실행 전 점검

- `ops/azure-pipelines-vm.yml`가 기본 파이프라인으로 연결되어 있는가
- `AZURE_SERVICE_CONNECTION` 설정이 유효한가
- `ANSIBLE_SSH_PRIVATE_KEY_SECURE_FILE` 등록이 완료되었는가
- `TFSTATE_RG`, `TFSTATE_STORAGE`가 설정되었는가 (runTerraform=true 또는 output 조회 시 필요)
- Feed에 배포 대상 패키지 버전이 존재하는가

## 2. 산출물 점검

필수 경로(패키지 내부 상대경로):
- `web/html.zip`
- `was/app.jar`
- `app/app.jar`
- `integration/app.jar`

## 3. 파라미터 점검

- Terraform 미반영 배포: `runTerraform=false`
- Terraform 포함 배포: `runTerraform=true`
- Universal Packages 배포: `artifactFeedType=universal`
- Maven Feed 배포: `artifactFeedType=maven`

## 4. 장애 시 1차 확인

- Terraform 단계 실패: backend 변수 누락 여부 확인
- Inventory 생성 실패: Terraform output 아티팩트 존재 여부 확인
- Ansible 연결 실패: SSH key/보안그룹/점프 경로 확인
- 산출물 검증 실패: Feed 패키지 내부 상대경로/버전 확인

## 5. 제외 항목

- 이 체크리스트는 DB 작업을 다루지 않습니다.
- DB 변경은 DBeaver를 통한 수동 작업 기준으로 운영합니다.
