# environments/prod.tfvars
# Usage: terraform plan -var-file=environments/prod.tfvars
# Differs from dev primarily in NAT Gateway topology (AZ-isolated egress)
# and instance sizing — everything else reuses the same modules.

environment        = "prod"
aws_region         = "us-east-1"
project_name       = "aws-landing-zone"
owner              = "aniket-kumar"

vpc_cidr              = "10.0.0.0/16"
availability_zones    = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs   = ["10.0.0.0/24", "10.0.1.0/24"]
private_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
single_nat_gateway    = false  # one NAT Gateway per AZ — no single point of failure

instance_type       = "t3.small"
ec2_instance_count  = 2
app_port            = 80

alb_ingress_cidrs  = ["0.0.0.0/0"]
health_check_path  = "/"
