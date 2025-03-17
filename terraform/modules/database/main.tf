# SummitEthic Infrastructure - Database Module
# This module provisions RDS instances and related resources

terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Random password generation for database
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# SSM parameter to store database password
resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.environment}/database/${var.db_identifier}/password"
  description = "Database password for ${var.db_identifier} in ${var.environment}"
  type        = "SecureString"
  value       = random_password.db_password.result
  
  tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      "org.summitethic.component" = "database-credential"
      "org.summitethic.managed-by" = "terraform"
    }
  )
}

# DB Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "${var.environment}-${var.db_identifier}-subnet-group"
  description = "Subnet group for ${var.db_identifier} database in ${var.environment}"
  subnet_ids  = var.subnet_ids
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-${var.db_identifier}-subnet-group"
      Environment = var.environment
      "org.summitethic.component" = "database-subnet-group"
      "org.summitethic.managed-by" = "terraform"
    }
  )
}

# DB Parameter Group
resource "aws_db_parameter_group" "db_parameter_group" {
  name        = "${var.environment}-${var.db_identifier}-params"
  family      = var.parameter_group_family
  description = "Parameter group for ${var.db_identifier} database in ${var.environment}"
  
  dynamic "parameter" {
    for_each = var.db_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", "immediate")
    }
  }
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-${var.db_identifier}-params"
      Environment = var.environment
      "org.summitethic.component" = "database-parameters"
      "org.summitethic.managed-by" = "terraform"
    }
  )
}

# RDS Instance
resource "aws_db_instance" "db_instance" {
  identifier           = "${var.environment}-${var.db_identifier}"
  engine               = var.db_engine
  engine_version       = var.db_version
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type         = "gp3"
  storage_encrypted    = true
  
  username             = var.db_username
  password             = random_password.db_password.result
  port                 = var.db_port
  
  vpc_security_group_ids = var.security_group_ids
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  parameter_group_name   = aws_db_parameter_group.db_parameter_group.name
  option_group_name      = var.option_group_name
  
  multi_az               = var.multi_az
  publicly_accessible    = false
  
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  apply_immediately           = var.apply_immediately
  
  copy_tags_to_snapshot       = true
  skip_final_snapshot         = var.skip_final_snapshot
  final_snapshot_identifier   = var.skip_final_snapshot ? null : "${var.environment}-${var.db_identifier}-final-snapshot"
  deletion_protection         = var.deletion_protection
  
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-${var.db_identifier}"
      Environment = var.environment
      "org.summitethic.component" = "database"
      "org.summitethic.purpose" = "data-storage"
      "org.summitethic.managed-by" = "terraform"
      "org.summitethic.backup-enabled" = "true"
      "org.summitethic.encryption-enabled" = "true"
    }
  )
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  name  = "${var.environment}-rds-monitoring-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-rds-monitoring-role"
      Environment = var.environment
      "org.summitethic.component" = "iam-role"
      "org.summitethic.purpose" = "database-monitoring"
      "org.summitethic.managed-by" = "terraform"
    }
  )
}

# Attach the RDS Enhanced Monitoring policy to the role
resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Alarms for database monitoring
resource "aws_cloudwatch_metric_alarm" "db_cpu_utilization_high" {
  alarm_name          = "${var.environment}-${var.db_identifier}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors database CPU utilization"
  
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db_instance.id
  }
  
  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-${var.db_identifier}-cpu-alarm"
      "org.summitethic.component" = "monitoring"
      "org.summitethic.purpose" = "database-performance"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "db_free_storage_space_low" {
  alarm_name          = "${var.environment}-${var.db_identifier}-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.allocated_storage * 1024 * 1024 * 1024 * 0.2  # 20% of allocated storage in bytes
  alarm_description   = "This metric monitors database free storage space"
  
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db_instance.id
  }
  
  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-${var.db_identifier}-storage-alarm"
      "org.summitethic.component" = "monitoring"
      "org.summitethic.purpose" = "database-storage"
    }
  )
}