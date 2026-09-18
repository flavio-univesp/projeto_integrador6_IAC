data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "container_app" {
  name                = "id-${var.unique_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_container_registry" "main" {
  name                          = "acr${var.compact_name}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Basic"
  admin_enabled                 = false
  public_network_access_enabled = true
  tags                          = var.tags
}

resource "azurerm_key_vault" "main" {
  count = var.use_key_vault ? 1 : 0

  name                          = "kv-${var.unique_name}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = var.key_vault_public_network_access_enabled
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7
  tags                          = var.tags
}

resource "azurerm_storage_account" "main" {
  name                            = "st${var.compact_name}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  tags                            = var.tags
}

resource "azurerm_storage_container" "residents" {
  name                  = var.residents_container_name
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "access_logs" {
  name                  = var.access_logs_container_name
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "access_logs" {
  storage_account_id = azurerm_storage_account.main.id

  rule {
    name    = "delete-old-access-logs"
    enabled = true

    filters {
      prefix_match = ["${var.access_logs_container_name}/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_creation_greater_than = var.access_logs_retention_days
      }
    }
  }
}

resource "random_password" "event_grid_webhook" {
  length  = 32
  special = false
}

resource "random_password" "session_secret" {
  length  = 64
  special = false
}

resource "azurerm_key_vault_secret" "event_grid_webhook" {
  count = var.use_key_vault ? 1 : 0

  name         = "event-grid-webhook-secret"
  value        = random_password.event_grid_webhook.result
  key_vault_id = azurerm_key_vault.main[0].id

  depends_on = [azurerm_role_assignment.current_user_key_vault_secrets_officer]
}

resource "azurerm_key_vault_secret" "session_secret" {
  count = var.use_key_vault ? 1 : 0

  name         = "session-secret"
  value        = random_password.session_secret.result
  key_vault_id = azurerm_key_vault.main[0].id

  depends_on = [azurerm_role_assignment.current_user_key_vault_secrets_officer]
}

resource "azurerm_role_assignment" "current_user_key_vault_secrets_officer" {
  count = var.use_key_vault ? 1 : 0

  scope                = azurerm_key_vault.main[0].id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "container_app_key_vault_secrets_user" {
  count = var.use_key_vault ? 1 : 0

  scope                = azurerm_key_vault.main[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.container_app.principal_id
}

resource "azurerm_role_assignment" "container_app_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.container_app.principal_id
}

resource "azurerm_role_assignment" "container_app_residents_contributor" {
  scope                = azurerm_storage_container.residents.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.container_app.principal_id
}


resource "azurerm_role_assignment" "container_app_access_logs_reader" {
  scope                = azurerm_storage_container.access_logs.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.container_app.principal_id
}