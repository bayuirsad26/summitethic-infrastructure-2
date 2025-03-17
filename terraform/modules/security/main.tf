# SummitEthic Infrastructure - Security Module
# This module provisions security groups, IAM roles, and security services

terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Security Group for Application Servers
resource "aws_security_group" "app" {
  name        = "${var.environment}-app-sg"
  description = "Security group for application servers"
  vpc_id      = var.vpc_id
  
  # SSH access from admin CIDRs only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidrs
    description = "SSH access from admin networks only"
  }
  
  # HTTP access from load balancer security group
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = var.lb_security_group_ids
    description     = "HTTP access from load balancers"
  }
  
  # HTTPS access from load balancer security group
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = var.lb_security_group_ids
    description     = "HTTPS access from load balancers"
  }
  
  # Application port access from load balancer security group
  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = var.lb_security_group_ids
    description     = "Application port access from load balancers"
  }
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-app-sg"
      Environment = var.environment
      "org.summitethic.component" = "security-group"
      "org.summitethic.purpose" = "application-security"
      "org.summitethic.managed-by" = "terraform"
    }
  )
}

# Security Group for Database Servers
resource "aws_security_group" "db" {
  name        = "${var.environment}-db-sg"
  description = "Security group for database servers"
  vpc_id      = var.vpc_id
  
  # Database port access from application security group
  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
    description     = "Database access from application servers"
  }
  
  # SSH access from admin CIDRs only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidrs
    description = "SSH access from admin networks only"
  }
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-db-sg"
      Environment = var.environment
      "org.summitethic.component" = "security-group"
      "org.summitethic.purpose" = "database-security"
      "org.summitethic.managed-by" = "terraform"
    }
  )
}

# Security Group for Monitoring
resource "aws_security_group" "monitoring" {
  name        = "${var.environment}-monitoring-sg"
  description = "Security group for monitoring servers"
  vpc_id      = var.vpc_id
  
  # SSH access from admin CIDRs only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidrs
    description = "SSH access from admin networks only"
  }
  
  # Prometheus access from within VPC only
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
    description = "Prometheus access from within VPC"
  }
  
  # Grafana web access from specified CIDR blocks
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = concat(var.admin_cidrs, var.monitoring_access_cidrs)
    description = "Grafana web access"
  }
  
  # Allow all monitoring targets to be scraped
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
    description = "Node exporter metrics"
  }
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-monitoring-sg"
      Environment = var.environment
      "org.summitethic.component" = "security-group"
      "org.summitethic.purpose" = "monitoring-security"
      "org.summitethic.managed-by" = "terraform"
    }
  )
}

# IAM Role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "${var.environment}-ec2-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      "org.summitethic.component" = "iam-role"
      "org.summitethic.purpose" = "ec2-permissions"
      "org.summitethic.managed-by" = "terraform"
    }
  )
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name
  
  tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      "org.summitethic.component" = "iam-profile"
      "org.summitethic.managed-by" = "terraform"
    }
  )
}

# Attach SSM policy for Session Manager access (if enabled)
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  count      = var.enable_ssm ? 1 : 0
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# AWS GuardDuty (if enabled)
resource "aws_guardduty_detector" "main" {
  count                = var.enable_guardduty ? 1 : 0
  enable               = true
  finding_publishing_frequency = "SIX_HOURS"
  
  tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      "org.summitethic.component" = "security-service"
      "org.summitethic.purpose" = "threat-detection"
      "org.summitethic.managed-by" = "terraform"
    }
  )
}

# AWS Security Hub (if enabled)
resource "aws_securityhub_account" "main" {
  count = var.enable_securityhub ? 1 : 0
  
  tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      "org.summitethic.component" = "security-service"
      "org.summitethic.purpose" = "compliance-monitoring"
      "org.summitethic.managed-by" = "terraform"
    }
  )
}

# Custom S3 bucket policy for secure logging
resource "aws_s3_bucket_policy" "logging_bucket_policy" {
  count  = var.logging_bucket != "" ? 1 : 0
  bucket = var.logging_bucket
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSLogDeliveryWrite"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "arn:aws:s3:::${var.logging_bucket}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid       = "AWSLogDeliveryAclCheck"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = "arn:aws:s3:::${var.logging_bucket}"
      }
    ]
  })
}

# Get current VPC
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# KMS key for encryption
resource "aws_kms_key" "main" {
  description             = "${var.environment} encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-kms-key"
      Environment = var.environment
      "org.summitethic.component" = "encryption"
      "org.summitethic.purpose" = "data-protection"
      "org.summitethic.managed-by" = "terraform"
    }
  )
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

# KMS alias
resource "aws_kms_alias" "main" {
  name          = "alias/${var.environment}-key"
  target_key_id = aws_kms_key.main.key_id
}

# Current AWS account ID
data "aws_caller_identity" "current" {}