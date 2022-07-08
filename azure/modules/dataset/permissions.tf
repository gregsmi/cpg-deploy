
locals {
  hail_accounts = {
    for type, key in data.kubernetes_secret.hail_gsa_keys :
    type => jsondecode(lookup(key.data, "key.json"))
  }
  hail_tokens = {
    for type, key in data.kubernetes_secret.hail_tokens :
    type => jsondecode(lookup(key.data, "tokens.json"))
  }

  dataset_permissions = {
    test       = concat(var.definition.access_accounts.test, [local.hail_accounts.test.appId])
    standard   = concat(var.definition.access_accounts.standard, [local.hail_accounts.standard.appId])
    full       = concat(var.definition.access_accounts.full, [local.hail_accounts.full.appId, var.deployment_ids.web_app_id])
    web-access = concat(var.definition.access_accounts.access, var.definition.access_accounts.web-access)
    access     = var.definition.access_accounts.access
  }

  sample_metadata_permissions = {
    main-read = concat(
      module.access_groups["test"].login_ids,
      module.access_groups["standard"].login_ids,
      module.access_groups["full"].login_ids,
      module.access_groups["access"].login_ids,
    )
    main-write = concat(
      module.access_groups["standard"].login_ids,
      module.access_groups["full"].login_ids,
    )
    test-read = concat(
      module.access_groups["test"].login_ids,
      module.access_groups["full"].login_ids,
      module.access_groups["access"].login_ids,
    )
    test-write = concat(
      module.access_groups["test"].login_ids,
      module.access_groups["full"].login_ids,
      module.access_groups["access"].login_ids,
    )
  }

  storage_roles = {
    # TODO GRS Custom roles?
    viewer = "Storage Blob Data Reader"
    writer = "Storage Blob Data Contributor"
    admin  = "Storage Blob Data Owner"
  }

  storage_permissions = {
    archive = [
      { role = "admin", groups = ["full"] }
    ]
    test = [
      { role = "admin", groups = ["test", "standard", "full", "access"] }
    ]
    test-upload = [
      { role = "admin", groups = ["test", "standard", "full", "access"] }
    ]
    test-tmp = [
      { role = "admin", groups = ["test", "standard", "full", "access"] }
    ]
    test-analysis = [
      { role = "admin", groups = ["test", "standard", "full", "access"] }
    ]
    test-web = [
      { role = "admin", groups = ["test", "standard", "full", "access"] }
    ]
    main = [
      { role = "admin", groups = ["full"] },
      { role = "writer", groups = ["standard"] },
      { role = "viewer", groups = ["access"] }
    ]
    main-upload = [
      { role = "admin", groups = ["full"] },
      { role = "writer", groups = ["standard"] },
      { role = "viewer", groups = ["access"] }
    ]
    main-tmp = [
      { role = "admin", groups = ["full"] },
      { role = "writer", groups = ["standard"] },
      { role = "viewer", groups = ["access"] }
    ]
    main-analysis = [
      { role = "admin", groups = ["full"] },
      { role = "writer", groups = ["standard"] },
      { role = "viewer", groups = ["access"] }
    ]
    main-web = [
      { role = "admin", groups = ["full"] },
      { role = "writer", groups = ["standard"] },
      { role = "viewer", groups = ["access"] }
    ]
    hail = []
  }

  # Helper variable to flatten into list.
  storage_permissions_set = flatten([
    for container_name, permissions in local.storage_permissions : flatten([
      for permission in permissions : [
        for group in permission.groups : {
          scope = container_name
          role  = permission.role
          group = group
        }
      ]
    ])
  ])
}
