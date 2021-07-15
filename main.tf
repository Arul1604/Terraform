terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}
resource "azurerm_resource_group" "vmss" {
 name     = var.resource_group_name
 location = var.location
 tags     = var.tags
}


resource "azurerm_virtual_network" "vmss" {
 name                = "${var.prefix}-vnet"
 address_space       = ["10.0.0.0/16"]
 location            = azurerm_resource_group.vmss.location
 resource_group_name = azurerm_resource_group.vmss.name
 tags                = var.tags
}

resource "azurerm_subnet" "vmss" {
 name                 = "${var.prefix}-subnet"
 resource_group_name  = azurerm_resource_group.vmss.name
 virtual_network_name = azurerm_virtual_network.vmss.name
 address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "jumpvmss" {
 name                 = "${var.prefix}-jumpsubnet"
 resource_group_name  = azurerm_resource_group.vmss.name
 virtual_network_name = azurerm_virtual_network.vmss.name
 address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "jumpvmss" {
  subnet_id                 = azurerm_subnet.jumpvmss.id
  network_security_group_id = azurerm_network_security_group.vmss.id
}

resource "azurerm_network_interface" "jumpvmss" {
 name                = "${var.prefix}-jumpnic"
 location            = azurerm_resource_group.vmss.location
 resource_group_name = azurerm_resource_group.vmss.name

 ip_configuration {
   name                         = "${var.prefix}-jumpip"
   subnet_id                    = azurerm_subnet.jumpvmss.id
   private_ip_address_allocation = "dynamic"
 }
}

resource "azurerm_virtual_machine" "jumpvmss" {
 name                  = "${var.prefix}-jumpVm"
 location              = azurerm_resource_group.vmss.location
 resource_group_name   = azurerm_resource_group.vmss.name
 network_interface_ids = [azurerm_network_interface.jumpvmss.id]
 vm_size               = var.size


  os_profile {
   computer_name   = "hostname"
   admin_username  = var.admin_username
   admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${file("~/.ssh/id_rsa.pub")}"
    }
  }  

  
  storage_image_reference {
    publisher = "Canonical"
    offer     = var.os_type
    sku       = var.sku
    version   = "latest"
  }
  
  storage_os_disk {
    name                  = "${var.prefix}-os_disk"
	create_option         = "FromImage"
    managed_disk_type     = "Standard_LRS"
    caching               = "ReadWrite"
  }
  
}

resource "azurerm_public_ip" "vmss" {
  name                = "${var.prefix}-PublicIPForLB"
  location            = azurerm_resource_group.vmss.location
  resource_group_name = azurerm_resource_group.vmss.name
  allocation_method   = "Static"
  sku                 = var.pip_sku
}

resource "azurerm_lb" "vmss" {
  name                = "${var.prefix}-LoadBalancer"
  location            = azurerm_resource_group.vmss.location
  resource_group_name = azurerm_resource_group.vmss.name
  sku                 = var.lb_sku
  
  frontend_ip_configuration {
    name                 = "${var.prefix}-PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.vmss.id
  }
}

resource "azurerm_lb_backend_address_pool" "vmss" {
  loadbalancer_id     = azurerm_lb.vmss.id
  name                = "${var.prefix}-backendpool"
}

resource "azurerm_lb_rule" "vmss" {
  count                          = length(var.lb_port)
  name                           = element(keys(var.lb_port), count.index)
  resource_group_name            = azurerm_resource_group.vmss.name
  loadbalancer_id                = azurerm_lb.vmss.id
  protocol                       = element(var.lb_port[element(keys(var.lb_port), count.index)], 1)
  frontend_port                  = element(var.lb_port[element(keys(var.lb_port), count.index)], 0)
  backend_port                   = element(var.lb_port[element(keys(var.lb_port), count.index)], 2)
  frontend_ip_configuration_name = "${var.prefix}-PublicIPAddress"
  enable_floating_ip             = false
  backend_address_pool_id        = azurerm_lb_backend_address_pool.vmss.id
}

resource "azurerm_network_security_group" "vmss" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.vmss.location
  resource_group_name = azurerm_resource_group.vmss.name
  
 
  security_rule = [
  {
    name                                       = "${var.prefix}-RDPnsgrules"
    priority                                   = 2500
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "*"
    source_port_range                          = "*"
    destination_port_range                     = "3389"
    source_address_prefixes                    = []
	source_address_prefix                      = "49.205.0.0/24"
	source_application_security_group_ids      = []
	source_port_ranges                         = []
	destination_address_prefix                 = "*"
	destination_address_prefixes               = []
	destination_application_security_group_ids = []
	destination_port_ranges                    = []
    description                                = "Allowed the access through RDP from the address range"
  },
  {
    name                                       = "${var.prefix}-SFTPnsgrules"
    priority                                   = 2700
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "*"
    source_port_range                          = "*"
    destination_port_range                     = "5548"
    source_address_prefixes                    = []
	source_address_prefix                      = "49.205.0.0/24"
	source_application_security_group_ids      = []
	source_port_ranges                         = []
	destination_address_prefix                 = "*"
	destination_address_prefixes               = []
	destination_application_security_group_ids = []
	destination_port_ranges                    = []
    description                                = "Allowed the access through SFTP port to upload files to the webserver from the address range"
   },
  ]
}

