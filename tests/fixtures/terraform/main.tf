terraform {
  required_version = ">= 1.6"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "ci"

  validation {
    condition     = contains(["ci", "dev", "stage", "prod"], var.environment)
    error_message = "environment must be one of ci, dev, stage, prod."
  }
}

locals {
  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "terraform_data" "marker" {
  input = local.labels
}

output "labels" {
  description = "Labels applied to the fixture"
  value       = terraform_data.marker.output
}
