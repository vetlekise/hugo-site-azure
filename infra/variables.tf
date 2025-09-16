variable "project_name" {
  description = "A unique name for the project, used to name resources."
  type        = string
  default     = "hugo-app"
}

variable "location" {
  description = "The Azure region where resources will be deployed."
  type        = string
  default     = "West Europe"
}

variable "add_custom_domain" {
  description = "Set to true to create the custom domain for the Static Web App."
  type        = bool
  default     = true
}

variable "custom_domain" {
  description = "The custom domain to add to the Static Web App. Only used if add_custom_domain is true."
  type        = string
  default     = "vetle.dev"
}

variable "github_owner" {
  description = "The GitHub owner (username or organization) of the repository."
  type        = string
  default     = "vetlekise"
}

variable "github_repo" {
  description = "The GitHub repository to link the Static Web App to."
  type        = string
  default     = "hugo-site-azure"
}

variable "github_branch" {
  description = "The branch of the GitHub repository to link the Static Web App to."
  type        = string
  default     = "main"
}

variable "github_pat" {
  description = "A GitHub PAT with repo and workflow scopes to link the Static Web App. This value is passed in as a secret in the workflow."
  type        = string
  sensitive   = true
}