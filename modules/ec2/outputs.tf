output "instance_ids" {
  description = "IDs of the EC2 instances."
  value       = aws_instance.app[*].id
}

output "private_ips" {
  description = "Private IP addresses of the EC2 instances."
  value       = aws_instance.app[*].private_ip
}
