variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "iot_hub_name" { type = string }
variable "iot_hub_sku" { type = string }
variable "iot_hub_capacity" { type = number }
variable "storage_account_id" { type = string }
variable "storage_connection_string" {
  type      = string
  sensitive = true
}
variable "access_logs_container_name" { type = string }
variable "deploy_event_subscription" { type = bool }
variable "container_app_fqdn" { type = string }
variable "event_grid_webhook_path" { type = string }
variable "event_grid_webhook_secret" {
  type      = string
  sensitive = true
}
variable "tags" { type = map(string) }