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
  sku_tier            = "Free"
  sku_size            = "Free"

  repository_url    = "https://github.com/${var.github_owner}/${var.github_repo}"
  repository_branch = "main"
  repository_token  = var.github_pat
}

resource "azurerm_static_web_app_custom_domain" "apex" {
  count = var.add_custom_domain ? 1 : 0

  static_web_app_id = azurerm_static_web_app.hugo.id
  domain_name       = var.custom_domain
  validation_type   = "dns-txt-token"
}


# Output the default hostname of the Static Web App
output "website_url" {
  description = "The primary URL for the website. Displays the custom domain if enabled."
  value = var.add_custom_domain ? "https://${var.custom_domain}" : "https://${azurerm_static_web_app.hugo.default_host_name}"
}

output "custom_domain_validation_token" {
  description = "The TXT token needed to validate the custom domain."
  sensitive   = true
  value       = var.add_custom_domain ? azurerm_static_web_app_custom_domain.apex[0].validation_token : "Custom domain not created. Set add_custom_domain to true to get a token."
}