resource "azurerm_subnet_network_security_group_association" "vmss" {
  subnet_id                 = azurerm_subnet.vmss.id
  network_security_group_id = azurerm_network_security_group.vmss.id
}

resource "azurerm_network_interface" "vmss" {
 count               = 2
 name                = "${var.prefix}-nic${count.index}"
 location            = azurerm_resource_group.vmss.location
 resource_group_name = azurerm_resource_group.vmss.name

 ip_configuration {
   name                                  = "${var.prefix}-internal${count.index}"
   subnet_id                             = azurerm_subnet.vmss.id
   private_ip_address_allocation         = "dynamic"
 }
}

resource "azurerm_ssh_public_key" "vmss" {
  name                = "${var.prefix}-key"
  resource_group_name = azurerm_resource_group.vmss.name
  location            = azurerm_resource_group.vmss.location
  public_key          = file("~/.ssh/id_rsa.pub")
}

resource "azurerm_availability_set" "vmss" {
  name                         = "${var.prefix}-aset"
  location                     = azurerm_resource_group.vmss.location
  resource_group_name          = azurerm_resource_group.vmss.name
  platform_update_domain_count = 2
  platform_fault_domain_count  = 2
}


resource "azurerm_virtual_machine" "vmss" {
 count                 = 2
 name                  = "${var.prefix}-Vm${count.index}"
 location              = azurerm_resource_group.vmss.location
 resource_group_name   = azurerm_resource_group.vmss.name
 network_interface_ids = [element(azurerm_network_interface.vmss.*.id, count.index)]
 vm_size               = var.size


  
  os_profile {
   computer_name   = "hostname"
   admin_username  = var.admin_username
   admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${file("~/.ssh/id_rsa.pub")}"
    }
  }  

  
  storage_image_reference {
    publisher = "Canonical"
    offer     = var.os_type
    sku       = var.sku
    version   = "latest"
  }
  
  storage_os_disk {
    name                  = "${var.prefix}-os_disk${count.index}"
	create_option         = "FromImage"
    managed_disk_type     = "Standard_LRS"
    caching               = "ReadWrite"
  }
  
}
  
resource "azurerm_network_interface_backend_address_pool_association" "vmss" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.vmss[count.index].id
  ip_configuration_name   = "${var.prefix}-internal${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.vmss.id
}
  

resource "azurerm_recovery_services_vault" "vmss" {
  name                = "${var.prefix}-RSV"
  location            = azurerm_resource_group.vmss.location
  resource_group_name = azurerm_resource_group.vmss.name
  sku                 = "Standard"
}

resource "azurerm_backup_policy_vm" "vmss" {
  name                = "${var.prefix}-recovery-vault-policy"
  resource_group_name = azurerm_resource_group.vmss.name
  recovery_vault_name = azurerm_recovery_services_vault.vmss.name

  timezone = "UTC"

  backup {
    frequency = "Daily"
    time      = "21:30"
  }

  retention_daily {
    count = 30
  }
}  

resource "azurerm_backup_protected_vm" "vmss" {
  count               = 2
  resource_group_name = azurerm_resource_group.vmss.name
  recovery_vault_name = azurerm_recovery_services_vault.vmss.name
  source_vm_id        = azurerm_virtual_machine.vmss[count.index].id
  backup_policy_id    = azurerm_backup_policy_vm.vmss.id
}

resource "azurerm_storage_account" "vmss" {
  name                     = "nherbstorageaccount"
  resource_group_name      = azurerm_resource_group.vmss.name
  location                 = azurerm_resource_group.vmss.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_blob_public_access = true
}

resource "azurerm_storage_container" "vmss" {
  name                  = "containerstorage"
  storage_account_name  = azurerm_storage_account.vmss.name
  container_access_type = "container" # "blob" "private"
}

resource "azurerm_storage_blob" "vmss" {
  name                   = "blobstorage"
  storage_account_name   = azurerm_storage_account.vmss.name
  storage_container_name = azurerm_storage_container.vmss.name
  type                   = "Block"
}

