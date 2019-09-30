output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "output of vpc"
}


output "public_key" {
  value       = module.vpc.vodo_public_key
  description = "public key id"
}


output "kms_key_arn" {
  value = module.vpc.kms_key_arn
}

output "readonly_arn_policy" {
  value = module.vpc.readonly_policy_arn
}

output "EC2_read_only_arn" {
  value = module.vpc.ec2_role_readonly_arn
}

output "mo_public_range" {
  value = module.vpc.public_range
}
