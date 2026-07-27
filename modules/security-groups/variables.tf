variable "name_prefix" {
  description = "Prefix applied to all resource names in this module."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID the security groups belong to."
  type        = string
}

variable "alb_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the ALB."
  type        = list(string)
}

variable "app_port" {
  description = "Port the application listens on."
  type        = number
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
