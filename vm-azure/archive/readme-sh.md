# VM Azure 실행 절차서 (Step by Step)

이 문서는 현재 폴더 기준으로 Terraform 배포와 백업 동기화 스크립트 실행 절차를 단계별로 정리한 문서입니다.

## 1. 작업 위치 이동

PowerShell에서 아래 경로로 이동합니다.

```powershell
cd C:\Workspace\k8s-lab-dabin\vm-azure
```

## 2. 사전 점검

아래 항목을 먼저 확인합니다.

- Azure 로그인 상태
- 올바른 구독 선택
- Terraform 설치 여부
- SSH 개인키 파일 존재 여부

실행 예시:

```powershell
az login
az account set --subscription 51be5183-cf60-4f1f-8b9f-fb4b31daa579
az account show --output table
terraform -version
Test-Path "$HOME/.ssh/id_rsa"
```

## 3. Ubuntu 이미지 설정 확인

현재 VM 이미지는 아래 값으로 설정되어 있어야 합니다.

- Publisher: Canonical
- Offer: 0001-com-ubuntu-server-jammy
- SKU: 22_04-lts-gen2
- Version: latest

검증 명령:

```powershell
az vm image list --location koreacentral --publisher Canonical --offer 0001-com-ubuntu-server-jammy --all --output table
```

## 4. Terraform 초기화 (최초 1회 또는 변경 시)

```powershell
terraform init
```

## 5. Terraform 유효성 검증

```powershell
terraform validate
```

## 6. Terraform 계획 확인

```powershell
terraform plan
```

## 7. Terraform 적용

```powershell
terraform apply
```

필요 시 자동 승인:

```powershell
terraform apply -auto-approve
```

## 8. 출력값 확인

배포가 성공하면 bastion 공인 IP와 VM 사설 IP를 확인합니다.

```powershell
terraform output
terraform output bastion_public_ip
terraform output vm_private_ips
```

## 9. 백업 동기화 스크립트 실행

현재 폴더의 sync-backups.ps1를 사용해 backup, helm_bak_20260318 폴더를 VM에 배포합니다.

기본 실행:

```powershell
.\sync-backups.ps1 -TerraformDir . -SshPrivateKeyPath "$HOME/.ssh/id_rsa" -AdminUser iwon
```

bastion01까지 포함:

```powershell
.\sync-backups.ps1 -TerraformDir . -SshPrivateKeyPath "$HOME/.ssh/id_rsa" -AdminUser iwon -IncludeBastion
```

원격 배포 기본 경로:

- /opt/updates/backup
- /opt/updates/helm_bak_20260318

## 10. 동기화 결과 확인

스크립트 출력에서 SUCCESS/FAILED 표를 확인합니다.

성공 후 VM에서 확인 예시:

```bash
ls -al /opt/updates
```

## 11. 장애 시 점검 순서

1. PlatformImageNotFound 발생 시
   - az vm image list 결과와 compute.tf 이미지 값 일치 여부 확인
2. SSH 연결 실패 시
   - bastion_public_ip 값 확인
   - NSG 22 포트 허용 소스 확인
   - SSH 키 경로 재확인
3. 스크립트 checksum mismatch 시
   - 로컬 아카이브 재생성 후 재실행

## 12. 참고 파일

- Terraform VM 설정: compute.tf
- Terraform 출력 정의: outputs.tf
- 백업 동기화 스크립트: sync-backups.ps1
