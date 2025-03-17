# SummitEthic Infrastructure - Security Module Variables

variable "environment" {
  description = "Environment name (e.g., development, staging, production)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "admin_cidrs" {
  description = "CIDR blocks for admin access"
  type        = list(string)
  default     = []
}

variable "monitoring_access_cidrs" {
  description = "CIDR blocks for monitoring access"
  type        = list(string)
  default     = []
}

variable "app_port" {
  description = "Port for the application"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Port for the database"
  type        = number
  default     = 5432
}

variable "lb_security_group_ids" {
  description = "Security group IDs for load balancers"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_ssm" {
  description = "Enable AWS Systems Manager Session Manager"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable AWS GuardDuty"
  type        = bool
  default     = true
}

variable "enable_securityhub" {
  description = "Enable AWS Security Hub"
  type        = bool
  default     = false
}

variable "logging_bucket" {
  description = "S3 bucket for AWS service logs"
  type        = string
  default     = ""
}