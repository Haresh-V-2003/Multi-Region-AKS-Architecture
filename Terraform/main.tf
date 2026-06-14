terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Master Shared Core Resource Container Group
resource "azurerm_resource_group" "global" {
  name     = var.global_resource_group_name
  location = var.global_location
}

# 1. Global Container Security (ACR Premium with Live Geo-Replication)
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.global.name
  location            = azurerm_resource_group.global.location
  sku                 = "Premium" 
  admin_enabled       = false

  georeplications {
    location                = "westus"
    zone_redundancy_enabled = false
  }
}

# 2. Regional Stamp: Region A (East US)
module "stamp_east" {
  source              = "./modules/regional_stamp"
  region_name         = "east"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.global.name

  hub_cidr          = "10.1.0.0/16"
  fw_subnet_cidr    = "10.1.0.0/24"
  spoke_cidr        = "10.2.0.0/16"
  appgw_subnet_cidr = "10.2.0.0/24"
  aks_subnet_cidr   = "10.2.1.0/24"
}

# 3. Regional Stamp: Region B (West US)
module "stamp_west" {
  source              = "./modules/regional_stamp"
  region_name         = "west"
  location            = "westus"
  resource_group_name = azurerm_resource_group.global.name

  hub_cidr          = "10.3.0.0/16"
  fw_subnet_cidr    = "10.3.0.0/24"
  spoke_cidr        = "10.4.0.0/16"
  appgw_subnet_cidr = "10.4.0.0/24"
  aks_subnet_cidr   = "10.4.1.0/24"
}

# 4. Azure Kubernetes Fleet Manager Control Plane Configuration
resource "azurerm_kubernetes_fleet_manager" "fleet" {
  name                = var.fleet_manager_name
  location            = azurerm_resource_group.global.location
  resource_group_name = azurerm_resource_group.global.name
}

resource "azurerm_kubernetes_fleet_member" "east_member" {
  name                  = "east-cluster-member"
  kubernetes_fleet_id   = azurerm_kubernetes_fleet_manager.fleet.id
  kubernetes_cluster_id = module.stamp_east.aks_id
  group                 = "group-1"
}

resource "azurerm_kubernetes_fleet_member" "west_member" {
  name                  = "west-cluster-member"
  kubernetes_fleet_id   = azurerm_kubernetes_fleet_manager.fleet.id
  kubernetes_cluster_id = module.stamp_west.aks_id
  group                 = "group-2"
}

# 5. Global Layer 7 Ingress Routing (Azure Front Door Premium)
resource "azurerm_cdn_frontdoor_profile" "fd" {
  name                = var.frontdoor_profile_name
  resource_group_name = azurerm_resource_group.global.name
  sku_name            = "Premium_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "endpoint" {
  name                     = var.frontdoor_endpoint_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id
}

resource "azurerm_cdn_frontdoor_origin_group" "og" {
  name                     = "aks-origin-pool-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id
  session_affinity_enabled = false

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/"
    protocol            = "Http"
    interval_in_seconds = 30
    request_type        = "HEAD"
  }
}

# Origin Target Mapping: Region A (East US Application Gateway)
resource "azurerm_cdn_frontdoor_origin" "east" {
  name                           = "origin-target-east"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.og.id
  enabled                        = true
  certificate_name_check_enabled = false
  host_name                      = module.stamp_east.appgw_public_ip
  http_port                      = 80
}

# Origin Target Mapping: Region B (West US Application Gateway)
resource "azurerm_cdn_frontdoor_origin" "west" {
  name                           = "origin-target-west"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.og.id
  enabled                        = true
  certificate_name_check_enabled = false
  host_name                      = module.stamp_west.appgw_public_ip
  http_port                      = 80
}

resource "azurerm_cdn_frontdoor_route" "route" {
  name                          = "default-application-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.og.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.east.id, azurerm_cdn_frontdoor_origin.west.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpOnly"
  link_to_default_domain = true
}
