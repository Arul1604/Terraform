variable "location" {
 description = "The location where resources will be created"
 default = "Southeast Asia"
}

variable "tags" {
 description = "A map of the tags to use for the resources that are deployed"
 type        = map(string)

 default = {
   environment = "lab"
 }
}

variable "resource_group_name" {
 description = "The name of the resource group in which the resources will be created"
 default     = "Nilavembu_Herbs"
}

variable "size" {
 description = "The size used for the linux VM"
 default	 = "Standard_D2ds_v4"
}

variable "admin_username" {
 description = "The username to be used for VM"
 default	 = "adminuser"
}

variable "sku" {
 description = "sku image to deploy"
 default     = "18.04-LTS"
}

variable "os_type" {
 description = "OS to be deployed"
 default     = "UbuntuServer"
}

variable "prefix" {
 description = "The name to be used for the resources created"
 default = "NHerbs"
}

variable "pip_sku" {
  description = "The SKU of the Azure Public IP. Accepted values are Basic and Standard."
  type        = string
  default     = "Standard"
}

variable "lb_sku" {
  description = "The SKU of the Azure Load Balancer. Accepted values are Basic and Standard."
  type        = string
  default     = "Standard"
}

variable "lb_port" {
  description = "Protocols to be used for lb rules. Format as [frontend_port, protocol, backend_port]"
  type        = map(any)
  default     = {
  http = ["80", "Tcp", "80"]
  https = ["443", "Tcp", "443"]
  }
}

variable "location1" {
 description = "The location where resources will be created"
 default = "East US 2"
}

variable "resource_group_name1" {
 description = "The name of the resource group in which the resources will be created"
 default     = "Nilavembu_Herbs_EastUS"
}

variable "vmadmin" {
 description = "The user name who manages VM in subscription"
 default	 = "vmadmin"
}

variable "vmadmin_password" {
 description = "The password for the user who manages VM in subscription"
 default	 = "password@123"
}

variable "backupadmin" {
 description = "The user name who manages VM backup for the EUS servers in EUS resource group"
 default	 = "backupadmin"
}

variable "backupadmin_password" {
 description = "The password for the user who manages VM backup for the EUS servers in EUS resource group"
 default	 = "password@123"
}
 
 
 

  