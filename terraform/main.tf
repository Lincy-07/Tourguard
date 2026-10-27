locals {
  # Tags passed in by the pipeline are checked by policy/plan/tags.rego before apply.
  tags = merge(var.tags, { managed_by = "terraform" })
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-${var.environment}-rg"
  location = var.location
  tags     = local.tags
}

module "network" {
  source              = "./modules/network"
  prefix              = "${var.prefix}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  vnet_cidr           = var.vnet_cidr
  subnet_cidr         = var.subnet_cidr
  allowed_ssh_cidr    = var.allowed_ssh_cidr
  tags                = local.tags
}

module "compute" {
  source              = "./modules/compute"
  prefix              = "${var.prefix}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = module.network.subnet_id
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  ssh_public_key      = var.ssh_public_key
  cloud_init          = file("${path.module}/cloud-init.yaml")
  tags                = local.tags
}
