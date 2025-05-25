variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}

# Firestore Configuration
variable "database_name" {
  description = "Name of the Firestore database"
  type        = string
  default     = "(default)"
}

variable "app_engine_location" {
  description = "The location ID for the App Engine application. This is immutable after creation."
  type        = string
  default     = "us-central"
}

variable "firestore_location" {
  description = "Location for Firestore database"
  type        = string
  default     = "us-central1"
}

variable "database_type" {
  description = "Type of Firestore database"
  type        = string
  default     = "FIRESTORE_NATIVE"

  validation {
    condition     = contains(["FIRESTORE_NATIVE", "DATASTORE_MODE"], var.database_type)
    error_message = "Database type must be either FIRESTORE_NATIVE or DATASTORE_MODE."
  }
}

variable "concurrency_mode" {
  description = "Concurrency mode for the database"
  type        = string
  default     = "OPTIMISTIC"

  validation {
    condition     = contains(["OPTIMISTIC", "PESSIMISTIC"], var.concurrency_mode)
    error_message = "Concurrency mode must be either OPTIMISTIC or PESSIMISTIC."
  }
}

variable "app_engine_integration_mode" {
  description = "App Engine integration mode"
  type        = string
  default     = "DISABLED"

  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.app_engine_integration_mode)
    error_message = "App Engine integration mode must be either ENABLED or DISABLED."
  }
}

variable "enable_point_in_time_recovery" {
  description = "Whether to enable point-in-time recovery"
  type        = bool
  default     = false # Enable in production
}

variable "enable_delete_protection" {
  description = "Whether to enable delete protection"
  type        = bool
  default     = false # Enable in production
}

# Indexing Configuration
variable "create_indexes" {
  description = "Whether to create custom indexes"
  type        = bool
  default     = true
}

# Backup Configuration
variable "enable_backup" {
  description = "Whether to enable automated backups"
  type        = bool
  default     = false # Enable in production
}

variable "backup_retention" {
  description = "Backup retention period"
  type        = string
  default     = "2592000s" # 30 days
}

variable "backup_frequency" {
  description = "Backup frequency (daily or weekly)"
  type        = string
  default     = "daily"

  validation {
    condition     = contains(["daily", "weekly"], var.backup_frequency)
    error_message = "Backup frequency must be either daily or weekly."
  }
}

variable "backup_day" {
  description = "Day of the week for weekly backups"
  type        = string
  default     = "SUNDAY"

  validation {
    condition = contains([
      "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY",
      "FRIDAY", "SATURDAY", "SUNDAY"
    ], var.backup_day)
    error_message = "Backup day must be a valid day of the week."
  }
}

# Security Configuration
variable "deploy_security_rules" {
  description = "Whether to deploy Firestore security rules"
  type        = bool
  default     = true
}

variable "security_rules_content" {
  description = "Content of the Firestore security rules file"
  type        = string
  default     = <<-EOT
    rules_version = '2';
    service cloud.firestore {
      match /databases/{database}/documents {
        // Allow read/write access for development
        // In production, implement proper authentication rules
        match /{document=**} {
          allow read, write: if true;
        }
      }
    }
  EOT
}

# IAM Configuration
variable "firestore_users" {
  description = "List of service account emails that need Firestore user access"
  type        = list(string)
  default     = []
}

variable "firestore_viewers" {
  description = "List of service account emails that need Firestore viewer access"
  type        = list(string)
  default     = []
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Whether to enable monitoring and alerting"
  type        = bool
  default     = true
}

variable "notification_channels" {
  description = "List of notification channel IDs for alerts"
  type        = list(string)
  default     = []
}

variable "read_ops_threshold" {
  description = "Threshold for read operations per second alert"
  type        = number
  default     = 1000
}

variable "write_ops_threshold" {
  description = "Threshold for write operations per second alert"
  type        = number
  default     = 500
}