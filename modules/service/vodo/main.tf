###############################################################
# This module to create a mini stack vpc, ec2, rds, kms 
###############################################################

# Make sure environment had been define and cidr had been define
locals {
  environment   = "${lookup(var.workspace_to_environment, terraform.workspace, var.default_environment)}"
  cidr          = "${lookup(var.workspace_to_cidr, terraform.workspace, var.workspace_to_cidr[var.default_environment])}"
  public_range  = "${lookup(var.subnets_map, "${terraform.workspace}_public", var.subnets_map["${var.default_environment}_public"])}"
  private_range = "${lookup(var.subnets_map, "${terraform.workspace}_private", var.subnets_map["${var.default_environment}_private"])}"
  instance_type = "${lookup(var.workspace_to_instance_type, "${terraform.workspace}", var.workspace_to_instance_type["${var.default_environment}"])}"
  db_type       = "${lookup(var.db_instance_type, "${terraform.workspace}", var.db_instance_type["${var.default_environment}"])}"
}



# Create public and private key to use as ssh key pair
resource "tls_private_key" "vodo" {
  algorithm = "RSA"
  rsa_bits  = "1024"
}

resource "local_file" "vodo_id_rsa" {
  content  = <<EOF
${tls_private_key.vodo.private_key_pem}
EOF
  filename = "/root/.ssh/vodo_id_rsa"
  provisioner "local-exec" {
    command = "chmod 400 /root/.ssh/vodo_id_rsa"
  }
}

# Get availability zone
data "aws_availability_zones" "vodo_zones" {
  state = "available"
}


########################################################################################
########################## Create VPC, public, private subnet ##########################
########################################################################################

module "vodo_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name            = "${var.app_name}"
  cidr            = "${local.cidr}"
  azs             = "${data.aws_availability_zones.vodo_zones.names}"
  private_subnets = "${local.private_range}"
  public_subnets  = "${local.public_range}"

  enable_nat_gateway = false
  enable_vpn_gateway = false
  single_nat_gateway = false
  tags = {
    app = "${var.app_name}"
    env = "${terraform.workspace}"
  }
  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = true

  enable_dns_hostnames = true
  enable_dns_support   = true
}

###################################################################################
######################### Create key, kms, EC2ReadOnly policy, attach to role #####
###################################################################################
# Create aws_keypair for ec2
resource "aws_key_pair" "vodo" {
  key_name   = "${var.app_name}"
  public_key = "${tls_private_key.vodo.public_key_openssh}"
}

# Create KMS key and alias
resource "aws_kms_key" "mykey" {}
resource "aws_kms_alias" "vodo" {
  name          = "alias/${var.app_name}"
  target_key_id = "${aws_kms_key.mykey.key_id}"
}


# Create custom policy to assume role to EC2 for ssm and kms read only
resource "aws_iam_policy" "ec2_read_only_ssm_kms" {
  name        = "ReadOnlyAccess"
  path        = "/"
  description = "EC2 read only SSM and KMS"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "kms:Describe*",
        "kms:GenerateRandom",
        "kms:Get*",
        "kms:List*",                
        "secretsmanager:Describe*",
        "secretsmanager:Get*",
        "secretsmanager:List*" 
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
  }
 	
EOF
}


# Create ec2 iam role readonly
resource "aws_iam_role" "EC2ReadOnlyAccess" {
  name = "EC2ReadOnlyAccess"

  assume_role_policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
}
EOF
}


# Attach policy readonly to role read-only
resource "aws_iam_role_policy_attachment" "EC2ReadOnlyAccess" {
  role       = "${aws_iam_role.EC2ReadOnlyAccess.name}"
  policy_arn = "${aws_iam_policy.ec2_read_only_ssm_kms.arn}"
}


resource "aws_iam_instance_profile" "EC2ReadOnlyAccess" {
  name = "EC2ReadOnlyAccess"
  role = "${aws_iam_role.EC2ReadOnlyAccess.name}"
}

###############################################################################################
############################### Create security group allow 22,80,443 and postgres sg group ###
###############################################################################################

resource "aws_security_group" "sg_webserver" {
  name        = "${var.sg_webserver}"
  description = "${var.sg_webserver} allow ssh-80-443"
  vpc_id      = "${module.vodo_vpc.vpc_id}"
  tags = {
    Name = "${var.sg_webserver}"
    env  = "${terraform.workspace}"
  }
}

resource "aws_security_group" "sg_postgres" {
  name        = "${var.sg_postgres}"
  description = "${var.sg_postgres} allow postgres port to only webserver"
  vpc_id      = "${module.vodo_vpc.vpc_id}"
  tags = {
    Name = "${var.sg_postgres}"
    env  = "${terraform.workspace}"
  }
}


