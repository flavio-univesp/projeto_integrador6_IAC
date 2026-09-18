# Infraestrutura CondoAcesso

Terraform modular para criar no Azure:

- VNet e subnets dedicadas para Azure Container Apps e MySQL;
- NSGs e Private DNS Zone do MySQL;
- Azure Database for MySQL Flexible Server sem acesso público;
- Azure Container Registry, Key Vault opcional e Blob Storage com containers separados;
- Managed Identity e permissões RBAC;
- IoT Hub com upload por identidade gerenciada e SAS temporária para cada ESP32;
- Event Grid filtrado para arquivos `.ndjson` gravados no container `logs-acesso`;
- Application Insights e Log Analytics;
- Container Apps Environment e, após a publicação da imagem, o Container App com ingress HTTPS público, probes de saúde e configuração da aplicação.

## Pré-requisitos

- Terraform 1.7 ou superior;
- Azure CLI autenticada com `az login`;
- permissão para criar recursos, registrar resource providers e criar atribuições RBAC na assinatura;
- papel `Storage Blob Data Contributor` para a identidade que executa o Terraform.

O provider registra automaticamente os namespaces usados pelo projeto. O Terraform também usa o Microsoft Entra ID, em vez das chaves da conta, para acessar o Blob Storage durante o provisionamento.

O Key Vault faz parte do Terraform, mas permanece desabilitado por padrão para compatibilidade com o ambiente acadêmico, que bloqueia seu data plane público. Com `use_key_vault = false`, os valores gerados pelo Terraform são armazenados como secrets nativos do Container App e continuam marcados como sensíveis no state. Isso inclui as credenciais do MySQL, o segredo do webhook do Event Grid e o segredo de sessão da aplicação.

> **Região do ambiente atual:** a infraestrutura foi provisionada no datacenter **Canada East** (`canadaeast`), pois essa era a única região em que a assinatura do Azure utilizada permitia a criação do Azure Database for MySQL Flexible Server. Essa escolha não é uma exigência da arquitetura; em outra assinatura, defina `location` conforme a disponibilidade regional dos recursos e as políticas aplicáveis.

## Configurar o Key Vault

As variáveis abaixo controlam a criação e a conectividade do Key Vault:

```hcl
use_key_vault                           = false
key_vault_public_network_access_enabled = false
```

- `use_key_vault = false`: não cria o Key Vault e usa secrets nativos do Container App. Essa é a configuração padrão e a indicada para a assinatura acadêmica atual.
- `use_key_vault = true` e `key_vault_public_network_access_enabled = true`: cria o Key Vault com acesso público e armazena nele as credenciais do MySQL, o segredo do webhook e o segredo de sessão. Use somente em uma assinatura sem política que bloqueie esse acesso.
- `use_key_vault = true` e `key_vault_public_network_access_enabled = false`: cria um Key Vault privado. Para gravar os segredos, o executor do Terraform precisa acessar seu data plane por Private Endpoint, DNS privado e conectividade com a VNet.

Para habilitar o Key Vault em outra assinatura sem restrição de acesso público, altere os valores em `terraform.tfvars` antes do primeiro provisionamento:

```hcl
use_key_vault                           = true
key_vault_public_network_access_enabled = true
```

Quando habilitado, o Terraform cria o vault, concede `Key Vault Secrets Officer` ao usuário que executa o provisionamento, concede `Key Vault Secrets User` à identidade gerenciada do Container App e grava quatro segredos: usuário e senha do MySQL, segredo do webhook e segredo de sessão. O Container App passa a referenciá-los pelo identificador do Key Vault, em vez de armazenar seus valores diretamente.

## Preparar a assinatura Azure

Antes de executar os comandos do Terraform, autentique-se no Azure e selecione a assinatura que receberá os recursos:

```powershell
az login
az account set --subscription "<ID-DA-ASSINATURA>"
```

Registre os resource providers usados pelo projeto:

```powershell
$namespaces = @(
	"Microsoft.App",
	"Microsoft.ContainerRegistry",
	"Microsoft.DBforMySQL",
	"Microsoft.Devices",
	"Microsoft.EventGrid",
	"Microsoft.Insights",
	"Microsoft.KeyVault",
	"Microsoft.ManagedIdentity",
	"Microsoft.Network",
	"Microsoft.OperationalInsights",
	"Microsoft.Storage"
)

foreach ($namespace in $namespaces) {
	az provider register `
		--namespace $namespace `
		--wait `
		--only-show-errors
}
```

Registre a feature de rede exigida pelo Container Apps Environment integrado à VNet e atualize o provider `Microsoft.Network`:

```powershell
az feature register `
	--namespace Microsoft.Network `
	--name AllowBringYourOwnPublicIpAddress `
	--only-show-errors

az provider register `
	--namespace Microsoft.Network `
	--wait `
	--only-show-errors
