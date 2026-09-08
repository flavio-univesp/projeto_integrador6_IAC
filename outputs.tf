output "resource_group_name" {
  description = "Resource Group criado."
  value       = azurerm_resource_group.main.name
}

output "acr_name" {
  description = "Nome do Azure Container Registry."
  value       = module.shared_services.acr_name
}

output "acr_login_server" {
  description = "Servidor de login do Azure Container Registry."
  value       = module.shared_services.acr_login_server
}

output "key_vault_name" {
  description = "Nome do Key Vault quando use_key_vault estiver habilitado."
  value       = module.shared_services.key_vault_name
}

output "mysql_fqdn" {
  description = "FQDN privado do MySQL Flexible Server."
  value       = module.mysql.server_fqdn
}

output "container_app_url" {
  description = "URL publica do Container App, quando habilitado."
  value       = module.container_apps.container_app_url
}

output "iot_hub_hostname" {
  description = "Hostname usado pelo ESP32 para conectar ao IoT Hub."
  value       = module.iot_ingestion.iot_hub_hostname
}

output "iot_device_registration_command" {
  description = "Comando para cadastrar o ESP32 com chave simetrica individual no prototipo."
  value       = "az iot hub device-identity create --hub-name ${module.iot_ingestion.iot_hub_name} --device-id ${var.iot_device_id} --auth-method shared_private_key"
}