# environments/dev.tfvars
# Usage: terraform plan -var-file=environments/dev.tfvars

environment        = "dev"
aws_region         = "us-east-1"
project_name       = "aws-landing-zone"
owner              = "aniket-kumar"

vpc_cidr              = "10.0.0.0/16"
availability_zones    = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs   = ["10.0.0.0/24", "10.0.1.0/24"]
private_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
single_nat_gateway    = true   # cost-saver for a non-prod sandbox

instance_type       = "t2.micro"
ec2_instance_count  = 1
app_port            = 80

alb_ingress_cidrs  = ["0.0.0.0/0"]
health_check_path  = "/"