```

Conceda ao usuário autenticado permissão de dados no Blob Storage no escopo da assinatura:

```powershell
$subscriptionId = az account show --query id -o tsv
$objectId = az ad signed-in-user show --query id -o tsv
$scope = "/subscriptions/$subscriptionId"

az role assignment create `
	--assignee-object-id $objectId `
	--assignee-principal-type User `
	--role "Storage Blob Data Contributor" `
	--scope $scope `
	--only-show-errors
```

Esses comandos exigem permissões para registrar providers e features e para criar atribuições RBAC na assinatura.

## Primeiro provisionamento

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out main.tfplan
terraform apply main.tfplan
```

O primeiro provisionamento mantém `deploy_container_app = false`, pois o ACR ainda está vazio. Ele cria o Container Apps Environment, o IoT Hub e os containers privados `residentes` e `logs-acesso`, mas ainda não cria o Container App nem a assinatura do Event Grid.

## Cadastrar o ESP32

O AzureRM não gerencia identidades individuais do IoT Hub. Instale a extensão Azure IoT da CLI e execute o comando gerado pelo Terraform:

```powershell
az extension add --name azure-iot
Invoke-Expression (terraform output -raw iot_device_registration_command)
```

O protótipo usa uma chave simétrica individual para `portaria-01`. Em produção, substitua o cadastro por um certificado X.509 próprio. Nunca grave a connection string do IoT Hub, a chave do Storage ou uma SAS permanente no firmware.

## Publicar a imagem

```powershell
$acrName = terraform output -raw acr_name
az acr login --name $acrName
docker build -t "${acrName}.azurecr.io/condoacesso-api:latest" .
docker push "${acrName}.azurecr.io/condoacesso-api:latest"
```

Antes do segundo apply, a imagem deve:

- escutar na porta `3000`; mantenha `container_target_port = 3000`, em linha com a variável `PORT` fornecida ao container;
- implementar `GET /health/live` e `GET /health/ready` para os probes do Container App;
- implementar `POST /api/events/blob-created`;
- validar o handshake `SubscriptionValidationEvent` do Event Grid;
- comparar o header `X-EventGrid-Webhook-Secret` com `EVENT_GRID_WEBHOOK_SECRET`.

Depois do push, altere `deploy_container_app = true` em `terraform.tfvars` e execute:

```powershell
terraform plan -out app.tfplan
terraform apply app.tfplan
terraform output container_app_url
```

Esse apply cria o Container App e a assinatura do Event Grid para eventos `BlobCreated` no container `logs-acesso` cujo nome do blob termine em `.ndjson`.

O Container App recebe as configurações `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_SSL`, `NODE_ENV`, `PORT`, `AZURE_STORAGE_ACCOUNT_NAME`, `AZURE_CLIENT_ID`, `RESIDENTS_BLOB_CONTAINER_NAME`, `ACCESS_LOGS_BLOB_CONTAINER_NAME` e `APPLICATIONINSIGHTS_CONNECTION_STRING`. `DB_USER`, `DB_PASSWORD`, `SESSION_SECRET` e `EVENT_GRID_WEBHOOK_SECRET` são fornecidos como secrets.

## Banco de dados

O Terraform não cria as tabelas porque o MySQL só é acessível pela VNet. Execute [sql/001_controle_acesso_importacao.sql](sql/001_controle_acesso_importacao.sql) por uma pipeline, um Container App Job ou uma máquina conectada à rede privada antes de habilitar a ingestão.

A aplicação deve processar cada arquivo em uma transação, usar `evento_id` para idempotência e manter o MySQL em UTC. Enquanto a tabela final ainda se chamar `controle-acesso`, use crases nas consultas.

## Observações de segurança

- A senha do MySQL é gerada pelo provider `random` e marcada como sensível no state. Conforme `use_key_vault`, ela é armazenada no Key Vault ou como secret nativo do Container App. Proteja o arquivo de state local.
- O MySQL usa apenas acesso privado e resolve nomes pela Private DNS Zone vinculada à VNet.
- Os containers `residentes` e `logs-acesso` não permitem acesso anônimo. A identidade gerenciada da aplicação recebe `Storage Blob Data Contributor` em ambos para ler, gravar e excluir blobs conforme o fluxo da aplicação.
- O IoT Hub usa Managed Identity para o Storage e entrega ao dispositivo uma SAS de upload válida por 15 minutos.
- O AzureRM exige a connection string do Storage no cadastro do destino, mesmo com `identityBased`; ela fica sensível no state e não é entregue à aplicação nem ao firmware. O acesso por chave compartilhada está habilitado na configuração atual para atender a essa exigência do provisionamento.
- Os arquivos no container `logs-acesso` são excluídos após 30 dias, por padrão; ajuste `access_logs_retention_days` conforme a LGPD e os requisitos de auditoria.
- O segredo do webhook é armazenado no Key Vault ou como secret nativo do Container App e enviado pelo Event Grid em um header secreto. Como os demais segredos gerenciados pelo Terraform, ele permanece sensível no state.
- O Storage está configurado com endpoint público habilitado, TLS 1.2 mínimo e acesso anônimo aos containers bloqueado. O upload do ESP32 usa somente a SAS temporária fornecida pelo IoT Hub.

### Restringir o acesso público ao Storage

Se a arquitetura passar a usar Private Endpoint, DNS privado e conectividade adequada para todos os clientes, edite `modules/shared-services/main.tf` e altere a propriedade do recurso `azurerm_storage_account.main`:

```hcl
public_network_access_enabled = true
```

para:

```hcl
public_network_access_enabled = false
```

Depois, gere e aplique um novo plano:

```powershell
terraform plan -out main.tfplan
terraform apply main.tfplan
```

Não desabilite o endpoint público sem antes disponibilizar uma rota privada para o upload. A SAS limita a autorização do dispositivo, mas não substitui a conectividade de rede com o endpoint do Blob Storage.

## Remoção do ambiente gerado

Execute na pasta raiz do projeto, onde estão `main.tf` e `terraform.tfstate`:

```powershell
cd "D:\One-MS\OneDrive - Microsoft\Desktop\UNIVESP\7 Semestre\PjI6\Repo\projeto_integrador6_IAC"

