variable "name_prefix" {
  description = "Prefix applied to all resource names in this module."
  type        = string
}

variable "instance_count" {
  description = "Number of EC2 instances to launch."
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs to launch instances into (round-robin across list)."
  type        = list(string)
}

variable "ec2_security_group_id" {
  description = "Security group ID to attach to the instances."
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name (grants SSM + scoped app permissions)."
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN to attach each instance to."
  type        = string
}

variable "app_port" {
  description = "Port the demo app listens on (used by user_data)."
  type        = number
}

variable "key_pair_name" {
  description = "Optional EC2 key pair name. Leave null — access is via SSM Session Manager."
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
