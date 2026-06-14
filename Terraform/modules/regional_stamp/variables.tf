variable "location" {
  type        = string
  description = "The target Azure region for deployment (e.g., eastus)."
}

variable "region_name" {
  type        = string
  description = "A short localized suffix identifier for name structuring (e.g., east, west)."
}

variable "resource_group_name" {
  type        = string
  description = "The target Azure Resource Group container name."
}

variable "hub_cidr" {
  type        = string
  description = "The master virtual network routing prefix for the hub."
}

variable "fw_subnet_cidr" {
  type        = string
  description = "The reserved prefix for Azure Firewall."
}

variable "spoke_cidr" {
  type        = string
  description = "The master virtual network routing prefix for the application spoke."
}

variable "appgw_subnet_cidr" {
  type        = string
  description = "The routing prefix reserved for Application Gateway."
}

variable "aks_subnet_cidr" {
  type        = string
  description = "The routing prefix reserved for AKS nodes and components."
}
