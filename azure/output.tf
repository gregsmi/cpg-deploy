output "deployment" {
  value = {
    resource_group = data.azurerm_resource_group.rg.name
    location       = data.azurerm_resource_group.rg.location
    admin_users    = [for user in data.azuread_users.admins.users : user.mail]
    datasets       = [for ds in module.datasets : ds.name]
  }
}
output "CPG_DEPLOY_CONFIG" {
  value = local.CPG_DEPLOY_CONFIG
}
output "sample_metadata_dbserver" {
  value = module.sm_db.fqdn
}
output "SM_DBCREDS" {
  value     = module.sm_db.credentials
  sensitive = true
}
output "AZURE_CREDENTIALS" {
  value     = module.ci_cd_sp.credentials
  sensitive = true
}
output "HAIL_DEPLOY_CONFIG" {
  value = local.HAIL_DEPLOY_CONFIG
}
