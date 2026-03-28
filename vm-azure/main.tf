resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

locals {
  tags = {
    env        = "poc"
    owner      = "platform-team"
    managed_by = "terraform"
    service    = "iwon-svc"
  }

  trusted_admin_cidr = "175.197.170.13/32"

  subnet_cidrs = {
    ingress = "10.0.1.0/24"
    app     = "10.0.2.0/24"
    mgmt    = "10.0.3.0/24"
    fw      = "10.0.254.0/26"
  }
}
