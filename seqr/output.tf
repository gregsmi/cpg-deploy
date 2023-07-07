output "public_ip" {
  description = "Static IP assigned to the SEQR ingress endpoint."
  value       = azurerm_public_ip.ingress.ip_address
}

output "web_address" {
  description = "The web address of the SEQR website."
  value       = "https://${local.fqdn}"
}

output "AZURE_CREDENTIALS" {
  value     = module.ci_cd_sp.credentials
  sensitive = true
}

output "oauth_client_id" {
  description = "The client credentials of the AzureAD application used for OAuth."
  value = {
    tenant_id     = var.tenant_id
    client_id     = azuread_application.oauth_app.application_id
    client_secret = azuread_application_password.oauth_app.value
  }
  sensitive = true
}