terraform plan -destroy -out destroy.tfplan
terraform apply destroy.tfplan
```

Isso permite revisar o plano antes da destruição. A forma direta seria:

```powershell
terraform destroy
```

Confirme digitando `yes`.

## Módulos

```text
modules/
|-- network/
|-- shared-services/
|-- mysql/
|-- container-apps/
`-- iot-ingestion/
```

## Análise de custos

Considerando os recursos provisionados na região **Canada East** (`canadaeast`), o custo médio estimado da infraestrutura é de **R$ 13,10 por dia**. Para um período de 30 dias, a estimativa é de **R$ 393,00**.

Esses valores são estimativas e podem variar conforme o consumo dos serviços, o volume de armazenamento e tráfego, a cotação do dólar, os tributos aplicáveis e eventuais alterações nos preços do Azure.

## Referências técnicas

As referências abaixo apresentam os conceitos e serviços relacionados às ações executadas por esta configuração Terraform.

Todos os links encontravam-se funcionais em 18/09/2026:

- [Documentação da linguagem Terraform](https://developer.hashicorp.com/terraform/language): sintaxe declarativa, recursos, variáveis, módulos, dependências e expressões utilizadas nos arquivos `.tf`.
- [Provider AzureRM](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs): referência dos recursos e data sources usados para criar e configurar a infraestrutura no Azure.
- [Visão geral do Terraform no Azure](https://learn.microsoft.com/azure/developer/terraform/overview): conceitos de infraestrutura como código, providers do Azure e fluxo de planejamento e implantação.
- [Criação do Azure Database for MySQL Flexible Server com Terraform](https://learn.microsoft.com/azure/mysql/flexible-server/quickstart-create-terraform): criação do servidor MySQL, banco de dados, VNet, subnet delegada e zona DNS privada.
- [Azure Container Apps](https://learn.microsoft.com/azure/container-apps/overview): ambientes, aplicações em containers, ingress, revisões, escalabilidade e integração com redes virtuais.
- [Upload de arquivos com o Azure IoT Hub](https://learn.microsoft.com/azure/iot-hub/iot-hub-devguide-file-upload): associação com o Blob Storage, geração de SAS temporária e envio de arquivos pelos dispositivos.
- [Eventos do Azure Blob Storage no Event Grid](https://learn.microsoft.com/azure/event-grid/event-schema-blob-storage): eventos `BlobCreated`, filtros e estrutura das notificações entregues ao webhook.
- [Identidades gerenciadas para recursos do Azure](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview): autenticação entre serviços sem armazenamento de credenciais na aplicação.
- [Controle de acesso a blobs com Azure RBAC](https://learn.microsoft.com/azure/storage/blobs/assign-azure-role-data-access): atribuição de funções, escopos e acesso ao Blob Storage pelo Microsoft Entra ID.
- [Controle de acesso ao Azure Key Vault com RBAC](https://learn.microsoft.com/azure/key-vault/general/rbac-guide): funções para criação e leitura de segredos nos planos de controle e de dados.
- [Visão geral do Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview): coleta de telemetria, métricas, logs e análise do comportamento da aplicação.
- [Calculadora de preços do Azure](https://azure.microsoft.com/pricing/calculator/): elaboração e atualização das estimativas de custo da infraestrutura.