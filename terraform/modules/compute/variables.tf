# SummitEthic Infrastructure - Compute Module Variables

variable "environment" {
  description = "Environment name (e.g., development, staging, production)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where instances will be launched"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "Number of instances to launch"
  type        = number
  default     = 2
}

variable "ami_id" {
  description = "AMI ID to use for the instances. If not provided, latest Amazon Linux 2 will be used."
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Key pair name for SSH access"
  type        = string
}

variable "security_groups" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "instance_profile" {
  description = "IAM instance profile name"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 20
}

variable "data_volume_size" {
  description = "Size of the data volume in GB"
  type        = number
  default     = 50
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring for the instances"
  type        = bool
  default     = false
}

variable "user_data_template" {
  description = "Path to the user data template file"
  type        = string
  default     = "templates/user_data.sh.tpl"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "create_lb" {
  description = "Whether to create a load balancer"
  type        = bool
  default     = true
}

variable "lb_internal" {
  description = "Whether the load balancer is internal"
  type        = bool
  default     = false
}

variable "lb_security_groups" {
  description = "List of security group IDs for the load balancer"
  type        = list(string)
  default     = []
}

variable "lb_subnet_ids" {
  description = "List of subnet IDs for the load balancer. If not provided, instance subnet IDs will be used."
  type        = list(string)
  default     = null
}

variable "lb_logs_bucket" {
  description = "S3 bucket for load balancer access logs"
  type        = string
  default     = ""
}

variable "lb_logging_enabled" {
  description = "Whether to enable load balancer access logs"
  type        = bool
  default     = true
}

variable "app_port" {
  description = "Port on which the application is running"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Path for the health check"
  type        = string
  default     = "/"
}

variable "ssl_certificate_arn" {
  description = "ARN of the SSL certificate to use for the HTTPS listener"
  type        = string
  default     = ""
}

variable "alarm_actions" {
  description = "List of ARNs to execute when the alarm transitions to ALARM state"
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "List of ARNs to execute when the alarm transitions to OK state"
  type        = list(string)
  default     = []
}