terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }
}

# 1. Virtual Networks (Hub & Spoke Pattern)
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-${var.region_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.hub_cidr]
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet" # Mandatory Azure designation
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.fw_subnet_cidr]
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-spoke-${var.region_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.spoke_cidr]
}

resource "azurerm_subnet" "appgw" {
  name                 = "sb-appgw"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.appgw_subnet_cidr]
}

resource "azurerm_subnet" "aks" {
  name                 = "sb-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.aks_subnet_cidr]
}

# 2. VNet Peering Fabric
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-hub-to-spoke-${var.region_name}"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-spoke-to-hub-${var.region_name}"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
}

# 3. Dedicated Regional Ingress Layer (Application Gateway)
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-${var.region_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "ingress" {
  name                = "appgw-${var.region_name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-ip-configuration"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = "port-http"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  backend_address_pool {
    name = "aks-backend-pool"
  }

  backend_http_settings {
    name                  = "http-setting"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name             = "port-http"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule-default"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "aks-backend-pool"
    backend_http_settings_name = "http-setting"
    priority                   = 100
  }
}

# 4. Azure Kubernetes Service (AKS) Private Cluster Deployment
resource "azurerm_kubernetes_cluster" "aks" {
  name                    = "aks-${var.region_name}"
  location                = var.location
  resource_group_name     = var.resource_group_name
  dns_prefix              = "aks-dns-${var.region_name}"
  private_cluster_enabled = true

  default_node_pool {
    name            = "systempool"
    node_count      = 2
    vm_size         = "Standard_D2s_v5"
    vnet_subnet_id  = azurerm_subnet.aks.id
    os_disk_size_gb = 50
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "userDefinedRouting"
  }

  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.ingress.id
  }
}
