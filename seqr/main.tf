resource "azurerm_resource_group" "rg" {
  name     = "${var.deployment_name}-rg"
  location = var.location
}

module "postgres_db" {
  source = "./modules/db"

  resource_group = azurerm_resource_group.rg
  subnet_id      = azurerm_subnet.pg_subnet.id
  database_names = ["reference_data_db", "seqrdb"]
}

# resource "azurerm_elastic_cloud_elasticsearch" "elastic_search" {
#   name                        = "seqr-es"
#   resource_group_name         = azurerm_resource_group.rg.name
#   location                    = azurerm_resource_group.rg.location
#   sku_name                    = "ess-monthly-consumption_Monthly"
#   elastic_cloud_email_address = "gregsmi@microsoft.com"
# }

locals {
  k8s_secrets = {
    # Secrets to place in k8s for consumption by SEQR service.
    postgres-secrets = {
      password = module.postgres_db.credentials.password
    }
    seqr-secrets = {
      django_key = "random"
      # seqr_es_password required here as well if the SEQR
      # helm template has enable_elasticsearch_auth set
    }
  }
}

module "k8s_cluster" {
  source = "./modules/k8s"

  resource_group = azurerm_resource_group.rg
  subnet_id      = azurerm_subnet.k8s_subnet.id
  secrets        = local.k8s_secrets
}
