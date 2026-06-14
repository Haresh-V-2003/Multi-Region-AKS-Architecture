output "global_frontdoor_url" {
  value       = azurerm_cdn_frontdoor_endpoint.endpoint.host_name
  description = "The global canonical endpoint URL used to reach your multi-region environment."
}

output "east_ingress_public_ip" {
  value       = module.stamp_east.appgw_public_ip
  description = "The target static IP assigned directly to the East US application load balancer gateway configuration."
}

output "west_ingress_public_ip" {
  value       = module.stamp_west.appgw_public_ip
  description = "The target static IP assigned directly to the West US application load balancer gateway configuration."
}
