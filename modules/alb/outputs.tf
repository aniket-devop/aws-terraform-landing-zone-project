output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB."
  value       = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "ARN of the target group EC2 instances should attach to."
  value       = aws_lb_target_group.app.arn
}
