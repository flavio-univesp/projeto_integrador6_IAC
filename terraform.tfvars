location    = "canadaeast"
project_name = "condoacesso"
environment  = "prd"

vnet_address_space         = "10.20.0.0/16"
container_apps_subnet_cidr = "10.20.0.0/23"
mysql_subnet_cidr          = "10.20.2.0/24"

mysql_version               = "8.0.21"
mysql_sku_name              = "B_Standard_B1ms"
mysql_storage_gb            = 32
mysql_backup_retention_days = 7
mysql_high_availability     = false
mysql_database_name         = "condoservicos"
mysql_administrator_login   = "condoadmin"

use_key_vault                          = true
key_vault_public_network_access_enabled = true

deploy_container_app      = true
container_image_repository = "condoacesso-api"
container_image_tag        = "1.0.1"
container_target_port      = 3000
container_cpu             = 0.5
container_memory          = "1Gi"
container_min_replicas    = 1
container_max_replicas    = 1

iot_hub_sku               = "S1"
iot_hub_capacity          = 1
iot_device_id             = "portaria-01"
event_grid_webhook_path   = "/api/events/blob-created"
access_logs_retention_days = 30

tags = {
  projeto        = "UNIVESP-Projeto-Integrador-VI"
  grupo          = "DRP04-Turma-001"
  ambiente       = "prd"
  gerenciado_por = "terraform"
}