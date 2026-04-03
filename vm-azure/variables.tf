variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default     = "Korea Central"
}

variable "resource_group_name" {
  description = "The name of the Resource Group in which all resources in this example should be created."
  default     = "iwon-svc-rg"
}

variable "admin_username" {
  description = "The user name to use for the VMs"
  default     = "iwon"
}

variable "admin_password" {
  description = "Optional VM admin password. Leave null to use SSH-key-only authentication. If set, it must satisfy Azure complexity rules."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition = var.admin_password == null || (
      length(regexall("[a-z]", var.admin_password)) > 0 &&
      length(regexall("[A-Z]", var.admin_password)) > 0 &&
      length(regexall("[0-9]", var.admin_password)) > 0 &&
      length(regexall("[^A-Za-z0-9_]", var.admin_password)) > 0
    )
    error_message = "admin_password must include lowercase, uppercase, digit, and special character other than underscore, or be null for SSH-only authentication."
  }
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key used for VM provisioning"
  default     = "~/.ssh/id_rsa.pub"
}

variable "key_vault_name" {
  description = "Globally unique name of the Key Vault used for HTTPS certificates"
  default     = "iwonsvckvkrc001"
}

variable "app_gateway_name" {
  description = "Name of the Application Gateway for HTTPS termination"
  default     = "iwon-svc-appgw"
}

variable "tls_certificate_name" {
  description = "Certificate name stored in Key Vault and referenced by Application Gateway"
  default     = "iwon-web-tls-cert"
}

variable "tls_certificate_mode" {
  description = "Certificate provisioning mode for Key Vault. Use 'import' to reference an externally managed certificate already imported in Key Vault, or 'self' for a temporary self-signed certificate."
  type        = string
  default     = "import"

  validation {
    condition     = contains(["import", "self"], var.tls_certificate_mode)
    error_message = "tls_certificate_mode must be either 'import' or 'self'."
  }
}

variable "tls_certificate_existing_secret_id" {
  description = "Optional Key Vault secret ID to use when tls_certificate_mode is 'import'. If null, versionless secret ID is derived from key_vault_name and tls_certificate_name."
  type        = string
  default     = null
}

variable "tls_certificate_subject" {
  description = "Subject for the certificate created by Terraform when tls_certificate_mode is 'self'."
  default     = "CN=iwon-smart.site"
}

variable "tls_certificate_san_dns_names" {
  description = "DNS SAN entries for the certificate created by Terraform when tls_certificate_mode is 'self'."
  type        = list(string)
  default = [
    "iwon-smart.site",
    "www.iwon-smart.site",
  ]
}

variable "tls_certificate_pfx_base64" {
  description = "Base64-encoded PFX payload for a publicly trusted certificate imported into Key Vault when tls_certificate_mode is 'import'."
  type        = string
  default     = null
  sensitive   = true
}

variable "tls_certificate_pfx_password" {
  description = "Password for the imported PFX payload. Set to an empty string for an unencrypted PFX."
  type        = string
  default     = null
  sensitive   = true
}
