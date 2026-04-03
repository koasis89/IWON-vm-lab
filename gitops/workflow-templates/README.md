# GitHub Actions Workflow Templates

이 폴더는 각 저장소에서 복사해 사용할 수 있는 **GitHub Actions 초안**을 담고 있습니다.

## 포함 파일

- `deploy-web.yml` → `IWonPaymentWeb/web` 전용
- `deploy-was.yml` → `IWonPaymentWeb/was` 전용
- `deploy-app.yml` → `IWonPaymentApp` 전용
- `deploy-integration.yml` → `IWonPaymentIntegration` 전용

## 공통 주의사항

1. 복사 대상 경로: 각 저장소의 `.github/workflows/`
2. 공통 GitHub Secrets 필요
   - `ADO_ORG`
   - `ADO_PROJECT`
   - `ADO_PIPELINE_ID`
   - `ADO_PAT`
3. PoC에서는 필요 시 `-x test` 를 유지할 수 있으나, 운영 전환 시 테스트 단계를 활성화한다.
4. `deployTarget` 은 workflow 별로 **고정**하며, 실행 중 동적으로 바꾸지 않는다.
5. PoC 산출물을 운영 공용 VM/서비스명에 직접 배포하지 않는다.
