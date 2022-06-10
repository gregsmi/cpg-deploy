output "name" {
  value = var.definition.name
}

output "config" {
  value = {
    projectId     = var.definition.project_id
    allowedRepos  = var.definition.allowed_repos
    testToken     = local.hail_tokens.test.default
    standardToken = local.hail_tokens.standard.default
    fullToken     = local.hail_tokens.full.default
  }
}

output "access_group_id" {
  value = module.access_groups["access"].object_id
}