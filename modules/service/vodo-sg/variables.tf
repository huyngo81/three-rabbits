variable "security_group_name" {
  type = "string"
  description = "sg-group-allow-80-443"
  default = "Allow_22_80_443"
}

variable "vpc_id" {
  type = "string"
  description = "vpc_id"  
}

variable "tcp_ports" {
  default = "default_null"
}

variable "udp_ports" {
  default = "default_null"
}

variable "cidrs" {
  type = "string"
}

variable "port_list" {
  type = "string"
  description = "port_list"
  default = "22,80,443"
}