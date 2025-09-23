# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.44.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "cloud-resume-challenge-common"
    storage_account_name = "stgaccremotestate"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"

  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription_id[terraform.workspace]
}

