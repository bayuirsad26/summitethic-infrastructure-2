# SummitEthic Production Infrastructure

terraform {
  required_version = ">= 1.0.0"
  
  backend "s3" {
    bucket         = "summitethic-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "summitethic-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "SummitEthic"
      Environment = "production"
      ManagedBy   = "Terraform"
      Owner       = "DevOps"
    }
  }
}

# Base tags used across all resources
locals {
  common_tags = {
    Environment           = "production"
    Project               = "SummitEthic"
    "org.summitethic.env" = "production"
  }
}

# Network Infrastructure
module "network" {
  source = "../../modules/network"
  
  environment        = "production"
  vpc_cidr           = var.vpc_cidr
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  database_subnets   = var.database_subnets
  availability_zones = var.availability_zones
  create_nat_gateway = true
  common_tags        = local.common_tags
  ssh_allowed_ips    = var.ssh_allowed_ips
  enable_flow_logs   = true
  flow_logs_retention_days = 30
}

# Compute Infrastructure
module "compute" {
  source = "../../modules/compute"
  
  environment        = "production"
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnet_ids
  instance_type      = var.instance_type
  instance_count     = var.instance_count
  key_name           = var.key_name
  security_groups    = [module.security.app_security_group_id]
  common_tags        = local.common_tags
  root_volume_size   = 50
  enable_monitoring  = true
  instance_profile   = module.security.instance_profile_name
  user_data_template = "templates/user_data.sh.tpl"
}

# Security Infrastructure
module "security" {
  source = "../../modules/security"
  
  environment     = "production"
  vpc_id          = module.network.vpc_id
  admin_cidrs     = var.admin_cidrs
  common_tags     = local.common_tags
  enable_ssm      = true
  enable_guardduty = true
}

# Database Infrastructure
module "database" {
  source = "../../modules/database"
  
  environment           = "production"
  vpc_id                = module.network.vpc_id
  subnet_ids            = module.network.database_subnet_ids
  db_engine             = "postgres"
  db_version            = "14"
  instance_class        = var.db_instance_class
  multi_az              = true
  allocated_storage     = 100
  storage_encrypted     = true
  backup_retention_period = 7
  maintenance_window    = "Sun:03:00-Sun:06:00"
  backup_window         = "01:00-03:00"
  deletion_protection   = true
  common_tags           = local.common_tags
  security_group_ids    = [module.security.db_security_group_id]
  subnet_group_name     = module.network.database_subnet_group_name
  parameter_group_name  = module.database.parameter_group_name
}

# Storage Infrastructure
module "storage" {
  source = "../../modules/storage"
  
  environment     = "production"
  bucket_suffix   = var.bucket_suffix
  common_tags     = local.common_tags
  versioning      = true
  logging_enabled = true
  lifecycle_rules = var.s3_lifecycle_rules
}

# Ethical Infrastructure Monitoring
module "monitoring" {
  source = "../../modules/monitoring"
  
  environment     = "production"
  vpc_id          = module.network.vpc_id
  subnet_ids      = module.network.private_subnet_ids
  security_groups = [module.security.monitoring_security_group_id]
  instance_type   = var.monitoring_instance_type
  key_name        = var.key_name
  common_tags     = local.common_tags
  
  # Ethical monitoring configuration
  enable_ethical_alerts = true
  resource_fairness_monitoring = true
  data_access_monitoring = true
  resource_usage_threshold = 85
  notification_emails = var.notification_emails
}