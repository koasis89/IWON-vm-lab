data "azurerm_client_config" "current" {}

locals {
  use_imported_tls_certificate = var.tls_certificate_mode == "import"
  imported_tls_certificate_secret_id = coalesce(
    var.tls_certificate_existing_secret_id,
    "https://${var.key_vault_name}.vault.azure.net/secrets/${var.tls_certificate_name}"
  )
  tls_certificate_secret_id = local.use_imported_tls_certificate ? local.imported_tls_certificate_secret_id : azurerm_key_vault_certificate.web_tls[0].secret_id
}

resource "azurerm_key_vault" "https" {
  name                       = var.key_vault_name
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  enable_rbac_authorization  = true
  tags                       = local.tags
}

resource "azurerm_role_assignment" "kv_admin_current_user" {
  scope                = azurerm_key_vault.https.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "time_sleep" "wait_for_kv_rbac" {
  depends_on      = [azurerm_role_assignment.kv_admin_current_user]
  create_duration = "60s"
}

resource "azurerm_key_vault_certificate" "web_tls" {
  count        = local.use_imported_tls_certificate ? 0 : 1
  name         = var.tls_certificate_name
  key_vault_id = azurerm_key_vault.https.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      subject            = var.tls_certificate_subject
      validity_in_months = 12

      subject_alternative_names {
        dns_names = var.tls_certificate_san_dns_names
      }

      key_usage = [
        "digitalSignature",
        "keyEncipherment",
      ]
      extended_key_usage = [
        "1.3.6.1.5.5.7.3.1",
      ]
    }
  }

  depends_on = [time_sleep.wait_for_kv_rbac]
}

resource "azurerm_user_assigned_identity" "appgw" {
  name                = "${var.app_gateway_name}-uami"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "appgw_kv_secret_user" {
  scope                = azurerm_key_vault.https.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.appgw.principal_id
}

resource "azurerm_public_ip" "appgw" {
  name                = "${var.app_gateway_name}-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_application_gateway" "https" {
  name                = var.app_gateway_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  lifecycle {
    precondition {
      condition = local.use_imported_tls_certificate ? length(trimspace(local.imported_tls_certificate_secret_id)) > 0 : true
      error_message = "When tls_certificate_mode is 'import', tls_certificate_existing_secret_id (or the derived versionless secret ID) must not be empty."
    }
  }

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw.id]
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.ingress.id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  frontend_port {
    name = "port-443"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "public-frontend"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  backend_address_pool {
    name         = "web-backend-pool"
    ip_addresses = [var.vm_definitions["web01"].private_ip]
  }

  backend_address_pool {
    name         = "was-backend-pool"
    ip_addresses = [var.vm_definitions["was01"].private_ip]
  }

  backend_address_pool {
    name         = "app-backend-pool"
    ip_addresses = [var.vm_definitions["app01"].private_ip]
  }

  backend_http_settings {
    name                  = "web-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = "web-http-probe"
  }

  backend_http_settings {
    name                  = "was-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 8080
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = "was-http-probe"
  }

  backend_http_settings {
    name                  = "app-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 8080
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = "app-http-probe"
  }

  probe {
    name                                      = "web-http-probe"
    host                                      = "127.0.0.1"
    protocol                                  = "Http"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = false
    minimum_servers                           = 0

    match {
      status_code = ["200-499"]
    }
  }

  probe {
    name                                      = "was-http-probe"
    host                                      = "127.0.0.1"
    protocol                                  = "Http"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = false
    minimum_servers                           = 0

    match {
      status_code = ["200-499"]
    }
  }

  probe {
    name                                      = "app-http-probe"
    host                                      = "127.0.0.1"
    protocol                                  = "Http"
    path                                      = "/app"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = false
    minimum_servers                           = 0

    match {
      status_code = ["200-499"]
    }
  }

  ssl_certificate {
    name                = var.tls_certificate_name
    key_vault_secret_id = local.tls_certificate_secret_id
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "public-frontend"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }

  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "public-frontend"
    frontend_port_name             = "port-443"
    protocol                       = "Https"
    ssl_certificate_name           = var.tls_certificate_name
  }

  redirect_configuration {
    name                 = "http-to-https"
    redirect_type        = "Permanent"
    target_listener_name = "https-listener"
    include_path         = true
    include_query_string = true
  }

  url_path_map {
    name                               = "main-path-map"
    default_backend_address_pool_name  = "web-backend-pool"
    default_backend_http_settings_name = "web-http-settings"

    path_rule {
      name                       = "app-path-rule"
      paths                      = ["/app", "/app/*"]
      backend_address_pool_name  = "app-backend-pool"
      backend_http_settings_name = "app-http-settings"
    }
  }

  request_routing_rule {
    name                        = "http-redirect-rule"
    rule_type                   = "Basic"
    http_listener_name          = "http-listener"
    redirect_configuration_name = "http-to-https"
    priority                    = 10
  }

  request_routing_rule {
    name               = "https-path-routing-rule"
    rule_type          = "PathBasedRouting"
    http_listener_name = "https-listener"
    url_path_map_name  = "main-path-map"
    priority           = 20
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Detection"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101S"
  }

  tags = local.tags

  depends_on = [
    azurerm_role_assignment.appgw_kv_secret_user,
    azurerm_key_vault_certificate.web_tls,
  ]
}
