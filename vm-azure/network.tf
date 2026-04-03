resource "azurerm_virtual_network" "this" {
  name                = "${var.resource_group_name}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "ingress" {
  name                 = "ingress-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.subnet_cidrs.ingress]
}

resource "azurerm_subnet" "app" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.subnet_cidrs.app]
}

resource "azurerm_subnet" "mgmt" {
  name                 = "mgmt-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.subnet_cidrs.mgmt]
}

resource "azurerm_subnet" "fw" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.subnet_cidrs.fw]
}

resource "azurerm_network_security_group" "ingress" {
  name                = "${var.resource_group_name}-ingress-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "ingress_http" {
  name                        = "allow-http"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.ingress.name
}

resource "azurerm_network_security_rule" "ingress_https" {
  name                        = "allow-https"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.ingress.name
}

resource "azurerm_network_security_rule" "ingress_appgw_manager" {
  name                        = "allow-appgw-manager"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["65200-65535"]
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.ingress.name
}

resource "azurerm_network_security_rule" "ingress_azure_load_balancer" {
  name                        = "allow-azure-load-balancer"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.ingress.name
}

resource "azurerm_network_security_group" "app" {
  name                = "${var.resource_group_name}-app-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "app_from_ingress_8080" {
  name                        = "allow-ingress-to-app-8080"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = local.subnet_cidrs.ingress
  destination_address_prefix  = local.subnet_cidrs.app
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.app.name
}

resource "azurerm_network_security_rule" "app_from_bastion_ssh" {
  name                        = "allow-bastion-ssh"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = local.subnet_cidrs.mgmt
  destination_address_prefix  = local.subnet_cidrs.app
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.app.name
}

resource "azurerm_network_security_rule" "app_db" {
  name                        = "allow-db-3306"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3306"
  source_address_prefix       = local.subnet_cidrs.app
  destination_address_prefix  = local.subnet_cidrs.app
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.app.name
}

resource "azurerm_network_security_rule" "app_kafka" {
  name                        = "allow-kafka-9092"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "9092"
  source_address_prefix       = local.subnet_cidrs.app
  destination_address_prefix  = local.subnet_cidrs.app
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.app.name
}

resource "azurerm_network_security_rule" "app_from_ingress_80" {
  name                        = "allow-ingress-to-app-80"
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = local.subnet_cidrs.ingress
  destination_address_prefix  = local.subnet_cidrs.app
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.app.name
}

# NFS (Azure Files) Rules
resource "azurerm_network_security_rule" "app_nfs" {
  name                        = "allow-nfs-2049"
  priority                    = 145
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "2049"
  source_address_prefix       = local.subnet_cidrs.app
  destination_address_prefix  = local.subnet_cidrs.app
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.app.name
}

resource "azurerm_network_security_rule" "app_nfs_rpcbind" {
  name                        = "allow-nfs-rpcbind-111"
  priority                    = 146
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "111"
  source_address_prefix       = local.subnet_cidrs.app
  destination_address_prefix  = local.subnet_cidrs.app
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.app.name
}

resource "azurerm_network_security_group" "mgmt" {
  name                = "${var.resource_group_name}-mgmt-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

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

resource "azurerm_subnet_network_security_group_association" "ingress" {
  subnet_id                 = azurerm_subnet.ingress.id
  network_security_group_id = azurerm_network_security_group.ingress.id
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_subnet_network_security_group_association" "mgmt" {
  subnet_id                 = azurerm_subnet.mgmt.id
  network_security_group_id = azurerm_network_security_group.mgmt.id
}

resource "azurerm_public_ip" "lb" {
  name                = "${var.resource_group_name}-lb-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_lb" "public" {
  name                = "${var.resource_group_name}-public-lb"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  tags                = local.tags

  frontend_ip_configuration {
    name                 = "public-frontend"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "web" {
  name            = "web-backend-pool"
  loadbalancer_id = azurerm_lb.public.id
}

resource "azurerm_lb_probe" "http" {
  name            = "http-probe"
  loadbalancer_id = azurerm_lb.public.id
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_rule" "http" {
  name                           = "http"
  loadbalancer_id                = azurerm_lb.public.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "public-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.http.id
}

resource "azurerm_lb_rule" "https" {
  name                           = "https"
  loadbalancer_id                = azurerm_lb.public.id
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "public-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.http.id
}
