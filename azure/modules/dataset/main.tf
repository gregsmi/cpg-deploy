data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "${var.definition.project_id}-rg"
  location = var.definition.region
}

data "kubernetes_secret" "hail_gsa_keys" {
  for_each = toset(["test", "standard", "full"])
  metadata {
    name = "${var.definition.name}-${each.key}-gsa-key"
  }
}
data "kubernetes_secret" "hail_tokens" {
  for_each = toset(["test", "standard", "full"])
  metadata {
    name = "${var.definition.name}-${each.key}-tokens"
  }
}

module "access_groups" {
  source       = "../group"
  for_each     = local.dataset_permissions
  name         = "${var.definition.name}-${each.key}"
  member_names = each.value
}

resource "azurerm_key_vault" "keyvault" {
  name                      = "${var.definition.project_id}vault"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  tenant_id                 = var.tenant_id
  enable_rbac_authorization = true
  sku_name                  = "standard"
}

# TF secret creation fails unless TF user is assigned Key Vault Secrets Officer role.
resource "azurerm_role_assignment" "key_adding" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "key_users" {
  for_each             = { for index, user in var.group_readers : index => user }
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
}

resource "azurerm_key_vault_secret" "dataset_membership" {
  for_each     = module.access_groups
  name         = "${var.definition.name}-${each.key}-members-cache"
  value        = join(",", distinct(each.value.login_ids))
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_key_vault_secret" "sample_metadata_membership" {
  for_each     = local.sample_metadata_permissions
  name         = "${var.definition.name}-sample-metadata-${each.key}-members-cache"
  value        = join(",", distinct(each.value))
  key_vault_id = azurerm_key_vault.keyvault.id
}
