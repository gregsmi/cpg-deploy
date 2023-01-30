output "public_ip" {
  value = azurerm_public_ip.ingress.ip_address
}
output "AZURE_CREDENTIALS" {
  value     = module.ci_cd_sp.credentials
  sensitive = true
}
