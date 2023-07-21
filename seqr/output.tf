output "public_ip" {
  description = "Static IP assigned to the SEQR ingress endpoint."
  value       = azurerm_public_ip.ingress.ip_address
}

output "web_address" {
  description = "The web address of the SEQR website."
  value       = "https://${local.fqdn}"
}

output "AZURE_CREDENTIALS" {
  description = "The credentials of the Azure service principal used for Github image build."
  value       = module.ci_cd_sp.credentials
  sensitive   = true
}

output "ELASTICSEARCH_CREDENTIALS" {
  description = "The credentials of the Elasticsearch cluster."
  value = {
    username = "elastic"
    password = random_password.elastic_password.result
  }
  sensitive = true
}

output "POSTGRES_CREDENTIALS" {
  description = "The credentials of the PostgreSQL database."
  value = {
    username = module.postgres_db.credentials.username
    password = module.postgres_db.credentials.password
  }
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

output "hadoop_core_site_xml" {
  description = "The Hadoop core-site.xml configuration."
  value       = local.hadoop_core_site_xml
  sensitive   = true
}
