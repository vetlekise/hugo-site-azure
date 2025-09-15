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