resource "azurerm_user_assigned_identity" "iot_hub" {
  name                = "id-${var.iot_hub_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "iot_hub_blob_contributor" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.iot_hub.principal_id
}

resource "azurerm_iothub" "main" {
  name                          = var.iot_hub_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  min_tls_version               = "1.2"
  public_network_access_enabled = true

  sku {
    name     = var.iot_hub_sku
    capacity = var.iot_hub_capacity
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.iot_hub.id]
  }

  file_upload {
    authentication_type = "identityBased"
    identity_id         = azurerm_user_assigned_identity.iot_hub.id
    connection_string   = var.storage_connection_string
    container_name      = var.access_logs_container_name
    sas_ttl             = "PT15M"
    notifications       = true
    lock_duration       = "PT1M"
    default_ttl         = "PT1H"
    max_delivery_count  = 10
  }

  tags = var.tags

  depends_on = [azurerm_role_assignment.iot_hub_blob_contributor]
}

resource "azurerm_eventgrid_event_subscription" "access_logs" {
  count = var.deploy_event_subscription ? 1 : 0

  name                 = "evgs-access-logs"
  scope                = var.storage_account_id
  included_event_types = ["Microsoft.Storage.BlobCreated"]

  webhook_endpoint {
    url = "https://${var.container_app_fqdn}${var.event_grid_webhook_path}"
  }

  delivery_property {
    header_name = "X-EventGrid-Webhook-Secret"
    type        = "Static"
    value       = var.event_grid_webhook_secret
    secret      = true
  }

  subject_filter {
    subject_begins_with = "/blobServices/default/containers/${var.access_logs_container_name}/blobs/logs/"
    subject_ends_with   = ".ndjson"
    case_sensitive      = false
  }

  retry_policy {
    max_delivery_attempts = 10
    event_time_to_live    = 1440
  }
}