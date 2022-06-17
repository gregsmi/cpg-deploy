output "hostname" {
  value = azurerm_linux_web_app.web_app.default_hostname
}
output "id" {
  value = azurerm_linux_web_app.web_app.id
}
output "name" {
  value = azurerm_linux_web_app.web_app.name
}
output "principal_id" {
  value = azurerm_linux_web_app.web_app.identity[0].principal_id
}
