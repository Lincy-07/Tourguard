terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  # Remote state in Azure Storage. Values come from environments/backend-dev.hcl:
  #   terraform init -backend-config=../environments/backend-dev.hcl
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}
