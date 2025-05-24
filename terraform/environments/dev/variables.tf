# terraform/environments/dev/variables.tf

variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "nahuelgabe-test"
}

variable "project_name" {
  description = "The project name for resource naming"
  type        = string
  default     = "dogfydiet"
}

variable "environment" {
  description = "The deployment environment"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone for resources"
  type        = string
  default     = "us-central1-a"
}

variable "notification_email" {
  description = "Email for monitoring notifications"
  type        = string
  default     = "nahuel@example.com"  # Update with your email
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# Secondary IP Ranges for GKE
variable "pods_cidr_range" {
  description = "CIDR block for GKE pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_cidr_range" {
  description = "CIDR block for GKE services"
  type        = string
  default     = "10.2.0.0/16"
}

variable "gke_master_cidr" {
  description = "CIDR block for GKE master nodes"
  type        = string
  default     = "172.16.0.0/28"
}

# GKE Configuration
variable "gke_node_count" {
  description = "Number of nodes in the GKE cluster"
  type        = number
  default     = 2
}

variable "gke_node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "gke_node_disk_size" {
  description = "Disk size for GKE nodes in GB"
  type        = number
  default     = 50
}

variable "gke_max_node_count" {
  description = "Maximum number of nodes in the GKE cluster"
  type        = number
  default     = 5
}

variable "gke_min_node_count" {
  description = "Minimum number of nodes in the GKE cluster"
  type        = number
  default     = 1
}