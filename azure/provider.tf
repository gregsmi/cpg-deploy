terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.9.0"
    }
    # Using azuread provider to create Apps/SPs requires Application 
    # Administrator role or Application.ReadWrite.All API perms
    azuread = {
      source  = "hashicorp/azuread"
      version = "=2.18.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "=2.11.0"
    }
  }
}

# Use Azure blob store to manage Terraform state - fill in 
# required fields via -backend-config on terraform init.
terraform {
  backend "azurerm" {}
}

provider "azuread" {
  tenant_id     = "b7e69ef3-619e-4cb7-a4e5-80110816cdf7"
  client_id     = "5f22a86b-27e6-4d8d-9abf-20616d741bf8"
  client_secret = data.azurerm_key_vault_secret.deployment_sp_secret.value
}

provider "azurerm" {
  features {}
}
