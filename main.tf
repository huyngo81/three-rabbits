provider aws {
  region = "${var.aws_region}"
  #  shared_credentials_file = "${var.credential_path}"
  #  profile                 = "${terraform.workspace}"
}

module "vpc" {
  source   = "./modules/service/vodo"
  app_name = "${var.app_name}"
}

#module "allow_ssh_http_https" {
#  source = "./modules/service/vodo-sg"
#  vpc_id = "${module.vpc.vpc_id}"
#  tcp_ports           = "${var.port_list}"
#  cidrs               = "${module.vpc.vpc_cidr}"  
#}



