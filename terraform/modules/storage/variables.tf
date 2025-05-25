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

# Storage Configuration
variable "bucket_location" {
  description = "Location for the storage bucket"
  type        = string
  default     = "US"
}

variable "force_destroy" {
  description = "Whether to force destroy the bucket when deleting"
  type        = bool
  default     = true  # Set to false in production
}

variable "enable_versioning" {
  description = "Whether to enable object versioning"
  type        = bool
  default     = false
}

variable "object_lifecycle_days" {
  description = "Number of days after which objects are deleted"
  type        = number
  default     = 90
}

# CORS Configuration
variable "cors_origins" {
  description = "Allowed CORS origins"
  type        = list(string)
  default     = ["*"]
}

# CDN Configuration
variable "enable_cdn" {
  description = "Whether to enable Cloud CDN"
  type        = bool
  default     = true
}

variable "cdn_default_ttl" {
  description = "Default TTL for CDN cache in seconds"
  type        = number
  default     = 3600
}

variable "cdn_max_ttl" {
  description = "Maximum TTL for CDN cache in seconds"
  type        = number
  default     = 86400
}

variable "cdn_client_ttl" {
  description = "Client TTL for CDN cache in seconds"
  type        = number
  default     = 3600
}