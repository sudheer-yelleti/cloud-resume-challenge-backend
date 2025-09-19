# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.44.0"
    }
  }
#   backend "azurerm" {
#     resource_group_name  = "tfstate"
#     storage_account_name = "tfstatestgacc"
#     container_name       = "tfstate"
#     key                  = "terraform.tfstate"
#   }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = "8362a864-1a8b-49e7-86c1-9cfdf8850b33"
}

