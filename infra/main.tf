terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "terraform"
    storage_account_name = "tfstatehugo793"
    container_name       = "tfstate"
    key                  = "hugo.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
}

# Create a resource group for the application
resource "azurerm_resource_group" "hugo" {
  name     = var.project_name
  location = var.location
}

# Create a free static web app
resource "azurerm_static_web_app" "hugo" {
  name                = var.project_name
  resource_group_name = azurerm_resource_group.hugo.name
  location            = azurerm_resource_group.hugo.location

  # The SKU is "Free" or "Standard"
  sku_tier = "Free" 
  sku_size = "Free"
}

# Output the default hostname of the Web App
output "website_url" {
  value = "https://${azurerm_linux_web_app.app_wa.default_hostname}"
}