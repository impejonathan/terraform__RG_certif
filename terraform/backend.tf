terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-jimpe"
    storage_account_name = "saterraformstatejimpe"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}
 