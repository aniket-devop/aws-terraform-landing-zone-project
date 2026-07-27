# outputs.tf (root)

output "vpc_id" {
  description = "ID of the created VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateway(s)."
  value       = module.vpc.nat_gateway_ids
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer — use this to hit the app."
  value       = module.alb.alb_dns_name
}

output "ec2_instance_ids" {
  description = "IDs of the EC2 instances in the private subnets."
  value       = module.ec2.instance_ids
}

output "ec2_private_ips" {
  description = "Private IP addresses of the EC2 instances."
  value       = module.ec2.private_ips
}
