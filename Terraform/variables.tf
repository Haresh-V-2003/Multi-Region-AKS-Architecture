variable "global_location" {
  type        = string
  default     = "eastus"
  description = "The primary tracking home location for the main global control plane resources."
}

variable "global_resource_group_name" {
  type        = string
  default     = "rg-multiregion-aks"
  description = "The definitive structural system name for the parent resource group."
}

variable "acr_name" {
  type        = string
  default     = "acrmultiregionglobal026"
  description = "The globally unique alphanumeric key name identifier for your geo-replicated container registry."
}

variable "frontdoor_profile_name" {
  type        = string
  default     = "fd-global-aks-routing"
  description = "The configuration profile tracking identifier for your Global Front Door instantiation."
}

variable "frontdoor_endpoint_name" {
  type        = string
  default     = "fdep-globalaks-endpoint026"
  description = "The unique public-facing edge domain token for your Front Door entrance node."
}

variable "fleet_manager_name" {
  type        = string
  default     = "aks-global-fleet"
  description = "The core system identity token assigned to your Azure Kubernetes Fleet Controller."
}
