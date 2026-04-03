# Bastion01 접속 허용 외부 IP 추가 작업절차서

작성일: 2026-04-03  
대상 경로: `IWON-vm-lab/vm-azure`  
작업 문서 위치: `vmware/docs/외부IP추가-작업절차서.md`

---

## 1. 작업 목적

Azure Terraform으로 구성된 `bastion01` VM에 대해 외부 관리 접속용 공인 IP를 추가 허용한다.

이번 작업에서 추가한 IP:
- `220.118.151.107/32`

기존 허용 IP:
- `175.197.170.13/32`

적용 대상:
- Resource Group: `iwon-svc-rg`
- NSG Rule: `allow-admin-ssh`
- Bastion Public IP: `20.214.224.224`

---

## 2. 변경 대상 파일

이번 작업에서 실제 반영된 파일은 아래와 같다.

1. `vm-azure/main.tf`
   - 관리자 허용 IP 목록(`trusted_admin_cidrs`)에 신규 IP 추가

2. `vm-azure/network.tf`
   - `allow-admin-ssh` 규칙을 단일 IP 방식에서 다중 IP 허용 방식으로 변경

3. `vm-azure/storage.tf`
   - Azure Files NFS Storage 방화벽에 관리자 IP 허용 추가
   - Terraform refresh/apply 시 403 오류 방지 목적

4. `vm-azure/variables.tf`
   - `admin_password`를 선택값으로 보완

5. `vm-azure/compute.tf`
   - 비밀번호 미설정 시 SSH 키 기반 인증 사용
   - 기존 VM이 불필요하게 교체되지 않도록 `ignore_changes` 보완

---

## 3. 작업 전 확인 사항

### 3.1 필수 조건
- Azure CLI 로그인 완료
- Terraform 실행 가능 상태
- 대상 경로: `C:\Workspace\IWON-vm-lab\vm-azure`
- Azure 구독에 대한 수정 권한 보유

### 3.2 사전 확인 명령

```powershell
Set-Location C:\Workspace\IWON-vm-lab\vm-azure
terraform validate
terraform plan -input=false
```

---

## 4. 실제 작업 절차

### 4.1 Terraform 코드 수정

`main.tf`의 관리자 허용 IP 목록에 신규 IP를 추가한다.

```hcl
trusted_admin_cidrs = [
  "175.197.170.13/32",
  "220.118.151.107/32",
]
```

`network.tf`의 Bastion SSH 규칙은 다중 IP 허용으로 구성한다.

```hcl
resource "azurerm_network_security_rule" "mgmt_ssh" {
  name                        = "allow-admin-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = local.trusted_admin_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.mgmt.name
}
```

---

### 4.2 작업 중 발생한 오류 및 조치

#### 오류 1: `admin_password` 복잡도 오류
발생 메시지:

```text
"admin_password" has to fulfill 3 out of these 4 conditions
```

원인:
- 기본값이 Azure Linux VM 비밀번호 복잡도 규칙을 만족하지 않음

조치:
- `admin_password`를 `null` 허용으로 변경
- 비밀번호가 없으면 SSH 키 기반 인증으로 동작하도록 수정

예시:

```hcl
variable "admin_password" {
  description = "Optional VM admin password. Leave null to use SSH-key-only authentication."
  type        = string
  default     = null
  sensitive   = true
}
```

```hcl
disable_password_authentication = var.admin_password == null
```

---

#### 오류 2: `azurerm_storage_share.nfs` 403 권한 오류
발생 메시지:

```text
403 This request is not authorized to perform this operation.
```

원인:
- Storage Account가 네트워크 제한 상태여서 Terraform이 데이터 평면(Storage Share)을 조회/갱신할 때 차단됨

조치:
- `storage.tf`의 스토리지 방화벽에 관리자 외부 IP를 허용
- Storage Account `ip_rules`는 `/32`가 아닌 순수 IPv4 형식으로 넣도록 처리

예시:

