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

# Topic Configuration
variable "message_retention_duration" {
  description = "How long to retain unacknowledged messages"
  type        = string
  default     = "604800s"  # 7 days
}

variable "allowed_persistence_regions" {
  description = "List of regions where messages can be stored"
  type        = list(string)
  default     = ["us-central1"]
}

# Subscription Configuration
variable "ack_deadline_seconds" {
  description = "Maximum time after subscriber receives message before it must acknowledge"
  type        = number
  default     = 60
}

variable "retain_acked_messages" {
  description = "Whether to retain acknowledged messages"
  type        = bool
  default     = false
}

variable "subscription_ttl" {
  description = "TTL for the subscription if no activity"
  type        = string
  default     = "2678400s"  # 31 days
}

variable "enable_message_ordering" {
  description = "Whether to enable message ordering"
  type        = bool
  default     = false
}

variable "subscription_filter" {
  description = "Filter expression for the subscription"
  type        = string
  default     = ""
}

# Retry Configuration
variable "retry_minimum_backoff" {
  description = "Minimum delay between retry attempts"
  type        = string
  default     = "10s"
}

variable "retry_maximum_backoff" {
  description = "Maximum delay between retry attempts"
  type        = string
  default     = "600s"
}

# Dead Letter Queue Configuration
variable "enable_dead_letter_queue" {
  description = "Whether to enable dead letter queue"
  type        = bool
  default     = true
}

variable "max_delivery_attempts" {
  description = "Maximum number of delivery attempts before sending to dead letter queue"
  type        = number
  default     = 5
}

# Push Configuration
variable "push_endpoint" {
  description = "HTTP endpoint for push subscription"
  type        = string
  default     = ""
}

variable "push_attributes" {
  description = "Attributes for push messages"
  type        = map(string)
  default     = {}
}

variable "oidc_service_account_email" {
  description = "Service account email for OIDC authentication"
  type        = string
  default     = ""
}

variable "oidc_audience" {
  description = "Audience for OIDC token"
  type        = string
  default     = ""
}

# Schema Configuration
variable "create_schema" {
  description = "Whether to create a Pub/Sub schema"
  type        = bool
  default     = false
}

variable "schema_name" {
  description = "Name of the Pub/Sub schema to use"
  type        = string
  default     = ""
}

variable "schema_type" {
  description = "Type of the schema (AVRO or PROTOCOL_BUFFER)"
  type        = string
  default     = "AVRO"
  
  validation {
    condition     = contains(["AVRO", "PROTOCOL_BUFFER"], var.schema_type)
    error_message = "Schema type must be either AVRO or PROTOCOL_BUFFER."
  }
}

variable "schema_encoding" {
  description = "Encoding for the schema (JSON or BINARY)"
  type        = string
  default     = "JSON"
  
  validation {
    condition     = contains(["JSON", "BINARY"], var.schema_encoding)
    error_message = "Schema encoding must be either JSON or BINARY."
  }
}

variable "schema_definition" {
  description = "The schema definition"
  type        = string
  default     = ""
}

# IAM Configuration
variable "publisher_service_accounts" {
  description = "List of service account emails that can publish to the topic"
  type        = list(string)
  default     = []
}

variable "subscriber_service_accounts" {
  description = "List of service account emails that can subscribe to the subscription"
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

variable "undelivered_messages_threshold" {
  description = "Threshold for undelivered messages alert"
  type        = number
  default     = 100
}

variable "oldest_unacked_message_threshold" {
  description = "Threshold for oldest unacked message age in seconds"
  type        = number
  default     = 600  # 10 minutes
}