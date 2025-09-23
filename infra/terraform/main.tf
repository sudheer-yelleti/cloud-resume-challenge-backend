# Create resource groups in each subscription
resource "azurerm_resource_group" "resource_group" {
  name     = "${var.resource_group_name}-${terraform.workspace}"
  location = "West US"
}

resource "azurerm_resource_group" "resource_group_common" {
  name     = "${var.resource_group_name}-common"
  location = "West US"
}

resource "azurerm_storage_account" "visitorcounter" {
  name                            = "visitorcounterstgacc${terraform.workspace}"
  resource_group_name             = azurerm_resource_group.resource_group.name
  location                        = azurerm_resource_group.resource_group.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false

  tags = {
    environment = terraform.workspace
  }

}

resource "azurerm_storage_account" "remotestate" {
  name                            = "stgaccremotestate"
  resource_group_name             = azurerm_resource_group.resource_group_common.name
  location                        = azurerm_resource_group.resource_group_common.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false

  tags = {
    environment = terraform.workspace
  }

}

resource "azurerm_storage_account_static_website" "staticwebsite" {
  storage_account_id = azurerm_storage_account.visitorcounter.id
  error_404_document = "custom_not_found.html"
  index_document     = "index.html"
}
# For storing the terraform state backend
resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.remotestate.id
  container_access_type = "private"

}

resource "azurerm_cdn_frontdoor_profile" "my_front_door" {
  name                = local.front_door_profile_name
  resource_group_name = azurerm_resource_group.resource_group.name
  sku_name            = var.front_door_sku_name
}

resource "azurerm_cdn_frontdoor_endpoint" "fd_endpoint" {
  name                     = local.front_door_endpoint_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
}

resource "azurerm_cdn_frontdoor_route" "fd_route" {
  name                          = local.front_door_route_name
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.fd_endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.fd_origin_group.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.fd_origin.id]

  patterns_to_match   = ["/*"]
  forwarding_protocol = "HttpsOnly"
  supported_protocols = ["Https", "Http"]

  cache {
    query_string_caching_behavior = "IgnoreQueryString"
    compression_enabled           = true
    content_types_to_compress     = ["text/html", "text/css", "application/javascript", "application/json"]
  }
}

