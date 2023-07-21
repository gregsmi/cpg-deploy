
# Use main deployment storage account for config container.
data "azurerm_storage_account" "main" {
  name                = "${var.deployment_name}sa"
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Create a reference container for k8s mounted ref volumes.
resource "azurerm_storage_container" "reference" {
  name                  = "reference"
  storage_account_name  = data.azurerm_storage_account.main.name
  container_access_type = "blob"
}

# Reference to storage accounts where data may be pulled from by 
# loading jobs - these will be configured for hadoop abfss access.
data "azurerm_storage_account" "data" {
  # TODO Read these in from an infrastructure config file?
  for_each            = { azcpg001sa = "azcpg001-rg" }
  name                = each.key
  resource_group_name = each.value
}

locals {
  # core-site.xml is a default config file for spark/hadoop that
  # the azure abfss driver will use for storage account credentials.
  # TODO Consider switching from account key to service principal.
  hadoop_core_site_xml = <<-EOT
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>

  %{~for account in data.azurerm_storage_account.data~}
  <property>
    <name>fs.azure.account.key.${account.name}.dfs.core.windows.net</name>
    <value>${account.primary_access_key}</value>
  </property>
  %{~endfor~}
  
</configuration>
EOT
}

resource "kubernetes_persistent_volume" "reference" {
  metadata {
    name = "reference-volume"
    annotations = {
      "pv.kubernetes.io/provisioned-by" = "blob.csi.azure.com"
    }
  }
  spec {
    capacity = {
      storage = "50Gi"
    }
    access_modes                     = ["ReadOnlyMany"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "azureblob-fuse-premium"
    mount_options                    = ["-o allow_other"]
    persistent_volume_source {
      csi {
        driver        = "blob.csi.azure.com"
        volume_handle = "${data.azurerm_storage_account.main.name}_${azurerm_storage_container.reference.name}"
        read_only     = true
        volume_attributes = {
          # The name of the storage account is stored in blobstore-secrets.
          resourceGroup = data.azurerm_resource_group.rg.name
          containerName = azurerm_storage_container.reference.name
        }
        node_stage_secret_ref {
          name      = "blobstore-secrets"
          namespace = "default"
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "reference" {
  metadata {
    name = "reference-volume-claim"
  }
  spec {
    access_modes = ["ReadOnlyMany"]
    resources {
      requests = {
        storage = "50Gi"
      }
    }
    volume_name        = "reference-volume"
    storage_class_name = "azureblob-fuse-premium"
  }
}
