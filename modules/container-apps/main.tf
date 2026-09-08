resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.environment_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "main" {
  name                = "appi-${var.environment_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = var.tags
}

resource "azurerm_container_app_environment" "main" {
  name                       = var.environment_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  infrastructure_subnet_id   = var.infrastructure_subnet_id
  tags                       = var.tags

  lifecycle {
    ignore_changes = [workload_profile]
  }
}

resource "azurerm_container_app" "main" {
  count = var.deploy_container_app ? 1 : 0

  name                         = var.container_app_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.user_assigned_identity_id]
  }

  registry {
    server   = var.acr_login_server
    identity = var.user_assigned_identity_id
  }

  dynamic "secret" {
    for_each = var.use_key_vault ? [] : [1]

    content {
      name  = "db-user"
      value = var.mysql_username
    }
  }

  dynamic "secret" {
    for_each = var.use_key_vault ? [] : [1]

    content {
      name  = "db-password"
      value = var.mysql_password
    }
  }

  dynamic "secret" {
    for_each = var.use_key_vault ? [] : [1]

    content {
      name  = "event-grid-webhook-secret"
      value = var.event_grid_webhook_secret
    }
  }

  dynamic "secret" {
    for_each = var.use_key_vault ? [1] : []

    content {
      name                = "db-user"
      key_vault_secret_id = var.mysql_username_secret_id
      identity            = var.user_assigned_identity_id
    }
  }

  dynamic "secret" {
    for_each = var.use_key_vault ? [1] : []

    content {
      name                = "db-password"
      key_vault_secret_id = var.mysql_password_secret_id
      identity            = var.user_assigned_identity_id
    }
  }

  dynamic "secret" {
    for_each = var.use_key_vault ? [1] : []

    content {
      name                = "event-grid-webhook-secret"
      key_vault_secret_id = var.event_grid_webhook_secret_id
      identity            = var.user_assigned_identity_id
    }
  }

  ingress {
    external_enabled = true
    target_port      = var.target_port
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "app"
      image  = "${var.acr_login_server}/${var.image_repository}:${var.image_tag}"
      cpu    = var.cpu
      memory = var.memory

      env {
        name  = "DB_HOST"
        value = var.mysql_host
      }

      env {
        name  = "DB_PORT"
        value = "3306"
      }

      env {
        name  = "DB_NAME"
        value = var.mysql_database_name
      }

      env {
        name        = "DB_USER"
        secret_name = "db-user"
      }

      env {
        name        = "DB_PASSWORD"
        secret_name = "db-password"
      }

      env {
        name  = "DB_SSL_MODE"
        value = "REQUIRED"
      }

      env {
        name  = "AZURE_STORAGE_ACCOUNT_NAME"
        value = var.storage_account_name
      }

      env {
        name  = "RESIDENTS_BLOB_CONTAINER_NAME"
        value = var.residents_blob_container_name
      }

      env {
        name  = "ACCESS_LOGS_BLOB_CONTAINER_NAME"
        value = var.access_logs_blob_container_name
      }

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = azurerm_application_insights.main.connection_string
      }

      env {
        name        = "EVENT_GRID_WEBHOOK_SECRET"
        secret_name = "event-grid-webhook-secret"
      }
    }
  }
}