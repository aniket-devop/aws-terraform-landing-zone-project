output "ec2_role_name" {
  description = "Name of the EC2 IAM role."
  value       = aws_iam_role.ec2_role.name
}

output "ec2_role_arn" {
  description = "ARN of the EC2 IAM role."
  value       = aws_iam_role.ec2_role.arn
}

output "instance_profile_name" {
  description = "Name of the instance profile to attach to EC2 instances."
  value       = aws_iam_instance_profile.ec2_profile.name
}
