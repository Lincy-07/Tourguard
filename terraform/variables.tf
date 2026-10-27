variable "prefix" {
  description = "Short name prefix applied to every resource."
  type        = string
  default     = "tourguard"
}

variable "environment" {
  description = "Environment name (dev / prod)."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region. Change it if your subscription policy blocks this one."
  type        = string
  default     = "centralindia"
}

variable "vm_size" {
  description = "VM size. The OPA policy only allows sizes listed in policy/data.json."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Linux admin user on the VM."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key text. Set with: export TF_VAR_ssh_public_key=\"$(cat ~/.ssh/id_rsa.pub)\""
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "Source CIDR allowed to SSH. '*' is easy but the policy raises a warning for it."
  type        = string
  default     = "*"
}

variable "vnet_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.20.1.0/24"
}

variable "tags" {
  description = "Governance tags. The OPA policy blocks the pipeline if owner, environment, project or cost_center is missing."
  type        = map(string)
  default     = {}
}
