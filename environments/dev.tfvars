# Non-secret settings for the dev environment. Committed to Git on purpose:
# changing vm_size or tags here is what triggers the cost/policy gate in Jenkins.
prefix           = "tourguard"
environment      = "dev"
location         = "indiasouthcentral"
vm_size          = "Standard_B1s"
admin_username   = "azureuser"
allowed_ssh_cidr = "*"

tags = {
  owner       = "lincy"      # <- put your name / roll number
  environment = "dev"
  project     = "tourguard"
  cost_center = "college-lab"
}
