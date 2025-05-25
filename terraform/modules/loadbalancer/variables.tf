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

# Load Balancer Configuration
variable "default_backend_service" {
  description = "Default backend service for the load balancer"
  type        = string
}

variable "enable_https" {
  description = "Whether to enable HTTPS"
  type        = bool
  default     = false
}

variable "https_redirect" {
  description = "Whether to redirect HTTP to HTTPS"
  type        = bool
  default     = true
}

variable "enable_quic" {
  description = "Whether to enable QUIC protocol"
  type        = bool
  default     = false
}

# SSL Configuration
variable "ssl_certificates" {
  description = "List of SSL certificate resource URLs"
  type        = list(string)
  default     = []
}

variable "create_managed_certificate" {
  description = "Whether to create a Google-managed SSL certificate"
  type        = bool
  default     = false
}

variable "managed_certificate_domains" {
  description = "Domains for the managed SSL certificate"
  type        = list(string)
  default     = []
}

variable "ssl_policy" {
  description = "URL of the SSL policy resource"
  type        = string
  default     = null
}

variable "create_ssl_policy" {
  description = "Whether to create an SSL policy"
  type        = bool
  default     = false
}

variable "ssl_policy_profile" {
  description = "Profile for SSL policy (COMPATIBLE, MODERN, RESTRICTED, CUSTOM)"
  type        = string
  default     = "MODERN"
}

variable "ssl_policy_min_tls_version" {
  description = "Minimum TLS version (TLS_1_0, TLS_1_1, TLS_1_2)"
  type        = string
  default     = "TLS_1_2"
}

# Routing Configuration
variable "host_rules" {
  description = "List of host rules for routing"
  type = list(object({
    hosts        = list(string)
    path_matcher = string
  }))
  default = []
}

variable "path_matchers" {
  description = "List of path matchers for routing"
  type = list(object({
    name            = string
    default_service = string
    path_rules = list(object({
      paths   = list(string)
      service = string
    }))
  }))
  default = []
}

# Backend Service Configuration
variable "create_backend_service" {
  description = "Whether to create a backend service"
  type        = bool
  default     = false
}

variable "backend_protocol" {
  description = "Protocol for the backend service (HTTP, HTTPS, HTTP2, TCP, SSL, GRPC)"
  type        = string
  default     = "HTTP"
}

variable "backend_port_name" {
  description = "Port name for the backend service"
  type        = string
  default     = "http"
}

variable "backend_timeout" {
  description = "Timeout for the backend service in seconds"
  type        = number
  default     = 30
}

variable "health_checks" {
  description = "List of health check resource URLs"
  type        = list(string)
  default     = []
}

# Cloud Armor Configuration
variable "enable_cloud_armor" {
  description = "Whether to enable Cloud Armor"
  type        = bool
  default     = false
}

variable "enable_rate_limiting" {
  description = "Whether to enable rate limiting"
  type        = bool
  default     = false
}

variable "rate_limit_threshold" {
  description = "Rate limit threshold (requests per interval)"
  type        = number
  default     = 100
}

variable "rate_limit_interval" {
  description = "Rate limit interval in seconds"
  type        = number
  default     = 60
}

variable "rate_limit_ban_duration" {
  description = "Ban duration in seconds for rate limit violations"
  type        = number
  default     = 600
}

variable "cloud_armor_rules" {
  description = "List of Cloud Armor custom rules"
  type = list(object({
    action         = string
    priority       = number
    versioned_expr = string
    src_ip_ranges  = list(string)
    description    = string
  }))
  default = []
}

# Logging Configuration
variable "enable_logging" {
  description = "Whether to enable logging for the backend service"
  type        = bool
  default     = true
}

variable "log_sample_rate" {
  description = "Sample rate for logging (0.0 to 1.0)"
  type        = number
  default     = 1.0
}

# Identity-Aware Proxy Configuration
variable "iap_oauth2_client_id" {
  description = "OAuth2 client ID for IAP"
  type        = string
  default     = ""
}

variable "iap_oauth2_client_secret" {
  description = "OAuth2 client secret for IAP"
  type        = string
  default     = ""
  sensitive   = true
}