resource "aws_security_group_rule" "egress" {
  count = "${length(split(",", var.all_sg))}"
  #count = "2"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "All egress traffic"
  depends_on        = ["aws_security_group.sg_webserver", "aws_security_group.sg_postgres"]
  security_group_id = "${element(split(",", "${aws_security_group.sg_webserver.id},${aws_security_group.sg_postgres.id}"), count.index)}"
}



resource "aws_security_group_rule" "webserver" {
  count             = "${var.tcp_ports == "default_null" ? 0 : length(split(",", var.tcp_ports))}"
  type              = "ingress"
  from_port         = "${element(split(",", var.tcp_ports), count.index)}"
  to_port           = "${element(split(",", var.tcp_ports), count.index)}"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = ""
  security_group_id = "${aws_security_group.sg_webserver.id}"
}

# Create postgres rule allow from source security group of webserver

resource "aws_security_group_rule" "postgres" {
  count     = "1"
  type      = "ingress"
  from_port = "${var.postgres_port}"
  to_port   = "${var.postgres_port}"
  protocol  = "tcp"
  #  cidr_blocks       = ["0.0.0.0/0"]
  source_security_group_id = "${aws_security_group.sg_webserver.id}"
  description              = ""
  security_group_id        = "${aws_security_group.sg_postgres.id}"
}

#####################################################################
########### Create EC2 WebServer ####################################
#####################################################################

# Get Amazon Linux 2 AMI
data "aws_ami" "az2" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.20190823.1-x86_64-gp2"]
  }

  owners = ["137112412989"]
}

data "aws_subnet_ids" "public" {
  vpc_id = "${module.vodo_vpc.vpc_id}"
  filter {
    name   = "tag:Name"
    values = ["*public*"]
  }
}

data "aws_subnet_ids" "all_subnets" {
  vpc_id = "${module.vodo_vpc.vpc_id}"
}


resource "random_pet" "webserver" {}


resource "aws_instance" "webserver" {
  count = "${terraform.workspace == "development" ? "1" : "${length(data.aws_subnet_ids.public.ids)}"}"
  #count = "${length(data.aws_subnet_ids.public.ids)}"
  ami           = "${data.aws_ami.az2.id}"
  instance_type = "${local.instance_type}"
  tags = {
    Name = "webserver-${random_pet.webserver.id}"
    env  = "${terraform.workspace}"
  }
  root_block_device {
    volume_size = "16"
  }
  associate_public_ip_address = true
  subnet_id                   = "${element(tolist(data.aws_subnet_ids.public.ids), count.index)}"
  iam_instance_profile        = "${aws_iam_instance_profile.EC2ReadOnlyAccess.name}"
  key_name                    = "${aws_key_pair.vodo.key_name}"
  vpc_security_group_ids      = ["${aws_security_group.sg_webserver.id}"]
  lifecycle {
    create_before_destroy = true
  }

}

################################################################
################## Create and RDS###############################
################################################################

# Generate DB Password random without special character
resource "random_password" "postgres" {
  length  = 16
  special = false
  keepers = {
    user = "${var.db_name}"
  }
}

resource "aws_db_subnet_group" "postgres" {
  name       = "postgres"
  subnet_ids = data.aws_subnet_ids.all_subnets.ids

  tags = {
    Name = "postgres_subnetGroup"
    env  = "${terraform.workspace}"
  }
}

# Deploy Postgres DB
module "postgres" {

  source                    = "terraform-aws-modules/rds/aws"
  db_subnet_group_name      = "${aws_db_subnet_group.postgres.id}"
  identifier                = "${var.db_name}"
  engine                    = "${var.db_name}"
  engine_version            = "11.4"
  instance_class            = "${local.db_type}"
  allocated_storage         = "20"
  name                      = "${var.db_name}"
  username                  = "${var.db_name}"
  password                  = "${random_password.postgres.result}"
  vpc_security_group_ids    = ["${aws_security_group.sg_postgres.id}"]
  backup_retention_period   = 0
  subnet_ids                = data.aws_subnet_ids.all_subnets.ids
  family                    = "postgres11"
  major_engine_version      = "11.4"
  final_snapshot_identifier = "${var.db_name}"
  deletion_protection       = false
  port                      = "5432"
  maintenance_window        = "Mon:00:00-Mon:03:00"
  backup_window             = "03:00-06:00"
  tags = {
    Name = "${var.db_name}"
    env  = "${terraform.workspace}"
  }
  publicly_accessible = true

}

# Store db password to ssm

resource "aws_ssm_parameter" "db_password" {
  name        = "/${terraform.workspace}/database/password/master"
  description = "store database secure password"
  type        = "SecureString"
  value       = "${random_password.postgres.result}"
  tags = {
    env  = "${terraform.workspace}"
    Name = "${var.db_name}_secured_password"
  }
  key_id = "${aws_kms_alias.vodo.arn}"

}
