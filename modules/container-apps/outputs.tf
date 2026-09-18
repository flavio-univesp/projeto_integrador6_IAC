output "container_app_url" {
  value = var.deploy_container_app ? "https://${azurerm_container_app.main[0].ingress[0].fqdn}" : null
}

output "container_app_fqdn" {
  value = var.deploy_container_app ? azurerm_container_app.main[0].ingress[0].fqdn : null
}