resource "azurerm_cdn_frontdoor_origin_group" "fd_origin_group" {
  name                     = local.front_door_origin_group_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
  session_affinity_enabled = true

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "fd_origin" {
  name                           = local.front_door_origin_name
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.fd_origin_group.id
  host_name                      = azurerm_storage_account.visitorcounter.primary_web_host
  origin_host_header             = azurerm_storage_account.visitorcounter.primary_web_host
  certificate_name_check_enabled = false
  enabled                        = "true"
}

# Create a storage account for azure function app
resource "azurerm_storage_account" "functionstorageaccount" {
  name                     = "visitorazfuncstgacc${terraform.workspace}"
  resource_group_name      = azurerm_resource_group.resource_group.name
  location                 = azurerm_resource_group.resource_group.location
  account_tier             = var.sa_account_tier
  account_replication_type = var.sa_account_replication_type
}

# Create a storage container
resource "azurerm_storage_container" "functionstoragecontainer" {
  name                  = "flexcontainer"
  storage_account_id    = azurerm_storage_account.functionstorageaccount.id
  container_access_type = "private"
}

# Create a service plan
resource "azurerm_service_plan" "appplan" {
  name                = "visitorfuncappserviceplan-${terraform.workspace}"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = "West US 2"
  sku_name            = "Y1"
  os_type             = "Linux"
}

# Create a function app
resource "azurerm_linux_function_app" "azfunction" {
  name                       = "GetVisitorData"
  resource_group_name        = azurerm_resource_group.resource_group.name
  location                   = "West US 2"
  storage_account_name       = azurerm_storage_account.functionstorageaccount.name
  service_plan_id            = azurerm_service_plan.appplan.id
  storage_account_access_key = azurerm_storage_account.functionstorageaccount.primary_access_key
  identity { type = "SystemAssigned" }

  site_config {
    application_stack {
      python_version = "3.11"
    }
    cors {
      allowed_origins = [
        "https://portal.azure.com",
        "https://${azurerm_cdn_frontdoor_endpoint.fd_endpoint.host_name}",
        "https://${azurerm_cdn_frontdoor_origin.fd_origin.host_name}"
      ]
      support_credentials = true
    }
  }

  app_settings = {
    "CosmosDBTableConnection__accountEndpoint" = "https://${azurerm_cosmosdb_account.db.name}.table.cosmos.azure.com:443/"
    "CosmosDBTableConnection__credential"      = "managedidentity"
    "CosmosDBTableConnection__accountName"     = azurerm_cosmosdb_table.table.account_name
  }

  depends_on = [azurerm_service_plan.appplan]
}

resource "azurerm_cosmosdb_account" "db" {
  name                = "visitorinfo-cosmos-db-${terraform.workspace}"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  capabilities {
    name = "EnableTable"
  }

  consistency_policy {
    consistency_level = "Session"
  }
  geo_location {
    location          = azurerm_resource_group.resource_group.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_table" "table" {
  name                = "visitor"
  resource_group_name = azurerm_cosmosdb_account.db.resource_group_name
  account_name        = azurerm_cosmosdb_account.db.name
  throughput          = 400
}


# Custom Role Definition
resource "azurerm_cosmosdb_sql_role_definition" "readonly" {
  name                = "CosmosDBReadOnlyRole"
  resource_group_name = azurerm_cosmosdb_account.db.resource_group_name
  account_name        = azurerm_cosmosdb_account.db.name
  type                = "CustomRole"

  assignable_scopes = [
    azurerm_cosmosdb_account.db.id
  ]

  permissions {
    data_actions = [
      "Microsoft.DocumentDB/databaseAccounts/readMetadata",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/readChangeFeed",
    ]
  }
}

resource "azurerm_cosmosdb_sql_role_definition" "readwrite" {
  name                = "CosmosDBReadWriteRole"
  resource_group_name = azurerm_cosmosdb_account.db.resource_group_name
  account_name        = azurerm_cosmosdb_account.db.name
  type                = "CustomRole"

  # Best practice: scope to your Cosmos DB account, not "/"
  assignable_scopes = [
    azurerm_cosmosdb_account.db.id
  ]

  permissions {
    data_actions = [
      "Microsoft.DocumentDB/databaseAccounts/readMetadata",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*",
    ]
  }
}


# Role Assignment to Function App's Managed Identity
resource "azurerm_cosmosdb_sql_role_assignment" "readonly_assignment" {
  resource_group_name = azurerm_cosmosdb_account.db.resource_group_name
  account_name        = azurerm_cosmosdb_account.db.name

  # Principal = the Function App's system-assigned identity object_id
  principal_id = azurerm_linux_function_app.azfunction.identity[0].principal_id

  # Scope must match one of the assignable_scopes in the role definition
  scope = azurerm_cosmosdb_account.db.id

  role_definition_id = azurerm_cosmosdb_sql_role_definition.readonly.id
}

resource "azurerm_cosmosdb_sql_role_assignment" "writeonly_assignment" {
  resource_group_name = azurerm_cosmosdb_account.db.resource_group_name
  account_name        = azurerm_cosmosdb_account.db.name

  # Principal = the Function App's system-assigned identity object_id
  principal_id = azurerm_linux_function_app.azfunction.identity[0].principal_id

  # Scope must match one of the assignable_scopes in the role definition
  scope = azurerm_cosmosdb_account.db.id

  role_definition_id = azurerm_cosmosdb_sql_role_definition.readwrite.id
}


locals {
  front_door_profile_name      = "profile-cloud-resume-challenge-${terraform.workspace}"
  front_door_endpoint_name     = "endpoint-cloud-resume-challenge-${terraform.workspace}"
  front_door_origin_group_name = "origin-group-cloud-resume-challenge-${terraform.workspace}"
  front_door_origin_name       = "origin-${azurerm_storage_account.visitorcounter.name}"
  front_door_route_name        = "route-${azurerm_storage_account.visitorcounter.name}"
}
