# Azure Files NFS v4.1 공유 스토리지
# 용도: was01, app01, smartcontract01 공유 파일 저장소

# 1. Storage Account (Premium FileStorage)
resource "azurerm_storage_account" "nfs" {
  name                     = "iwonsfskrc${replace(var.resource_group_name, "-", "")}01"
  location                 = azurerm_resource_group.this.location
  resource_group_name      = azurerm_resource_group.this.name
  account_tier             = "Premium"
  account_replication_type = "LRS"
  account_kind             = "FileStorage"
  tags                     = local.tags
}

# 2. Private Endpoint for Azure Files (NFS)
resource "azurerm_private_endpoint" "storage_files" {
  name                = "${var.resource_group_name}-storage-pe"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.app.id
  tags                = local.tags

  private_service_connection {
    name                           = "storage-psc"
    private_connection_resource_id = azurerm_storage_account.nfs.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }
}

# 3. Private DNS Zone for Azure Files
resource "azurerm_private_dns_zone" "storage" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

# 4. Private DNS Zone VNet Link
resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  name                  = "${var.resource_group_name}-storage-vnet-link"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.storage.name
  virtual_network_id    = azurerm_virtual_network.this.id
  tags                  = local.tags
}

# 5. Private DNS A Record for Storage Account
resource "azurerm_private_dns_a_record" "storage" {
  name                = azurerm_storage_account.nfs.name
  zone_name           = azurerm_private_dns_zone.storage.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.storage_files.private_service_connection.0.private_ip_address]
  tags                = local.tags
}

# 6. Storage Share (NFS v4.1)
resource "azurerm_storage_share" "nfs" {
  name                 = "shared"
  storage_account_name = azurerm_storage_account.nfs.name
  quota                = 1024
  enabled_protocol     = "NFS"
  access_tier          = "Premium"
}

# 7. Storage Account Network Rule: Allow Private Endpoint from app-subnet
resource "azurerm_storage_account_network_rules" "nfs" {
  storage_account_id = azurerm_storage_account.nfs.id
  default_action     = "Deny"
  bypass             = ["AzureServices"]

  depends_on = [
    azurerm_private_endpoint.storage_files
  ]
}
