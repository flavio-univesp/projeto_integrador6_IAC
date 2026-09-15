output "user_assigned_identity_id" {
  value = azurerm_user_assigned_identity.container_app.id
}

output "user_assigned_identity_client_id" {
  value = azurerm_user_assigned_identity.container_app.client_id
}

output "acr_name" {
  value = azurerm_container_registry.main.name
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "key_vault_id" {
  value = var.use_key_vault ? azurerm_key_vault.main[0].id : null
}

output "key_vault_name" {
  value = var.use_key_vault ? azurerm_key_vault.main[0].name : null
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "storage_account_id" {
  value = azurerm_storage_account.main.id
}

output "storage_primary_blob_connection_string" {
  value     = azurerm_storage_account.main.primary_blob_connection_string
  sensitive = true
}

output "residents_container_name" {
  value = azurerm_storage_container.residents.name
}

output "access_logs_container_name" {
  value = azurerm_storage_container.access_logs.name
}

output "event_grid_webhook_secret" {
  value     = random_password.event_grid_webhook.result
  sensitive = true
}

output "event_grid_webhook_secret_id" {
  value = var.use_key_vault ? azurerm_key_vault_secret.event_grid_webhook[0].versionless_id : null
}

output "session_secret" {
  value     = random_password.session_secret.result
  sensitive = true
}

output "session_secret_id" {
  value = var.use_key_vault ? azurerm_key_vault_secret.session_secret[0].versionless_id : null
}