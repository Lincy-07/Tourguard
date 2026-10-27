# Remote state location (created once in the setup guide). Names only, no secrets.
resource_group_name  = "tourguard-tfstate-rg"
storage_account_name = "tourguardlincy2026"
container_name       = "tfstate"
key                  = "tourguard.dev.tfstate"
use_azuread_auth     = true