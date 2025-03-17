# SummitEthic Infrastructure - Compute Module
# This module provisions EC2 instances and load balancers

terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Data source to get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# EC2 Instances
resource "aws_instance" "app_servers" {
  count         = var.instance_count
  ami           = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = element(var.subnet_ids, count.index % length(var.subnet_ids))
  
  vpc_security_group_ids = var.security_groups
  key_name               = var.key_name
  iam_instance_profile   = var.instance_profile

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = var.data_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  monitoring = var.enable_monitoring

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = templatefile(var.user_data_template, {
    environment = var.environment
    region      = data.aws_region.current.name
    hostname    = "app-${var.environment}-${count.index + 1}"
  })
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-app-server-${count.index + 1}"
      Environment = var.environment
      "org.summitethic.component" = "application-server"
      "org.summitethic.purpose" = "hosting-services"
      "org.summitethic.managed-by" = "terraform"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer
resource "aws_lb" "app_lb" {
  count              = var.create_lb ? 1 : 0
  name               = "${var.environment}-app-lb"
  internal           = var.lb_internal
  load_balancer_type = "application"
  security_groups    = var.lb_security_groups
  subnets            = var.lb_subnet_ids != null ? var.lb_subnet_ids : var.subnet_ids

  enable_deletion_protection = var.environment == "production"
  
  access_logs {
    bucket  = var.lb_logs_bucket
    prefix  = "${var.environment}-lb-logs"
    enabled = var.lb_logging_enabled
  }
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-app-lb"
      Environment = var.environment
      "org.summitethic.component" = "load-balancer"
      "org.summitethic.purpose" = "traffic-distribution"
      "org.summitethic.managed-by" = "terraform"
    }
  )
}

# Target Group
resource "aws_lb_target_group" "app_tg" {
  count                = var.create_lb ? 1 : 0
  name                 = "${var.environment}-app-tg"
  port                 = var.app_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 60

  health_check {
    enabled             = true
    interval            = 30
    path                = var.health_check_path
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200-299"
  }
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-app-tg"
      Environment = var.environment
      "org.summitethic.component" = "target-group"
      "org.summitethic.purpose" = "health-checks"
      "org.summitethic.managed-by" = "terraform"
    }
  )
}

# Target Group Attachment
resource "aws_lb_target_group_attachment" "app_tg_attachment" {
  count            = var.create_lb ? var.instance_count : 0
  target_group_arn = aws_lb_target_group.app_tg[0].arn
  target_id        = aws_instance.app_servers[count.index].id
  port             = var.app_port
}

# HTTP Listener redirecting to HTTPS
resource "aws_lb_listener" "http" {
  count             = var.create_lb ? 1 : 0
  load_balancer_arn = aws_lb.app_lb[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  count             = var.create_lb && var.ssl_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.app_lb[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg[0].arn
  }
}

# CloudWatch Alarms for instance monitoring
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count               = var.enable_monitoring ? var.instance_count : 0
  alarm_name          = "${var.environment}-app-server-${count.index + 1}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  
  dimensions = {
    InstanceId = aws_instance.app_servers[count.index].id
  }
  
  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-cpu-alarm-${count.index + 1}"
      "org.summitethic.component" = "monitoring"
      "org.summitethic.purpose" = "resource-optimization"
    }
  )
}

data "aws_region" "current" {}