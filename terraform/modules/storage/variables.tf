# SummitEthic Infrastructure - Storage Module Variables

variable "environment" {
  description = "Environment name (e.g., development, staging, production)"
  type        = string
}

variable "name" {
  description = "Name for the storage resources"
  type        = string
}

variable "purpose" {
  description = "Purpose of the storage resources (for ethical tagging)"
  type        = string
  default     = "data-storage"
}

variable "data_classification" {
  description = "Classification of the data stored (e.g., public, internal, confidential, sensitive)"
  type        = string
  default     = "internal"
}

variable "bucket_suffix" {
  description = "Suffix to add to the S3 bucket name (required for global uniqueness)"
  type        = string
}

variable "versioning" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = true
}

variable "logging_enabled" {
  description = "Enable logging for the S3 bucket"
  type        = bool
  default     = true
}

variable "logging_bucket" {
  description = "Target bucket for S3 access logs"
  type        = string
  default     = ""
}

variable "lifecycle_rules" {
  description = "Lifecycle rules for the S3 bucket"
  type        = list(object({
    id                                = string
    enabled                           = bool
    expiration_days                   = optional(number)
    transitions                       = optional(list(object({
      days                            = number
      storage_class                   = string
    })))
    noncurrent_version_expiration_days = optional(number)
  }))
  default     = []
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "create_efs" {
  description = "Whether to create an EFS file system"
  type        = bool
  default     = false
}

variable "efs_subnet_ids" {
  description = "Subnet IDs for EFS mount targets"
  type        = list(string)
  default     = []
}

variable "efs_security_group_ids" {
  description = "Security group IDs for EFS mount targets"
  type        = list(string)
  default     = []
}

variable "efs_kms_key_id" {
  description = "KMS key ID for EFS encryption"
  type        = string
  default     = null
}

variable "efs_performance_mode" {
  description = "EFS performance mode (generalPurpose or maxIO)"
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "EFS throughput mode (bursting or provisioned)"
  type        = string
  default     = "bursting"
}

variable "efs_transition_to_ia" {
  description = "EFS lifecycle policy to transition to IA storage class"
  type        = string
  default     = null
}

variable "efs_enable_backup" {
  description = "Enable AWS Backup for EFS"
  type        = bool
  default     = true
}

variable "create_efs_access_point" {
  description = "Whether to create an EFS access point"
  type        = bool
  default     = false
}

variable "efs_access_point_gid" {
  description = "POSIX group ID for EFS access point"
  type        = number
  default     = 1000
}

variable "efs_access_point_uid" {
  description = "POSIX user ID for EFS access point"
  type        = number
  default     = 1000
}

variable "efs_access_point_path" {
  description = "Path for EFS access point"
  type        = string
  default     = "/data"
}

variable "efs_access_point_permissions" {
  description = "POSIX permissions for EFS access point"
  type        = string
  default     = "0755"
}

variable "create_bucket_size_alarm" {
  description = "Whether to create a CloudWatch alarm for bucket size"
  type        = bool
  default     = false
}

variable "bucket_size_alarm_threshold" {
  description = "Threshold for bucket size alarm in bytes"
  type        = number
  default     = 5368709120  # 5 GB
}

variable "create_objects_count_alarm" {
  description = "Whether to create a CloudWatch alarm for number of objects"
  type        = bool
  default     = false
}

variable "objects_count_alarm_threshold" {
  description = "Threshold for number of objects alarm"
  type        = number
  default     = 10000
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