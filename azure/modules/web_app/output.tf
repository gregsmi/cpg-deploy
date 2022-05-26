output "hostname" {
  value = azurerm_app_service.web_app.default_site_hostname
}
output "id" {
  value = azurerm_app_service.web_app.id
}
output "name" {
  value = azurerm_app_service.web_app.name
}
output "principal_id" {
  value = azurerm_app_service.web_app.identity[0].principal_id
}
