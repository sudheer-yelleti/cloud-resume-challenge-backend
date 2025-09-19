# Retrieve the current client configuration to get the Tenant ID
data "azurerm_client_config" "current" {}
data "azurerm_billing_mca_account_scope" "billing" {
  billing_account_name = "12cd9329-fb91-54d2-9782-c40a099cd0d6:41addaf6-2c7d-47f4-a271-ed76e330c27f_2019-05-31"
  billing_profile_name = "5GAG-WODN-BG7-PGB"
  invoice_section_name = "IVYE-4QLS-PJA-PGB"
}

# Create a new Management Group under the Root Tenant Group
resource "azurerm_management_group" "management_groups" {
  for_each = local.environments

  display_name               = each.value.name
  parent_management_group_id = null
}

# Create subscriptions for each environment
resource "azurerm_subscription" "subscriptions" {
  for_each = local.environments

  billing_scope_id  = data.azurerm_billing_mca_account_scope.billing.id
  subscription_name = each.value.name

  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
  depends_on = [azurerm_management_group.management_groups]
}

# Associate subscriptions with management groups
resource "azurerm_management_group_subscription_association" "associations" {
  for_each = local.environments

  management_group_id = azurerm_management_group.management_groups[each.key].id
  subscription_id     = azurerm_subscription.subscriptions[each.key].id
  
  depends_on = [azurerm_subscription.subscriptions]
}

resource "azurerm_resource_group" "tfstate" {
  name     = "tfstate"
  location = "East US"
}

resource "azurerm_storage_account" "tfstate" {
  name                            = "tfstatestgacc"
  resource_group_name             = azurerm_resource_group.tfstate.name
  location                        = azurerm_resource_group.tfstate.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false

  tags = {
    environment = "Dev"
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

# Create resource groups in each subscription
resource "azurerm_resource_group" "resource_groups" {
  for_each = {
    dev  = "cloud-resume-challenge-dev-rg"
    prod = "cloud-resume-challenge-prod-rg"
  }

  name     = each.value
  location = "East US"

  # Use the subscription provider alias if needed
  # depends_on = [azurerm_subscription.subscriptions]
}

locals {
  environments = {
    dev = {
      name = "cloud-resume-challenge-dev"
      resource_group_name = "cloud-resume-challenge-dev-rg"
    }
    prod = {
      name = "cloud-resume-challenge-prod"
      resource_group_name = "cloud-resume-challenge-prod-rg"
    }
  }
}
