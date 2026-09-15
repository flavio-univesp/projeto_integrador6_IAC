variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "environment_name" { type = string }
variable "container_app_name" { type = string }
variable "infrastructure_subnet_id" { type = string }
variable "user_assigned_identity_id" { type = string }
variable "user_assigned_identity_client_id" { type = string }
variable "acr_login_server" { type = string }
variable "deploy_container_app" { type = bool }
variable "image_repository" { type = string }
variable "image_tag" { type = string }
variable "target_port" { type = number }
variable "cpu" { type = number }
variable "memory" { type = string }
variable "min_replicas" { type = number }
variable "max_replicas" { type = number }
variable "mysql_host" { type = string }
variable "mysql_database_name" { type = string }
variable "use_key_vault" { type = bool }
variable "mysql_username" {
  type      = string
  sensitive = true
}
variable "mysql_password" {
  type      = string
  sensitive = true
}
variable "mysql_username_secret_id" {
  type     = string
  nullable = true
}
variable "mysql_password_secret_id" {
  type     = string
  nullable = true
}
variable "storage_account_name" { type = string }
variable "residents_blob_container_name" { type = string }
variable "access_logs_blob_container_name" { type = string }
variable "event_grid_webhook_secret" {
  type      = string
  sensitive = true
}
variable "event_grid_webhook_secret_id" {
  type     = string
  nullable = true
}
variable "session_secret" {
  type      = string
  sensitive = true
}
variable "session_secret_id" {
  type     = string
  nullable = true
}
variable "tags" { type = map(string) }