output "aks_id" {
  value       = azurerm_kubernetes_cluster.aks.id
  description = "The target structural system string identifying the managed AKS engine resource."
}

output "appgw_public_ip" {
  value       = azurerm_public_ip.appgw.ip_address
  description = "The static destination target IP address of the Regional Application Gateway mapping."
}
