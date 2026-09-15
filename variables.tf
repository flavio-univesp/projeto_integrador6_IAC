variable "location" {
  description = "Regiao do Azure onde os recursos serao criados."
  type        = string
  default     = "brazilsouth"
}

variable "project_name" {
  description = "Prefixo usado nos nomes dos recursos."
  type        = string
  default     = "condoacesso"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "project_name deve conter de 3 a 20 caracteres: letras minusculas, numeros ou hifens."
  }
}

variable "environment" {
  description = "Nome curto do ambiente."
  type        = string
  default     = "dev"
}

variable "vnet_address_space" {
  description = "CIDR da rede virtual."
  type        = string
  default     = "10.20.0.0/16"
}

variable "container_apps_subnet_cidr" {
  description = "CIDR da subnet dedicada ao Container Apps Environment."
  type        = string
  default     = "10.20.0.0/23"
}

variable "mysql_subnet_cidr" {
  description = "CIDR da subnet dedicada e delegada ao MySQL."
  type        = string
  default     = "10.20.2.0/24"
}

variable "mysql_version" {
  description = "Versao do MySQL Flexible Server."
  type        = string
  default     = "8.0.21"
}

variable "mysql_sku_name" {
  description = "SKU do MySQL Flexible Server."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "mysql_storage_gb" {
  description = "Armazenamento do MySQL em GB."
  type        = number
  default     = 32
}

variable "mysql_backup_retention_days" {
  description = "Retencao de backup do MySQL em dias."
  type        = number
  default     = 7
}

variable "mysql_high_availability" {
  description = "Habilita alta disponibilidade na mesma zona."
  type        = bool
  default     = false
}

variable "mysql_database_name" {
  description = "Nome do banco criado inicialmente."
  type        = string
  default     = "condoservicos"
}

variable "mysql_administrator_login" {
  description = "Usuario administrador do MySQL."
  type        = string
  default     = "condoadmin"
}

variable "use_key_vault" {
  description = "Cria o Key Vault e armazena nele os segredos usados pelo Container App."
  type        = bool
  default     = false
}

variable "key_vault_public_network_access_enabled" {
  description = "Habilita o acesso publico ao Key Vault quando use_key_vault for true."
  type        = bool
  default     = false
}

variable "deploy_container_app" {
  description = "Cria o Container App. Habilite somente depois de publicar a imagem no ACR."
  type        = bool
  default     = false
}

variable "container_image_repository" {
  description = "Repositorio da imagem dentro do ACR."
  type        = string
  default     = "condoacesso-api"
}

variable "container_image_tag" {
  description = "Tag da imagem dentro do ACR."
  type        = string
  default     = "latest"
}

variable "container_target_port" {
  description = "Porta HTTP exposta pelo container."
  type        = number
  default     = 3000
}

variable "container_cpu" {
  description = "Quantidade de vCPU do container."
  type        = number
  default     = 0.5
}

variable "container_memory" {
  description = "Memoria do container."
  type        = string
  default     = "1Gi"
}

variable "container_min_replicas" {
  description = "Quantidade minima de replicas."
  type        = number
  default     = 1
}

variable "container_max_replicas" {
  description = "Quantidade maxima de replicas."
  type        = number
  default     = 1
}

variable "iot_hub_sku" {
  description = "SKU do IoT Hub. Use F1 apenas para prova de conceito e S1 para producao."
  type        = string
  default     = "S1"

  validation {
    condition     = contains(["F1", "S1", "S2", "S3"], var.iot_hub_sku)
    error_message = "iot_hub_sku deve ser F1, S1, S2 ou S3."
  }
}

variable "iot_hub_capacity" {
  description = "Quantidade de unidades do IoT Hub."
  type        = number
  default     = 1
}

variable "iot_device_id" {
  description = "Identificador do ESP32 cadastrado no IoT Hub."
  type        = string
  default     = "portaria-01"
}

variable "event_grid_webhook_path" {
  description = "Rota do Container App que recebe e valida eventos BlobCreated."
  type        = string
  default     = "/api/events/blob-created"
}

variable "access_logs_retention_days" {
  description = "Dias de retencao dos arquivos NDJSON de acesso no Blob Storage."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags comuns aplicadas aos recursos."
  type        = map(string)
  default = {
    projeto        = "UNIVESP-Projeto-Integrador-VI"
    ambiente       = "dev"
    gerenciado_por = "terraform"
  }
}