output "resource_group" {
  value = azurerm_resource_group.rg.name
}

output "vm_public_ip" {
  description = "Public IP of the web VM. The pipeline reads this to deploy."
  value       = module.compute.public_ip
}

output "ssh_command" {
  value = "ssh ${var.admin_username}@${module.compute.public_ip}"
}

output "app_url" {
  value = "http://${module.compute.public_ip}"
}
