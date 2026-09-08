variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "server_name" { type = string }
variable "delegated_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }
variable "use_key_vault" { type = bool }
variable "key_vault_id" {
	type     = string
	nullable = true
}
variable "administrator_login" { type = string }
variable "mysql_version" { type = string }
variable "sku_name" { type = string }
variable "storage_gb" { type = number }
variable "backup_retention_days" { type = number }
variable "high_availability_enabled" { type = bool }
variable "database_name" { type = string }
variable "tags" { type = map(string) }