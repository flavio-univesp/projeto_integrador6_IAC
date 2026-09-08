resource "random_password" "administrator" {
  length           = 24
  special          = true
  override_special = "_%@-"
}

resource "azurerm_mysql_flexible_server" "main" {
  name                   = var.server_name
  resource_group_name    = var.resource_group_name
  location               = var.location
  administrator_login    = var.administrator_login
  administrator_password = random_password.administrator.result
  backup_retention_days  = var.backup_retention_days
  delegated_subnet_id    = var.delegated_subnet_id
  private_dns_zone_id    = var.private_dns_zone_id
  sku_name               = var.sku_name
  version                = var.mysql_version

  storage {
    auto_grow_enabled = true
    size_gb           = var.storage_gb
  }

  dynamic "high_availability" {
    for_each = var.high_availability_enabled ? [1] : []

    content {
      mode = "SameZone"
    }
  }

  tags = var.tags
}

resource "azurerm_mysql_flexible_database" "main" {
  name                = var.database_name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.main.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

resource "azurerm_mysql_flexible_server_configuration" "require_secure_transport" {
  name                = "require_secure_transport"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.main.name
  value               = "ON"
}

resource "azurerm_key_vault_secret" "administrator_login" {
  count = var.use_key_vault ? 1 : 0

  name         = "mysql-administrator-login"
  value        = var.administrator_login
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "administrator_password" {
  count = var.use_key_vault ? 1 : 0

  name         = "mysql-administrator-password"
  value        = random_password.administrator.result
  key_vault_id = var.key_vault_id
}

