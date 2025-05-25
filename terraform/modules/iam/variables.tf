variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
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
  description = "Name of the GKE cluster"
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for the applications"
  type        = string
  default     = "default"
}

# Service Account Configuration
variable "create_service_account_keys" {
  description = "Whether to create service account keys (not recommended for production)"
  type        = bool
  default     = true # Set to false in production, use workload identity instead
}

variable "enable_workload_identity" {
  description = "Whether to enable workload identity"
  type        = bool
  default     = true
}