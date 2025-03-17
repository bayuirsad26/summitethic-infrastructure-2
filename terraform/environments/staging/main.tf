# SummitEthic Staging Infrastructure

terraform {
  required_version = ">= 1.0.0"
  
  backend "s3" {
    bucket         = "summitethic-terraform-state"
    key            = "staging/terraform.tfstate"
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
      Environment = "staging"
      ManagedBy   = "Terraform"
      Owner       = "DevOps"
    }
  }
}

# Base tags used across all resources
locals {
  common_tags = {
    Environment           = "staging"
    Project               = "SummitEthic"
    "org.summitethic.env" = "staging"
  }
}

# Network Infrastructure
module "network" {
  source = "../../modules/network"
  
  environment        = "staging"
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

# Security Infrastructure
module "security" {
  source = "../../modules/security"
  
  environment     = "staging"
  vpc_id          = module.network.vpc_id
  admin_cidrs     = var.admin_cidrs
  common_tags     = local.common_tags
  enable_ssm      = true
  enable_guardduty = true
  logging_bucket  = module.storage.bucket_name
}

# Compute Infrastructure
module "compute" {
  source = "../../modules/compute"
  
  environment        = "staging"
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnet_ids
  instance_type      = var.instance_type
  instance_count     = 2
  key_name           = var.key_name
  security_groups    = [module.security.app_security_group_id]
  common_tags        = local.common_tags
  root_volume_size   = 30
  enable_monitoring  = true
  instance_profile   = module.security.instance_profile_name
  user_data_template = "templates/user_data.sh.tpl"
  create_lb          = true
  lb_internal        = false
  lb_security_groups = [module.security.lb_security_group_id]
  lb_subnet_ids      = module.network.public_subnet_ids
  lb_logs_bucket     = module.storage.bucket_name
}

# Database Infrastructure
module "database" {
  source = "../../modules/database"
  
  environment           = "staging"
  vpc_id                = module.network.vpc_id
  subnet_ids            = module.network.database_subnet_ids
  db_engine             = "postgres"
  db_version            = "14"
  instance_class        = "db.t3.medium"
  multi_az              = true
  allocated_storage     = 50
  storage_encrypted     = true
  backup_retention_period = 7
  maintenance_window    = "Sun:03:00-Sun:06:00"
  backup_window         = "01:00-03:00"
  deletion_protection   = true
  common_tags           = local.common_tags
  security_group_ids    = [module.security.db_security_group_id]
  subnet_group_name     = module.network.database_subnet_group_name
  parameter_group_name  = module.database.parameter_group_name
  monitoring_interval   = 60
  
  db_parameters = [
    {
      name  = "log_min_duration_statement"
      value = "1000"
    },
    {
      name  = "shared_preload_libraries"
      value = "pg_stat_statements"
    }
  ]
}

# Storage Infrastructure
module "storage" {
  source = "../../modules/storage"
  
  environment       = "staging"
  name              = "staging-storage"
  bucket_suffix     = var.bucket_suffix
  common_tags       = local.common_tags
  versioning        = true
  logging_enabled   = true
  logging_bucket    = "summitethic-logs-${var.bucket_suffix}"
  data_classification = "confidential"
  purpose           = "application-storage"
  
  lifecycle_rules = [
    {
      id                                = "staging-lifecycle"
      enabled                           = true
      expiration_days                   = 90
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        }
      ]
      noncurrent_version_expiration_days = 30
    }
  ]
  
  create_bucket_size_alarm     = true
  bucket_size_alarm_threshold  = 5368709120  # 5 GB
  create_objects_count_alarm   = true
  objects_count_alarm_threshold = 10000
  alarm_actions                = [var.sns_alarm_topic_arn]
}

# Monitoring Infrastructure
module "monitoring" {
  source = "../../modules/monitoring"
  
  environment     = "staging"
  vpc_id          = module.network.vpc_id
  subnet_ids      = module.network.private_subnet_ids
  security_groups = [module.security.monitoring_security_group_id]
  instance_type   = "t3.small"
  key_name        = var.key_name
  common_tags     = local.common_tags
  
  # Ethical monitoring configuration
  enable_ethical_alerts           = true
  resource_fairness_monitoring    = true
  data_access_monitoring          = true
  resource_usage_threshold        = 80
  notification_emails             = var.notification_emails
  data_privacy_monitoring_enabled = true
}