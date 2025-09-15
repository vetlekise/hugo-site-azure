variable "project_name" {
  description = "A unique name for the project, used to name resources."
  type        = string
  default     = ""
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