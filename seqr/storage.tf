
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
