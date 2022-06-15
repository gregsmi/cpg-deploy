
resource "azurerm_key_vault" "keyvault" {
  name                      = "${var.deployment_name}vault"
  resource_group_name       = data.azurerm_resource_group.rg.name
  location                  = data.azurerm_resource_group.rg.location
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization = true
  sku_name                  = "standard"
}

# TF secret creation fails unless TF user is assigned Key Vault Secrets Officer role.
resource "azurerm_role_assignment" "key_adding" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "server_config" {
  name         = "server-config"
  value        = jsonencode({ for ds in module.datasets : ds.name => ds.config })
  key_vault_id = azurerm_key_vault.keyvault.id
  # TF user must have Officer role before TF can add secrets.
  depends_on = [azurerm_role_assignment.key_adding]
}

data "azuread_users" "admins" {
  mail_nicknames = local.config.administrators
}
resource "azurerm_key_vault_secret" "global_admins" {
  name         = "project-creator-users"
  value        = join(",", [for user in data.azuread_users.admins.users : user.mail])
  key_vault_id = azurerm_key_vault.keyvault.id
  # TF user must have Officer role before TF can add secrets.
  depends_on = [azurerm_role_assignment.key_adding]
}
