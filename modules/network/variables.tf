variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "base_name" { type = string }
variable "vnet_address_space" { type = string }
variable "container_apps_subnet_cidr" { type = string }
variable "mysql_subnet_cidr" { type = string }
variable "tags" { type = map(string) }