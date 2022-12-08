terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.34.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "=2.31.0"
    }
  }
}

provider "azurerm" {
  features {}
}
