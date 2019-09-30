output "vpc_id" {
  value       = module.vodo_vpc.vpc_id
  description = "output of vpc"
}

output "vodo_public_key" {
  value = tls_private_key.vodo.public_key_openssh
  description = "output of public key demo"
}

output "kms_key_arn" {
  value = aws_kms_alias.vodo.arn
}

output "readonly_policy_arn" {
  value = aws_iam_policy.ec2_read_only_ssm_kms.arn
  description = "read only arn"
}

output "ec2_role_readonly_arn" {
  value = aws_iam_role.EC2ReadOnlyAccess.arn
  description = "EC2 role readonly arn"
}

output "public_range" {
  value = local.public_range
}

