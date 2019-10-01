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

variable "workspace_to_cidr" {
  type        = "map"
  description = "this variable to map the workspace to cidrs base on workspace name"
  default = {
    development = "172.20.0.0/16"
    production  = "172.16.0.0/16"
  }
}

variable "subnets_map" {
  type = map(list(string))
  default = {
    "development_public"  = ["172.20.200.0/24", "172.20.201.0/24", "172.20.202.0/24"]
    "development_private" = ["172.20.100.0/24", "172.20.101.0/24", "172.20.103.0/24"]
    "production_public"   = ["172.16.200.0/24", "172.16.201.0/24", "172.16.202.0/24"]
    "production_private"  = ["172.16.100.0/24", "172.16.101.0/24", "172.16.103.0/24"]
  }
}

variable "tcp_ports" {
  default = "22,80,443"
}

variable "postgres_port" {
  type        = "string"
  description = "postgres_port"
  default     = "5432"
}

variable "sg_webserver" {
  default = "sg_webserver"
}

variable "sg_postgres" {
  type        = "string"
  description = "sg_postgres"
  default     = "sg_postgres"
}

variable "all_sg" {
  type        = "string"
  description = "all_sg"
  default     = "sg_postgres,sg_webserver"
}

variable "workspace_to_instance_type" {
  type        = "map"
  description = "this variable to map the workspace to cidrs base on workspace name"
  default = {
    development = "t2.micro"
    production  = "t2.medium"
  }
}


