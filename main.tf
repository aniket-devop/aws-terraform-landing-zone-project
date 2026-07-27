# main.tf (root)
# Composes the reusable child modules into the AWS Landing Zone.
# Naming convention: ${var.project_name}-${var.environment}-<resource>

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

module "vpc" {
  source = "./modules/vpc"

  name_prefix           = local.name_prefix
  vpc_cidr               = var.vpc_cidr
  availability_zones     = var.availability_zones
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_cidrs   = var.private_subnet_cidrs
  single_nat_gateway     = var.single_nat_gateway
  tags                   = local.common_tags
}

module "security_groups" {
  source = "./modules/security-groups"

  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  alb_ingress_cidrs = var.alb_ingress_cidrs
  app_port          = var.app_port
  tags              = local.common_tags
}

module "iam" {
  source = "./modules/iam"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

module "alb" {
  source = "./modules/alb"

  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
  app_port           = var.app_port
  health_check_path  = var.health_check_path
  tags               = local.common_tags
}

module "ec2" {
  source = "./modules/ec2"

  name_prefix           = local.name_prefix
  instance_count         = var.ec2_instance_count
  instance_type          = var.instance_type
  private_subnet_ids     = module.vpc.private_subnet_ids
  ec2_security_group_id  = module.security_groups.ec2_security_group_id
  instance_profile_name  = module.iam.instance_profile_name
  target_group_arn       = module.alb.target_group_arn
  app_port               = var.app_port
  key_pair_name          = var.key_pair_name
  tags                   = local.common_tags
}
