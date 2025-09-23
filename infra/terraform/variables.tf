variable "subscription_id" {
  type = map(any)
  default = {
    "dev"  = "42e2b662-8043-48d1-a3f2-5fc357ca1bbd"
    "prod" = "9c0565dd-cb68-4912-83c8-5b78dac83415"
  }
}

variable "resource_group_name" {
  type    = string
  default = "cloud-resume-challenge"
}

variable "front_door_sku_name" {
  type        = string
  description = "The SKU for the Front Door profile. Possible values include: Standard_AzureFrontDoor, Premium_AzureFrontDoor"
  default     = "Standard_AzureFrontDoor"
  validation {
    condition     = contains(["Standard_AzureFrontDoor", "Premium_AzureFrontDoor"], var.front_door_sku_name)
    error_message = "The SKU value must be one of the following: Standard_AzureFrontDoor, Premium_AzureFrontDoor."
  }
}

variable "sa_account_tier" {
  description = "The tier of the storage account. Possible values are Standard and Premium."
  type        = string
  default     = "Standard"
}

variable "sa_account_replication_type" {
  description = "The replication type of the storage account. Possible values are LRS, GRS, RAGRS, and ZRS."
  type        = string
  default     = "LRS"
}

variable "runtime_name" {
  description = "The name of the language worker runtime."
  type        = string
  default     = "python" # Allowed: dotnet-isolated, java, node, powershell, python
}

variable "runtime_version" {
  description = "The version of the language worker runtime."
  type        = string
  default     = "3.11" # Supported versions: see https://aka.ms/flexfxversions
}