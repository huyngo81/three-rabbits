provider aws {
  region                  = "${var.aws_region}"
#  shared_credentials_file = "${var.credential_path}"
#  profile                 = "${terraform.workspace}"
}

module "vpc" {
  source   = "./modules/service/vodo"
  app_name = "${var.app_name}"
}