```hcl
resource "azurerm_storage_account_network_rules" "nfs" {
  storage_account_id = azurerm_storage_account.nfs.id
  default_action     = "Deny"
  bypass             = ["AzureServices"]
  ip_rules           = [for cidr in local.trusted_admin_cidrs : trimsuffix(cidr, "/32")]
}
```

---

### 4.3 검증 실행

실행 명령:

```powershell
Set-Location C:\Workspace\IWON-vm-lab\vm-azure
terraform fmt
terraform validate
terraform plan -refresh=false -no-color -input=false
```

검증 결과:
- `terraform validate` → `Success! The configuration is valid.`
- `terraform plan -refresh=false -no-color -input=false` → `Plan: 0 to add, 3 to change, 0 to destroy.`

즉, VM 재생성 없이 인플레이스 변경만 수행되는 것을 확인했다.

---

### 4.4 Azure 반영

실행 명령:

```powershell
Set-Location C:\Workspace\IWON-vm-lab\vm-azure
terraform apply -refresh=false -auto-approve
```

실행 결과(검증 완료):

```text
Apply complete! Resources: 0 added, 3 changed, 0 destroyed.
```

변경 반영 리소스:
- `azurerm_network_security_rule.mgmt_ssh`
- `azurerm_storage_account_network_rules.nfs`
- `azurerm_application_gateway.https`

---

## 5. 적용 후 출력값

`terraform apply` 완료 후 확인된 주요 출력값은 아래와 같다.

```text
app_gateway_public_ip = "20.194.3.246"
bastion_public_ip = "20.214.224.224"
load_balancer_public_ip = "20.214.150.221"
resource_group_name = "iwon-svc-rg"
storage_account_name = "iwonsfskrciwonsvcrg01"
```

VM 사설 IP:

```text
app01 = 10.0.2.30
bastion01 = 10.0.3.10
db01 = 10.0.2.50
kafka01 = 10.0.2.60
smartcontract01 = 10.0.2.40
was01 = 10.0.2.20
web01 = 10.0.2.10
```

---

## 6. 접속 확인 방법

외부 PC가 `220.118.151.107` 환경일 때 아래처럼 Bastion SSH 접속을 확인한다.

```powershell
ssh iwon@20.214.224.224
```

또는 SSH config 사용 시:

```sshconfig
Host bastion01
  HostName 20.214.224.224
  User iwon
  IdentityFile ~/.ssh/id_rsa
```

접속 명령:

```powershell
ssh bastion01
```

---

## 7. 롤백 절차

신규 허용 IP를 제거해야 할 경우 아래 순서로 되돌린다.

1. `vm-azure/main.tf`에서 `220.118.151.107/32` 삭제
2. 아래 실행

```powershell
Set-Location C:\Workspace\IWON-vm-lab\vm-azure
terraform fmt
terraform validate
terraform plan -refresh=false -no-color -input=false
terraform apply -refresh=false -auto-approve
```

---

## 8. 운영 주의사항

1. 관리자 공인 IP가 변경되면 아래 2곳을 함께 확인한다.
   - `allow-admin-ssh` NSG 규칙
   - Storage Account `ip_rules`

2. `admin_password`는 운영에서는 가급적 사용하지 않고 SSH 키 기반 인증 유지 권장

3. 현재 `terraform plan -no-color -input=false` 기준으로 `Application Gateway`에 소규모 drift가 1건 남을 수 있으나, 이번 Bastion IP 추가 작업과는 별개이다.

---

## 9. 작업 결과 요약

- `bastion01` 외부 SSH 허용 IP에 `220.118.151.107/32` 추가 완료
- Terraform 검증 완료
- Azure 적용 완료
- 실제 적용 결과:

```text
Apply complete! Resources: 0 added, 3 changed, 0 destroyed.
```

이로써 `220.118.151.107`에서 `bastion01(20.214.224.224)`로 SSH 접속 가능한 상태가 되었다.
