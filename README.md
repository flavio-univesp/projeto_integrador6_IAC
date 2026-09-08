# Infraestrutura CondoAcesso

Terraform modular para criar no Azure:

- VNet e subnets dedicadas para Azure Container Apps e MySQL;
- NSGs e Private DNS Zone do MySQL;
- Azure Database for MySQL Flexible Server sem acesso publico;
- Azure Container Registry, Key Vault opcional e Blob Storage com containers separados;
- Managed Identity e permissoes RBAC;
- IoT Hub com upload por identidade gerenciada e SAS temporaria para cada ESP32;
- Event Grid filtrado para arquivos `logs/*.ndjson`;
- Application Insights e Log Analytics;
- Container Apps Environment e, apos a publicacao da imagem, o Container App com ingress HTTPS publico.

## Pre-requisitos

- Terraform 1.7 ou superior;
- Azure CLI autenticada com `az login`;
- permissao para criar recursos, registrar resource providers e criar atribuicoes RBAC na assinatura;
- papel `Storage Blob Data Contributor` para a identidade que executa o Terraform.

O provider registra automaticamente os namespaces usados pelo projeto. O Terraform tambem usa Microsoft Entra ID, em vez das chaves da conta, para acessar o Blob Storage durante o provisionamento.

O Key Vault faz parte do Terraform, mas permanece desabilitado por padrao para compatibilidade com o ambiente academico, que bloqueia seu data plane publico. Com `use_key_vault = false`, os valores gerados pelo Terraform sao armazenados como secrets nativos do Container App e continuam marcados como sensiveis no state.

## Configurar o Key Vault

As variaveis abaixo controlam a criacao e a conectividade do Key Vault:

```hcl
use_key_vault                           = false
key_vault_public_network_access_enabled = false
```

- `use_key_vault = false`: nao cria o Key Vault e usa secrets nativos do Container App. Essa e a configuracao padrao e a indicada para a assinatura academica atual.
- `use_key_vault = true` e `key_vault_public_network_access_enabled = true`: cria o Key Vault com acesso publico e armazena nele as credenciais do MySQL e o segredo do webhook. Use somente em uma assinatura sem politica que bloqueie esse acesso.
- `use_key_vault = true` e `key_vault_public_network_access_enabled = false`: cria um Key Vault privado. Para gravar os segredos, o executor do Terraform precisa acessar seu data plane por Private Endpoint, DNS privado e conectividade com a VNet.

Para habilitar o Key Vault em outra assinatura sem restricao de acesso publico, altere os valores em `terraform.tfvars` antes do primeiro provisionamento:

```hcl
use_key_vault                           = true
key_vault_public_network_access_enabled = true
```

Quando habilitado, o Terraform cria o vault, concede `Key Vault Secrets Officer` ao usuario que executa o provisionamento, concede `Key Vault Secrets User` a identidade gerenciada do Container App e grava os tres segredos. O Container App passa a referencia-los pelo identificador do Key Vault em vez de armazenar seus valores diretamente.

## Preparar a assinatura Azure

Antes de executar os comandos do Terraform, autentique-se na Azure e selecione a assinatura que recebera os recursos:

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

Registre a feature de rede exigida pelo Container Apps Environment integrado a VNet e atualize o provider `Microsoft.Network`:

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

Conceda ao usuario autenticado permissao de dados no Blob Storage no escopo da assinatura:

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

Esses comandos exigem permissoes para registrar providers e features e para criar atribuicoes RBAC na assinatura.

