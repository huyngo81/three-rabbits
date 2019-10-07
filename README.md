# Introduction:
  This three-rabbits is sample terraform project with three version.
  + Version 1: (gfg)
    - Terraform: deploy new VPC with public subnet, ec2 instance with public ip, rds with public ip encrypted by KMS, security group allow only ec2 instance
    - Ansible: Deploy a simple web application with database user and pass on AWS Secret Manager
    
  + Version 2: 
    - Terraform: deploy new VPC with 3 AZ, each zone has two public and private subnet, internet gateway, nat gateway, elb, asg,  rds with public ip encrypted by KMS, 
    RDS and EC2 instance is on private subnet access via ELB and go out via NAT Gateway
    - Ansible: deploy web scale application 3 EC2 using dynamic inventory ec2.py, ec2.ini base on aws tags

  + Version 3: 
    - Terraform: deploy new VPC with 3 AZ, each zone has two public and private subnet, internet gateway, nat gateway, elb, asg,  rds with public ip encrypted by KMS, 
    RDS and EC2 instance is on private subnet access via ELB and go out via NAT Gateway
    - Ansible: input a deploy type: ec2instance, ecs, fargate, lambda to deploy sample web applycation base on input

  ## How to run: 
  terraform workspace new development
  terraform init
  terraform plan
  terraform apply




