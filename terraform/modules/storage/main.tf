# SummitEthic Infrastructure - Storage Module
# This module provisions S3 buckets and EFS file systems

terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# S3 Bucket
resource "aws_s3_bucket" "main" {
  bucket = "${var.environment}-${var.name}-${var.bucket_suffix}"
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-${var.name}"
      Environment = var.environment
      "org.summitethic.component" = "storage-bucket"
      "org.summitethic.purpose" = var.purpose
      "org.summitethic.managed-by" = "terraform"
      "org.summitethic.data-classification" = var.data_classification
    }
  )
}

# S3 Bucket Ownership Controls
resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id
  
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# S3 Bucket ACL (Private by default)
resource "aws_s3_bucket_acl" "main" {
  depends_on = [aws_s3_bucket_ownership_controls.main]
  
  bucket = aws_s3_bucket.main.id
  acl    = "private"
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  
  versioning_configuration {
    status = var.versioning ? "Enabled" : "Suspended"
  }
}

# S3 Bucket Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count = length(var.lifecycle_rules) > 0 ? 1 : 0
  
  bucket = aws_s3_bucket.main.id
  
  dynamic "rule" {
    for_each = var.lifecycle_rules
    
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"
      
      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [1] : []
        
        content {
          days = rule.value.expiration_days
        }
      }
      
      dynamic "transition" {
        for_each = rule.value.transitions != null ? rule.value.transitions : []
        
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }
      
      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration_days != null ? [1] : []
        
        content {
          noncurrent_days = rule.value.noncurrent_version_expiration_days
        }
      }
    }
  }
}

# S3 Bucket Logging
resource "aws_s3_bucket_logging" "main" {
  count = var.logging_enabled ? 1 : 0
  
  bucket = aws_s3_bucket.main.id
  
  target_bucket = var.logging_bucket
  target_prefix = "${var.environment}/${var.name}/"
}

# EFS File System
resource "aws_efs_file_system" "main" {
  count = var.create_efs ? 1 : 0
  
  encrypted = true
  kms_key_id = var.efs_kms_key_id
  
  performance_mode = var.efs_performance_mode
  throughput_mode  = var.efs_throughput_mode
  
  dynamic "lifecycle_policy" {
    for_each = var.efs_transition_to_ia != null ? [1] : []
    
    content {
      transition_to_ia = var.efs_transition_to_ia
    }
  }
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-${var.name}-efs"
      Environment = var.environment
      "org.summitethic.component" = "efs-filesystem"
      "org.summitethic.purpose" = var.purpose
      "org.summitethic.managed-by" = "terraform"
      "org.summitethic.data-classification" = var.data_classification
    }
  )
}

# EFS Mount Targets
resource "aws_efs_mount_target" "main" {
  count = var.create_efs ? length(var.efs_subnet_ids) : 0
  
  file_system_id  = aws_efs_file_system.main[0].id
  subnet_id       = var.efs_subnet_ids[count.index]
  security_groups = var.efs_security_group_ids
}

# EFS Backup Policy
resource "aws_efs_backup_policy" "main" {
  count = var.create_efs && var.efs_enable_backup ? 1 : 0
  
  file_system_id = aws_efs_file_system.main[0].id
  
  backup_policy {
    status = "ENABLED"
  }
}

# EFS Access Point
resource "aws_efs_access_point" "main" {
  count = var.create_efs && var.create_efs_access_point ? 1 : 0
  
  file_system_id = aws_efs_file_system.main[0].id
  
  posix_user {
    gid = var.efs_access_point_gid
    uid = var.efs_access_point_uid
  }
  
  root_directory {
    path = var.efs_access_point_path
    
    creation_info {
      owner_gid   = var.efs_access_point_gid
      owner_uid   = var.efs_access_point_uid
      permissions = var.efs_access_point_permissions
    }
  }
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-${var.name}-access-point"
      Environment = var.environment
      "org.summitethic.component" = "efs-access-point"
      "org.summitethic.purpose" = var.purpose
      "org.summitethic.managed-by" = "terraform"
    }
  )
}

# CloudWatch Alarm for S3 Bucket Size
resource "aws_cloudwatch_metric_alarm" "bucket_size" {
  count = var.create_bucket_size_alarm ? 1 : 0
  
  alarm_name          = "${var.environment}-${var.name}-bucket-size-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BucketSizeBytes"
  namespace           = "AWS/S3"
  period              = 86400  # 1 day
  statistic           = "Maximum"
  threshold           = var.bucket_size_alarm_threshold
  alarm_description   = "This alarm monitors the size of the ${aws_s3_bucket.main.bucket} bucket"
  
  dimensions = {
    BucketName  = aws_s3_bucket.main.bucket
    StorageType = "StandardStorage"
  }
  
  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  
  tags = merge(
    var.common_tags,
    {
      "org.summitethic.component" = "monitoring"
      "org.summitethic.purpose" = "resource-optimization"
    }
  )
}

# CloudWatch Alarm for S3 Number of Objects
resource "aws_cloudwatch_metric_alarm" "number_of_objects" {
  count = var.create_objects_count_alarm ? 1 : 0
  
  alarm_name          = "${var.environment}-${var.name}-objects-count-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfObjects"
  namespace           = "AWS/S3"
  period              = 86400  # 1 day
  statistic           = "Maximum"
  threshold           = var.objects_count_alarm_threshold
  alarm_description   = "This alarm monitors the number of objects in the ${aws_s3_bucket.main.bucket} bucket"
  
  dimensions = {
    BucketName  = aws_s3_bucket.main.bucket
    StorageType = "AllStorageTypes"
  }
  
  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  
  tags = merge(
    var.common_tags,
    {
      "org.summitethic.component" = "monitoring"
      "org.summitethic.purpose" = "resource-optimization"
    }
  )
}