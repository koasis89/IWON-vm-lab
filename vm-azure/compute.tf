resource "azurerm_public_ip" "bastion" {
  name                = "${var.resource_group_name}-bastion-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "vm" {
  for_each            = var.vm_definitions
  name                = "${each.value.name}-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = each.value.subnet_key == "app" ? azurerm_subnet.app.id : azurerm_subnet.mgmt.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.private_ip
    public_ip_address_id          = each.key == "bastion01" ? azurerm_public_ip.bastion.id : null
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each                        = var.vm_definitions
  name                            = each.value.name
  location                        = azurerm_resource_group.this.location
  resource_group_name             = azurerm_resource_group.this.name
  size                            = each.value.size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = var.admin_password == null
  network_interface_ids           = [azurerm_network_interface.vm[each.key].id]
  tags = merge(local.tags, {
    role = each.value.name
  })

  lifecycle {
    ignore_changes = [
      admin_password,
      disable_password_authentication,
    ]
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    name                 = "${each.value.name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "web" {
  network_interface_id    = azurerm_network_interface.vm["web01"].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web.id
}
