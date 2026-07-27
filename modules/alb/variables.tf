variable "name_prefix" {
  description = "Prefix applied to all resource names in this module."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID the ALB and target group belong to."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs to place the ALB in (needs 2+ AZs)."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID to attach to the ALB."
  type        = string
}

variable "app_port" {
  description = "Port the target group forwards traffic to on the EC2 instances."
  type        = number
}

variable "health_check_path" {
  description = "HTTP path used for target group health checks."
  type        = string
  default     = "/"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
