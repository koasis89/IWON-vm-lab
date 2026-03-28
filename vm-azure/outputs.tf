output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "load_balancer_public_ip" {
  value = azurerm_public_ip.lb.ip_address
}

output "bastion_public_ip" {
  value = azurerm_public_ip.bastion.ip_address
}

output "app_gateway_public_ip" {
  value = azurerm_public_ip.appgw.ip_address
}

output "key_vault_name" {
  value = azurerm_key_vault.https.name
}

output "vm_private_ips" {
  value = {
    for name, nic in azurerm_network_interface.vm :
    name => nic.private_ip_address
  }
}

output "storage_account_name" {
  value       = azurerm_storage_account.nfs.name
  description = "Azure Files Storage Account Name"
}

output "storage_nfs_host" {
  value       = "${azurerm_storage_account.nfs.name}.privatelink.file.core.windows.net"
  description = "Azure Files NFS Host (Private Endpoint)"
}

output "storage_nfs_path" {
  value       = "/${azurerm_storage_share.nfs.name}"
  description = "Azure Files NFS Share Path"
}

output "storage_nfs_mount_command" {
  value       = "sudo mount -t nfs -o vers=4,minorversion=1,sec=sys ${azurerm_storage_account.nfs.name}.privatelink.file.core.windows.net:/${azurerm_storage_share.nfs.name} /mnt/shared"
  description = "NFS mount command for app-tier VMs"
}
