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
# TF jsonencode can't format nicely, so we go to some effort to get a pretty json file.
locals {
  CPG_DEPLOY_CONFIG_FIELDS = [for k, v in local.CPG_DEPLOY_CONFIG : "\"${k}\": \"${v}\""]
}
resource "local_file" "deploy_config" {
  filename = "deploy-config.prod.json"
  content  = <<-EOT
{
  %{~for i, f in local.CPG_DEPLOY_CONFIG_FIELDS~}
    ${f}%{if i != length(local.CPG_DEPLOY_CONFIG_FIELDS) - 1},%{endif}
  %{~endfor~}
}
EOT
}
