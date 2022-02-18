output "deployment_name" {
  value = var.deployment_name
}
output "resource_group" {
  value = data.azurerm_resource_group.rg.name
}
output "location" {
  value = data.azurerm_resource_group.rg.location
}
