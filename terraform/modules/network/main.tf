# SummitEthic Infrastructure - Network Module
# This module provisions the VPC and network components

terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# VPC resource
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-vpc"
      Environment = var.environment
      "org.summitethic.component" = "core-network"
      "org.summitethic.purpose" = "service-isolation"
    }
  )
}

# Public subnets
resource "aws_subnet" "public" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = true
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-public-subnet-${count.index + 1}"
      Environment = var.environment
      "org.summitethic.component" = "public-subnet"
      "org.summitethic.purpose" = "public-services"
    }
  )
}

# Private subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-private-subnet-${count.index + 1}"
      Environment = var.environment
      "org.summitethic.component" = "private-subnet"
      "org.summitethic.purpose" = "internal-services"
    }
  )
}

# Database subnets
resource "aws_subnet" "database" {
  count             = length(var.database_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.database_subnets[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-database-subnet-${count.index + 1}"
      Environment = var.environment
      "org.summitethic.component" = "database-subnet"
      "org.summitethic.purpose" = "data-services"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-igw"
      Environment = var.environment
      "org.summitethic.component" = "internet-gateway"
      "org.summitethic.purpose" = "external-connectivity"
    }
  )
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count = var.create_nat_gateway ? 1 : 0
  vpc   = true
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-nat-eip"
      Environment = var.environment
      "org.summitethic.component" = "nat-eip"
      "org.summitethic.purpose" = "nat-connectivity"
    }
  )
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  count         = var.create_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-nat-gateway"
      Environment = var.environment
      "org.summitethic.component" = "nat-gateway"
      "org.summitethic.purpose" = "private-subnet-egress"
    }
  )
  
  depends_on = [aws_internet_gateway.main]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-public-route-table"
      Environment = var.environment
      "org.summitethic.component" = "route-table"
      "org.summitethic.purpose" = "public-routing"
    }
  )
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-private-route-table"
      Environment = var.environment
      "org.summitethic.component" = "route-table"
      "org.summitethic.purpose" = "private-routing"
    }
  )
}

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-database-route-table"
      Environment = var.environment
      "org.summitethic.component" = "route-table"
      "org.summitethic.purpose" = "database-routing"
    }
  )
}

# Routes
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route" "private_nat_gateway" {
  count                  = var.create_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "database" {
  count          = length(aws_subnet.database)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# Security Group for general public access (HTTP/HTTPS)
resource "aws_security_group" "public_web" {
  name        = "${var.environment}-public-web"
  description = "Allow HTTP/HTTPS traffic"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }
  
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
      Name = "${var.environment}-public-web-sg"
      Environment = var.environment
      "org.summitethic.component" = "security-group"
      "org.summitethic.purpose" = "web-traffic"
    }
  )
}

# Security Group for SSH access
resource "aws_security_group" "ssh" {
  name        = "${var.environment}-ssh"
  description = "Allow SSH access from approved IPs"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_ips
    description = "SSH access from approved IPs"
  }
  
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
      Name = "${var.environment}-ssh-sg"
      Environment = var.environment
      "org.summitethic.component" = "security-group"
      "org.summitethic.purpose" = "ssh-access"
      "org.summitethic.security-critical" = "true"
    }
  )
}

# VPC Flow Logs for ethical auditing and security monitoring
resource "aws_flow_log" "main" {
  count = var.enable_flow_logs ? 1 : 0
  
  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-vpc-flow-logs"
      Environment = var.environment
      "org.summitethic.component" = "flow-logs"
      "org.summitethic.purpose" = "security-monitoring"
      "org.summitethic.data-category" = "network-metadata"
    }
  )
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  
  name              = "/vpc/flow-logs/${var.environment}"
  retention_in_days = var.flow_logs_retention_days
  
  tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      "org.summitethic.component" = "log-group"
      "org.summitethic.purpose" = "flow-logs-storage"
    }
  )
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  
  name = "${var.environment}-flow-logs-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      "org.summitethic.component" = "iam-role"
      "org.summitethic.purpose" = "flow-logs-permissions"
    }
  )
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  
  name = "${var.environment}-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}