resource "azurerm_monitor_action_group" "vmss" {
  name                = "${var.prefix}-CPUalerts"
  resource_group_name = azurerm_resource_group.vmss.name
  short_name          = "CPUalerts"
  
  email_receiver {
    name          = "sendtoadmin"
    email_address = "arulpandian1609@gmail.com"
  }
  
  sms_receiver {
    name         = "oncallmsg"
    country_code = "91"
    phone_number = "8778082635"
  }
}
  
resource "azurerm_monitor_metric_alert" "vmss" {
  count               = 2
  name                = "azurerm_virtual_machine.vmss.name${count.index}-cpu_alert"
  resource_group_name = azurerm_resource_group.vmss.name
  scopes              = [azurerm_storage_account.vmss.id]
  description         = "An alert rule to watch the metric Percentage CPU"

  enabled = true

  criteria {
  metric_namespace = "Microsoft.Storage/storageAccounts"
  metric_name      = "avg Percentage CPU"
  operator         = "GreaterThan"
  threshold        = 75
  aggregation      = "Average"
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.vmss.id
  }
}

resource "azurerm_resource_group" "EUSvmss" {
 name     = var.resource_group_name1
 location = var.location1
 tags     = var.tags
}

resource "azurerm_virtual_network" "EUSvmss" {
 name                = "${var.prefix}-vnet"
 address_space       = ["10.1.0.0/16"]
 location            = azurerm_resource_group.EUSvmss.location
 resource_group_name = azurerm_resource_group.EUSvmss.name
 tags                = var.tags
}

resource "azurerm_subnet" "EUSvmss" {
 name                 = "${var.prefix}-subnet"
 resource_group_name  = azurerm_resource_group.EUSvmss.name
 virtual_network_name = azurerm_virtual_network.EUSvmss.name
 address_prefixes     = ["10.1.4.0/24"]
}

resource "azurerm_network_interface" "EUSvmss" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.EUSvmss.location
  resource_group_name = azurerm_resource_group.EUSvmss.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.EUSvmss.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "EUSvmss" {
  name                  = "${var.prefix}-vm"
  location              = azurerm_resource_group.EUSvmss.location
  resource_group_name   = azurerm_resource_group.EUSvmss.name
  network_interface_ids = [azurerm_network_interface.EUSvmss.id]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = var.admin_username
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${file("~/.ssh/id_rsa.pub")}"
    }
  }
}

resource "azurerm_network_security_group" "EUSvmss" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.EUSvmss.location
  resource_group_name = azurerm_resource_group.EUSvmss.name

  security_rule {
    name                                       = "${var.prefix}-RDPnsgrules"
    priority                                   = 2500
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "*"
    source_port_range                          = "*"
    destination_port_range                     = "*"
    source_address_prefixes                    = []
	source_address_prefix                      = "49.205.0.0/24"
	source_application_security_group_ids      = []
	source_port_ranges                         = []
	destination_address_prefix                 = "*"
	destination_address_prefixes               = []
	destination_application_security_group_ids = []
	destination_port_ranges                    = []
    description                                = "Allowed the access only through specific ip address range"
  }
 }

resource "azurerm_subnet_network_security_group_association" "EUSvmss" {
  subnet_id                 = azurerm_subnet.EUSvmss.id
  network_security_group_id = azurerm_network_security_group.EUSvmss.id
}

resource "azurerm_virtual_network_peering" "vmss" {
  name                         = "${var.prefix}-peer1to2"
  resource_group_name          = azurerm_resource_group.vmss.name
  virtual_network_name         = azurerm_virtual_network.vmss.name
  remote_virtual_network_id    = azurerm_virtual_network.EUSvmss.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "EUSvmss" {
  name                         = "${var.prefix}-peer2to1"
  resource_group_name          = azurerm_resource_group.EUSvmss.name
  virtual_network_name         = azurerm_virtual_network.EUSvmss.name
  remote_virtual_network_id    = azurerm_virtual_network.vmss.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
 
 allow_gateway_transit = false 
}

resource "azuread_user" "Vmadmin" {
  user_principal_name = "${var.vmadmin}@lura1604outlook.onmicrosoft.com"
  display_name        = var.vmadmin
  mail_nickname       = var.vmadmin
  password            = var.vmadmin_password
}

resource "azuread_user" "backupadmin" {
  user_principal_name = "${var.backupadmin}@lura1604outlook.onmicrosoft.com"
  display_name        = var.backupadmin
  mail_nickname       = var.backupadmin
  password            = var.backupadmin_password
}