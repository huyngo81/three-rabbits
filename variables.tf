variable "aws_region" {
  type    = "string"
  default = "ap-southeast-1"
}

variable "credential_path" {
  type    = "string"
  default = "$HOME/.aws/credentials"
}

variable "app_name" {
  type    = "string"
  default = "vodo"
}

variable "default_environment" {
  type    = "string"
  default = "development"
}

variable "workspace_to_environment" {
  type        = "map"
  description = "map workspace name to environment string"
  default = {
    development = "development"
    production  = "production"
  }
}

