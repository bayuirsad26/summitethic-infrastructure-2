# SummitEthic Development Infrastructure

terraform {
  required_version = ">= 1.0.0"
  
  backend "s3" {
    bucket         = "summitethic-terraform-state-dev"
    key            = "development/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "summitethic-terraform-locks-dev"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "SummitEthic"
      Environment = "development"
      ManagedBy   = "Terraform"
      Owner       = "DevOps"
    }
  }
}

# Base tags used across all resources
locals {
  common_tags = {
    Environment           = "development"
    Project               = "SummitEthic"
    "org.summitethic.env" = "development"
  }
}

# Network Infrastructure
module "network" {
  source = "../../modules/network"
  
  environment        = "development"
  vpc_cidr           = var.vpc_cidr
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  database_subnets   = var.database_subnets
  availability_zones = var.availability_zones
  create_nat_gateway = false  # Cost saving for development
  common_tags        = local.common_tags
  ssh_allowed_ips    = var.ssh_allowed_ips
  enable_flow_logs   = false  # Simplify for development
}

# Security Infrastructure
module "security" {
  source = "../../modules/security"
  
  environment     = "development"
  vpc_id          = module.network.vpc_id
  admin_cidrs     = var.admin_cidrs
  common_tags     = local.common_tags
  enable_ssm      = true
  enable_guardduty = false  # Cost saving for development
}

# Compute Infrastructure (smaller instance types for development)
module "compute" {
  source = "../../modules/compute"
  
  environment        = "development"
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnet_ids
  instance_type      = "t3.small"
  instance_count     = 1
  key_name           = var.key_name
  security_groups    = [module.security.app_security_group_id]
  common_tags        = local.common_tags
  root_volume_size   = 20
  enable_monitoring  = false  # Cost saving for development
  instance_profile   = module.security.instance_profile_name
  user_data_template = "templates/user_data.sh.tpl"
}

# Database Infrastructure (smaller instance for development)
module "database" {
  source = "../../modules/database"
  
  environment           = "development"
  vpc_id                = module.network.vpc_id
  subnet_ids            = module.network.database_subnet_ids
  db_engine             = "postgres"
  db_version            = "14"
  instance_class        = "db.t3.small"
  multi_az              = false  # Cost saving for development
  allocated_storage     = 20
  storage_encrypted     = true
  backup_retention_period = 3
  maintenance_window    = "Sun:03:00-Sun:06:00"
  backup_window         = "01:00-03:00"
  deletion_protection   = false  # Allow easy cleanup in development
  common_tags           = local.common_tags
  security_group_ids    = [module.security.db_security_group_id]
  subnet_group_name     = module.network.database_subnet_group_name
  parameter_group_name  = module.database.parameter_group_name
  apply_immediately     = true  # For ease of development iteration
}

# Storage Infrastructure
module "storage" {
  source = "../../modules/storage"
  
  environment     = "development"
  name            = "dev-storage"
  bucket_suffix   = var.bucket_suffix
  common_tags     = local.common_tags
  versioning      = false  # Cost saving for development
  logging_enabled = false  # Simplify for development
  
  lifecycle_rules = [
    {
      id                                = "dev-cleanup"
      enabled                           = true
      expiration_days                   = 30
      noncurrent_version_expiration_days = 7
    }
  ]
}