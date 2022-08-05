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
# Use specific SP set up by init to run Terraform operations.
provider "azurerm" {
  features {}
  subscription_id = var.deployment_principal.subscription_id
  tenant_id       = var.deployment_principal.tenant_id
  client_id       = var.deployment_principal.client_id
  client_secret   = var.deployment_principal.client_secret
}
provider "azuread" {
  tenant_id     = var.deployment_principal.tenant_id
  client_id     = var.deployment_principal.client_id
  client_secret = var.deployment_principal.client_secret
}
