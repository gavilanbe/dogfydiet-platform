# terraform/modules/monitoring/variables.tf

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

variable "gke_cluster_name" {
  description = "Name of the GKE cluster to monitor"
  type        = string
}

variable "notification_email" {
  description = "Email address for monitoring notifications"
  type        = string
}

# Alert Thresholds
variable "cpu_threshold" {
  description = "CPU usage threshold for alerts (0.0 to 1.0)"
  type        = number
  default     = 0.8
}

variable "memory_threshold" {
  description = "Memory usage threshold for alerts (0.0 to 1.0)"
  type        = number
  default     = 0.85
}

variable "error_rate_threshold" {
  description = "Error rate threshold for alerts (0.0 to 1.0)"
  type        = number
  default     = 0.05
}

variable "latency_threshold_ms" {
  description = "Latency threshold for alerts in milliseconds"
  type        = number
  default     = 2000
}

variable "min_request_volume" {
  description = "Minimum request volume per minute"
  type        = number
  default     = 10
}

variable "error_log_threshold" {
  description = "Error log count threshold per minute"
  type        = number
  default     = 10
}

# Monitoring Configuration
variable "enable_uptime_checks" {
  description = "Whether to enable uptime checks"
  type        = bool
  default     = true
}

variable "uptime_check_urls" {
  description = "List of URLs to monitor with uptime checks"
  type        = list(string)
  default     = []
}