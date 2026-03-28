variable "vm_definitions" {
  description = "Map of VMs to create"
  type = map(object({
    name       = string
    size       = string
    subnet_key = string
    private_ip = string
  }))

  default = {
    web01 = {
      name       = "web01"
      size       = "Standard_D2s_v5"
      subnet_key = "app"
      private_ip = "10.0.2.10"
    }
    was01 = {
      name       = "was01"
      size       = "Standard_D2s_v5"
      subnet_key = "app"
      private_ip = "10.0.2.20"
    }
    app01 = {
      name       = "app01"
      size       = "Standard_D2s_v5"
      subnet_key = "app"
      private_ip = "10.0.2.30"
    }
    smartcontract01 = {
      name       = "smartcontract01"
      size       = "Standard_D2s_v5"
      subnet_key = "app"
      private_ip = "10.0.2.40"
    }
    db01 = {
      name       = "db01"
      size       = "Standard_D4s_v5"
      subnet_key = "app"
      private_ip = "10.0.2.50"
    }
    kafka01 = {
      name       = "kafka01"
      size       = "Standard_D4s_v5"
      subnet_key = "app"
      private_ip = "10.0.2.60"
    }
    bastion01 = {
      name       = "bastion01"
      size       = "Standard_D2s_v5"
      subnet_key = "mgmt"
      private_ip = "10.0.3.10"
    }
  }
}