## Primeiro provisionamento

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out main.tfplan
terraform apply main.tfplan
```

O primeiro provisionamento mantem `deploy_container_app = false`, pois o ACR ainda esta vazio. Ele cria o IoT Hub e o container privado `logs-acesso`, mas ainda nao cria a assinatura Event Grid.

## Cadastrar o ESP32

O AzureRM nao gerencia identidades individuais do IoT Hub. Instale a extensao Azure IoT da CLI e execute o comando gerado pelo Terraform:

```powershell
az extension add --name azure-iot
Invoke-Expression (terraform output -raw iot_device_registration_command)
```

O prototipo usa uma chave simetrica individual para `portaria-01`. Em producao, substitua o cadastro por certificado X.509 proprio. Nunca grave a connection string do IoT Hub, chave do Storage ou SAS permanente no firmware.

## Publicar a imagem

```powershell
$acrName = terraform output -raw acr_name
az acr login --name $acrName
docker build -t "${acrName}.azurecr.io/condoacesso-api:latest" .
docker push "${acrName}.azurecr.io/condoacesso-api:latest"
```

Antes do segundo apply, a imagem deve implementar `POST /api/events/blob-created`, validar o handshake `SubscriptionValidationEvent` do Event Grid e comparar o header `X-EventGrid-Webhook-Secret` com `EVENT_GRID_WEBHOOK_SECRET`.

Depois do push, altere `deploy_container_app = true` em `terraform.tfvars` e execute:

```powershell
terraform plan -out app.tfplan
terraform apply app.tfplan
terraform output container_app_url
```

Esse apply cria o Container App e a assinatura Event Grid para eventos `BlobCreated` cujo caminho comece com `logs/` e termine em `.ndjson`.

## Banco de dados

A criacao de tabelas nao e executada pelo Terraform porque o MySQL so e acessivel pela VNet. Execute [sql/001_controle_acesso_importacao.sql](sql/001_controle_acesso_importacao.sql) por uma pipeline, Container App Job ou maquina conectada a rede privada antes de habilitar a ingestao.

A aplicacao deve processar cada arquivo em transacao, usar `evento_id` para idempotencia e manter o MySQL em UTC. Enquanto a tabela final ainda se chamar `controle-acesso`, use crases nas consultas.

## Observacoes de seguranca

- A senha do MySQL e gerada pelo provider `random` e marcada como sensivel no state. Conforme `use_key_vault`, ela e armazenada no Key Vault ou como secret nativo do Container App. Proteja o arquivo de state local.
- O MySQL usa apenas acesso privado e resolve nomes pela Private DNS Zone vinculada a VNet.
- Os containers `residentes` e `logs-acesso` nao permitem acesso anonimo. A aplicacao pode escrever no primeiro e apenas ler o segundo.
- O IoT Hub usa Managed Identity para o Storage e entrega ao dispositivo uma SAS de upload valida por 15 minutos.
- O AzureRM exige a connection string do Storage no cadastro do destino mesmo com `identityBased`; ela fica sensivel no state, a chave compartilhada permanece desabilitada e nao e entregue a aplicacao ou ao firmware.
- Arquivos em `logs-acesso/logs/` sao excluidos apos 30 dias por padrao; ajuste `access_logs_retention_days` conforme LGPD e auditoria.
- O segredo do webhook e armazenado no Key Vault ou como secret nativo do Container App e enviado pelo Event Grid em um header secreto. Como outros segredos gerenciados pelo Terraform, ele permanece sensivel no state.
- Neste ambiente academico, o Storage tem acesso publico desabilitado pela governanca da assinatura. Para uso fora dos servicos Azure autorizados, configure Private Endpoint e DNS privado.

### Acesso publico ao Storage em outra assinatura

Em uma assinatura sem politica que bloqueie o acesso publico ao Storage, edite `modules/shared-services/main.tf` e altere a propriedade do recurso `azurerm_storage_account.main`:

```hcl
public_network_access_enabled = false
```

para:

```hcl
public_network_access_enabled = true
```

Depois, gere e aplique um novo plano:

```powershell
terraform plan -out main.tfplan
terraform apply main.tfplan
```

Essa alteracao permite que o ESP32 envie o arquivo diretamente ao endpoint publico do Blob Storage usando a SAS temporaria fornecida pelo IoT Hub. Ela nao cria um fluxo direto do Storage para o dispositivo; mensagens de retorno devem usar recursos do IoT Hub.

## Remoção do ambiente gerado.

Execute na pasta raiz do projeto, onde estão `main.tf` e `terraform.tfstate`:

```hcl
cd "D:\One-MS\OneDrive - Microsoft\Desktop\UNIVESP\7 Semestre\PjI6\Repo\projeto_integrador6_IAC"

terraform plan -destroy -out destroy.tfplan
terraform apply destroy.tfplan
```
Isso permite revisar o plano antes da destruição. A forma direta seria:

```hcl
terraform destroy
```
Confirme digitando `yes`.

## Modulos

```text
modules/
|-- network/
|-- shared-services/
|-- mysql/
|-- container-apps/
`-- iot-ingestion/
```