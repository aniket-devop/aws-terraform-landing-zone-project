# variables.tf (root)
# Root-level inputs. In this project the root module composes the child
# modules directly (see main.tf) — the environments/ folder holds per-env
# .tfvars files so the same root config can be planned/applied against
# dev, staging, or prod without duplicating code.

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project identifier used in resource names and tags."
  type        = string
  default     = "aws-landing-zone"
}

variable "environment" {
  description = "Deployment environment name (dev, staging, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Owner tag — team or individual responsible for these resources."
  type        = string
  default     = "aniket-kumar"
}

# ---------- Networking ----------

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to spread subnets and NAT gateways across (2 required)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private (app) subnets, one per AZ."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "single_nat_gateway" {
  description = "If true, deploy one NAT Gateway shared across AZs instead of one per AZ. Set true to cut cost in dev; keep false for prod (AZ-isolated egress)."
  type        = bool
  default     = false
}

# ---------- Compute ----------

variable "instance_type" {
  description = "EC2 instance type for the application tier."
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Port the application listens on (ALB target group + EC2 SG)."
  type        = number
  default     = 80
}

variable "ec2_instance_count" {
  description = "Number of EC2 instances to launch in private subnets."
  type        = number
  default     = 2
}

variable "key_pair_name" {
  description = "Optional existing EC2 key pair name for emergency SSH via bastion. Leave null to rely solely on SSM Session Manager (recommended)."
  type        = string
  default     = null
}

# ---------- Load Balancer ----------

variable "alb_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the ALB (public internet by default)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "health_check_path" {
  description = "HTTP path the target group uses for health checks."
  type        = string
  default     = "/"
}
