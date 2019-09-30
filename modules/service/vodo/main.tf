# This module to create a mini stack vpc, ec2, rds, kms

# Make sure environment had been define and cidr had been define
locals {
  environment   = "${lookup(var.workspace_to_environment, terraform.workspace, var.default_environment)}"
  cidr          = "${lookup(var.workspace_to_cidr, terraform.workspace, var.workspace_to_cidr[var.default_environment])}"
  public_range  = "${lookup(var.subnets_map, "${terraform.workspace}_public", var.subnets_map["${var.default_environment}_public"])}"
  private_range = "${lookup(var.subnets_map, "${terraform.workspace}_private", var.subnets_map["${var.default_environment}_private"])}"
  subnet_count  = "${length(lookup(var.subnets_map, "${terraform.workspace}_private", var.subnets_map["${var.default_environment}_private"]))}"
}


# Create public and private key to use as ssh key pair
resource "tls_private_key" "vodo" {
  algorithm = "RSA"
  rsa_bits  = "1024"

}


# get availability zone
data "aws_availability_zones" "vodo_zones" {
  state = "available"
}

# Create a new vpc base on cidr lookup
#resource "aws_vpc" "vodo" {
#  cidr_block = "${local.cidr}"
#  tags = {
#    env  = "${local.environment}"
#    Name = "${var.app_name}"
#  }
#}

#resource "aws_internet_gateway" "cluster_gateway" {
#  vpc_id = "${aws_vpc.vodo.id}"
#}

#resource "aws_subnet" "public_subnet" {
#  count = "${length(local.public_range)}"
#  vpc_id = "${aws_vpc.vodo.id}"
#  cidr_block = "${element(local.public_range,count.index)}"
#  map_public_ip_on_launch = true
#  depends_on = ["aws_internet_gateway.cluster_gateway"]
#  availability_zone = "${element(data.aws_availability_zones.vodo_zones.names,count.index)}"
#}

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
