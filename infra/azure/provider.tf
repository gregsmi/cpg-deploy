terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.67.0"
    }
    # Using azuread provider to create Apps/SPs requires Application 
    # Administrator role or Application.ReadWrite.All API perms
    azuread = {
      source  = "hashicorp/azuread"
      version = "=2.2.1"
    }
    # kubernetes = {
    #   source  = "hashicorp/kubernetes"
    #   version = "2.2.0"
    # }
  }
}

# Use Azure blob store to manage tfstate
terraform {
  backend "azurerm" {}
}

# provider "azuread" {}

# Configure the Azure provider
provider "azurerm" {
  features {}
  # Provider registrations (Microsoft.DataProtection, Microsoft.AVS) require 
  # subscription-level permissions, so they must be registered ahead of time
  skip_provider_registration = true
}

# Master resource group for deployment (unmanaged)
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}
