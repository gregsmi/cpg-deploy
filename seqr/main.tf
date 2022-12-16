variable "location" {
  type = string
}

resource "random_id" "rg_name_suffix" {
  byte_length = 4
}

resource "azurerm_resource_group" "rg" {
  name     = "seqr-${random_id.rg_name_suffix.hex}"
  location = var.location
}

module "postgres_db" {
  source = "./modules/db"

  resource_group = azurerm_resource_group.rg
  subnet_id      = azurerm_subnet.db_subnet.id
  database_names = ["reference_data_db", "seqrdb"]
}

resource "azurerm_kubernetes_cluster" "cluster" {
  name                = "seqr-aks"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  dns_prefix          = "aks0"

  default_node_pool {
    name           = "default"
    vm_size        = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.k8s_subnet.id

    enable_auto_scaling = true

    min_count = 1
    max_count = 5
  }

  identity {
    type = "SystemAssigned"
  }
}
