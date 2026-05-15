# 1단계 가이드: Terraform 인프라 배포

이 단계는 Azure DevOps Managed Agent(무료)에서 Terraform을 실행하여 VM 인프라를 배포하고, 다음 단계에서 사용할 출력값(IP 등)을 생성하는 단계입니다.

대상 파일:
- [devops/azure-pipelines-vm.yml](../../devops/azure-pipelines-vm.yml)
- [vm-azure/provider.tf](../provider.tf)
- [vm-azure/main.tf](../main.tf)
- [vm-azure/network.tf](../network.tf)
- [vm-azure/compute.tf](../compute.tf)
- [vm-azure/storage.tf](../storage.tf)
- [vm-azure/https_option_b.tf](../https_option_b.tf)
- [vm-azure/outputs.tf](../outputs.tf)

## 생성 절차

1. Azure DevOps에서 Service Connection 생성
- 이름 예시: AZURE_SERVICE_CONNECTION
- Pipeline 변수 AZURE_SERVICE_CONNECTION에 동일 이름 지정

2. Terraform 상태 저장소 변수 설정(권장)
- TFSTATE_RG
- TFSTATE_STORAGE
- TFSTATE_CONTAINER
- TFSTATE_KEY

3. 파이프라인 실행
- 파일: [devops/azure-pipelines-vm.yml](../../devops/azure-pipelines-vm.yml)
- 파라미터 runTerraform=true

4. Terraform 실행 순서
- terraform init
- terraform validate
- terraform plan
- terraform apply -auto-approve
- terraform output -json

## 구성

파이프라인 Stage:
- Stage 1 - Terraform Apply and Output

산출물:
- terraform-output 아티팩트
- tf-output.json (bastion_public_ip, vm_private_ips 등)

## 결과물

성공 시:
- Azure에 VM/네트워크/스토리지/App Gateway/Key Vault 리소스가 생성 또는 갱신됨
- 다음 단계 인벤토리 생성에 필요한 출력 JSON 확보

점검 포인트:
- Terraform job 로그에 validate/plan/apply 모두 성공
- 아티팩트 terraform-output 게시 성공

실패 시 확인:
- Service Connection 권한
- Terraform backend 변수
- Azure 리소스 이름 충돌
