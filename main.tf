resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

locals {
  base_name    = "${var.project_name}-${var.environment}"
  unique_name  = "${local.base_name}-${random_string.suffix.result}"
  compact_name = "${replace(var.project_name, "-", "")}${var.environment}${random_string.suffix.result}"
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.base_name}"
  location = var.location
  tags     = var.tags
}

module "network" {
  source = "./modules/network"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  base_name                  = local.base_name
  vnet_address_space         = var.vnet_address_space
  container_apps_subnet_cidr = var.container_apps_subnet_cidr
  mysql_subnet_cidr          = var.mysql_subnet_cidr
  tags                       = var.tags
}

module "shared_services" {
  source = "./modules/shared-services"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  unique_name                = local.unique_name
  compact_name               = local.compact_name
  residents_container_name   = "residentes"
  access_logs_container_name = "logs-acesso"
  access_logs_retention_days = var.access_logs_retention_days
  use_key_vault              = var.use_key_vault
  key_vault_public_network_access_enabled = var.key_vault_public_network_access_enabled
  tags                       = var.tags
}

module "mysql" {
  source = "./modules/mysql"

  resource_group_name       = azurerm_resource_group.main.name
  location                  = azurerm_resource_group.main.location
  server_name               = "mysql-${local.unique_name}"
  delegated_subnet_id       = module.network.mysql_subnet_id
  private_dns_zone_id       = module.network.mysql_private_dns_zone_id
  use_key_vault             = var.use_key_vault
  key_vault_id              = module.shared_services.key_vault_id
  administrator_login       = var.mysql_administrator_login
  mysql_version             = var.mysql_version
  sku_name                  = var.mysql_sku_name
  storage_gb                = var.mysql_storage_gb
  backup_retention_days     = var.mysql_backup_retention_days
  high_availability_enabled = var.mysql_high_availability
  database_name             = var.mysql_database_name
  tags                      = var.tags

  depends_on = [module.network, module.shared_services]
}

module "container_apps" {
  source = "./modules/container-apps"

  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  environment_name                = "cae-${local.unique_name}"
  container_app_name              = "ca-${local.unique_name}"
  infrastructure_subnet_id        = module.network.container_apps_subnet_id
  user_assigned_identity_id       = module.shared_services.user_assigned_identity_id
  acr_login_server                = module.shared_services.acr_login_server
  deploy_container_app            = var.deploy_container_app
  image_repository                = var.container_image_repository
  image_tag                       = var.container_image_tag
  target_port                     = var.container_target_port
  cpu                             = var.container_cpu
  memory                          = var.container_memory
  min_replicas                    = var.container_min_replicas
  max_replicas                    = var.container_max_replicas
  mysql_host                      = module.mysql.server_fqdn
  mysql_database_name             = module.mysql.database_name
  use_key_vault                   = var.use_key_vault
  mysql_username                  = module.mysql.administrator_login
  mysql_password                  = module.mysql.administrator_password
  mysql_username_secret_id        = module.mysql.administrator_login_secret_id
  mysql_password_secret_id        = module.mysql.administrator_password_secret_id
  storage_account_name            = module.shared_services.storage_account_name
  residents_blob_container_name   = module.shared_services.residents_container_name
  access_logs_blob_container_name = module.shared_services.access_logs_container_name
  event_grid_webhook_secret       = module.shared_services.event_grid_webhook_secret
  event_grid_webhook_secret_id    = module.shared_services.event_grid_webhook_secret_id
  tags                            = var.tags

  depends_on = [module.shared_services, module.mysql]
}

module "iot_ingestion" {
  source = "./modules/iot-ingestion"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  iot_hub_name               = "iot-${local.unique_name}"
  iot_hub_sku                = var.iot_hub_sku
  iot_hub_capacity           = var.iot_hub_capacity
  storage_account_id         = module.shared_services.storage_account_id
  storage_connection_string  = module.shared_services.storage_primary_blob_connection_string
  access_logs_container_name = module.shared_services.access_logs_container_name
  deploy_event_subscription  = var.deploy_container_app
  container_app_fqdn         = module.container_apps.container_app_fqdn
  event_grid_webhook_path    = var.event_grid_webhook_path
  event_grid_webhook_secret  = module.shared_services.event_grid_webhook_secret
  tags                       = var.tags

  depends_on = [module.shared_services, module.container_apps]
}