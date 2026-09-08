output "server_fqdn" {
  value = azurerm_mysql_flexible_server.main.fqdn
}

output "database_name" {
  value = azurerm_mysql_flexible_database.main.name
}

output "administrator_login" {
  value     = var.administrator_login
  sensitive = true
}

output "administrator_password" {
  value     = random_password.administrator.result
  sensitive = true
}

output "administrator_login_secret_id" {
  value = var.use_key_vault ? azurerm_key_vault_secret.administrator_login[0].versionless_id : null
}

output "administrator_password_secret_id" {
  value = var.use_key_vault ? azurerm_key_vault_secret.administrator_password[0].versionless_id : null
}