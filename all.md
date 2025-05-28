FILE_PATH_START
./terraform/environments/dev/outputs.tf
FILE_CONTENT_START
# Network Outputs
output "vpc_network_name" {
  description = "The name of the VPC network"
  value       = module.vpc.network_name
}

output "vpc_network_self_link" {
  description = "The self-link of the VPC network"
  value       = module.vpc.network_self_link
}

output "private_subnet_name" {
  description = "The name of the private subnet"
  value       = module.vpc.private_subnet_name
}

output "public_subnet_name" {
  description = "The name of the public subnet"
  value       = module.vpc.public_subnet_name
}

# GKE Outputs
output "gke_cluster_name" {
  description = "The name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "The endpoint of the GKE cluster"
  value       = module.gke.endpoint
  sensitive   = true
}

output "gke_cluster_ca_certificate" {
  description = "The CA certificate of the GKE cluster"
  value       = module.gke.ca_certificate
  sensitive   = true
}

output "gke_cluster_location" {
  description = "The location of the GKE cluster"
  value       = module.gke.location
}

# Storage Outputs
output "frontend_bucket_name" {
  description = "The name of the frontend storage bucket"
  value       = module.storage.frontend_bucket_name
}

output "frontend_bucket_url" {
  description = "The URL of the frontend storage bucket"
  value       = module.storage.frontend_bucket_url
}

# Load Balancer Outputs
output "load_balancer_ip" {
  description = "The static IP address of the load balancer"
  value       = module.loadbalancer.load_balancer_ip
}

output "load_balancer_url" {
  description = "The URL to access the application via load balancer"
  value       = module.loadbalancer.load_balancer_url
}

output "frontend_url" {
  description = "The URL to access the frontend application"
  value       = "http://${module.loadbalancer.load_balancer_ip}"
}

# Pub/Sub Outputs
output "pubsub_topic_name" {
  description = "The name of the Pub/Sub topic"
  value       = module.pubsub.topic_name
}

output "pubsub_subscription_name" {
  description = "The name of the Pub/Sub subscription"
  value       = module.pubsub.subscription_name
}

# Firestore Outputs
output "firestore_database_name" {
  description = "The name of the Firestore database"
  value       = module.firestore.database_name
}

# IAM Outputs
output "microservice_1_service_account" {
  description = "Service account email for microservice 1"
  value       = module.iam.microservice_1_service_account
}

output "microservice_2_service_account" {
  description = "Service account email for microservice 2"
  value       = module.iam.microservice_2_service_account
}

output "docker_repository_url" {
  description = "URL of the Docker repository"
  value       = module.iam.docker_repository_url
}

# Monitoring Outputs
output "monitoring_notification_channel" {
  description = "Monitoring notification channel ID"
  value       = module.monitoring.notification_channel_id
}

# kubectl configuration command
output "kubectl_config" {
  description = "Command to configure kubectl"
  value       = module.gke.kubectl_config
}

# Important URLs and commands
output "setup_instructions" {
  description = "Post-deployment setup instructions"
  value       = <<-EOT
    
    ========================================
    🚀 DogfyDiet Platform Deployment Complete!
    ========================================
    
    Frontend URL: http://${module.loadbalancer.load_balancer_ip}
    Frontend Bucket: ${module.storage.frontend_bucket_name}
    
    To configure kubectl:
    ${module.gke.kubectl_config}
    
    To deploy applications:
    1. Update GitHub secret FRONTEND_BUCKET_NAME with: ${module.storage.frontend_bucket_name}
    2. Update GitHub secret API_URL with: http://${module.loadbalancer.load_balancer_ip}/api
    3. Push changes to trigger CI/CD pipeline
    
    To access the frontend directly via bucket:
    ${module.storage.frontend_bucket_website_url}
    
  EOT
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/environments/dev/main.tf
FILE_CONTENT_START
terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "gcs" {
    bucket = "nahuelgabe-test-terraform-state"
    prefix = "dogfydiet-platform/dev"
  }
}

# Configure providers
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Data sources
data "google_client_config" "default" {}

# Conditional provider configuration
# Only configure if cluster exists
provider "kubernetes" {
  host                   = try("https://${module.gke.endpoint}", "")
  token                  = try(data.google_client_config.default.access_token, "")
  cluster_ca_certificate = try(base64decode(module.gke.ca_certificate), "")
}

provider "helm" {
  kubernetes {
    host                   = try("https://${module.gke.endpoint}", "")
    token                  = try(data.google_client_config.default.access_token, "")
    cluster_ca_certificate = try(base64decode(module.gke.ca_certificate), "")
  }
}

locals {
  environment = var.environment
  project     = var.project_name

  common_labels = {
    environment = local.environment
    project     = local.project
    managed_by  = "terraform"
  }

  # Naming convention: {project}-{environment}-{resource}
  name_prefix = "${local.project}-${local.environment}"
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix
  environment = local.environment

  private_subnet_cidr = var.private_subnet_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  pods_cidr_range     = var.pods_cidr_range
  services_cidr_range = var.services_cidr_range
  gke_master_cidr     = var.gke_master_cidr

  labels = local.common_labels
}

##### NEW FIREWALL RULE #####
# Firewall rule to allow health checks from Google Cloud Load Balancer to GKE Nodes
resource "google_compute_firewall" "allow_lb_health_checks_to_gke_nodes" {
  project = var.project_id
  name    = "${local.name_prefix}-allow-lb-hc-gke" # e.g., dogfydiet-dev-allow-lb-hc-gke
  network = module.vpc.network_name               # Uses the network created by the vpc module

  description = "Allow health checks from GCP Load Balancer to GKE worker nodes"

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  # Google Cloud health checker IP ranges
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]

  # Target GKE nodes using the tag applied by your GKE module.
  target_tags = ["${local.name_prefix}-gke-node"] # e.g., dogfydiet-dev-gke-node

  priority = 1000 # Standard priority

  depends_on = [module.vpc] # Ensure VPC is created first
}



# GKE Module
module "gke" {
  source = "../../modules/gke"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix
  environment = local.environment

  network_name           = module.vpc.network_name
  subnet_name            = module.vpc.private_subnet_name
  master_ipv4_cidr_block = var.gke_master_cidr

  min_node_count    = var.gke_min_node_count
  max_node_count    = var.gke_max_node_count
  node_machine_type = var.gke_node_machine_type
  node_disk_size_gb = var.gke_node_disk_size

  labels = local.common_labels

  depends_on = [module.vpc]
}

# Cloud Storage Module for Frontend
module "storage" {
  source = "../../modules/storage"

  project_id  = var.project_id
  name_prefix = local.name_prefix
  environment = local.environment

  # CDN configuration
  enable_cdn      = true
  cdn_default_ttl = 3600
  cdn_max_ttl     = 86400

  labels = local.common_labels
}

# Load Balancer Module
module "loadbalancer" {
  source = "../../modules/loadbalancer"

  project_id  = var.project_id
  name_prefix = local.name_prefix
  environment = local.environment

  # Backend configuration
  default_backend_service = module.storage.backend_bucket_self_link # This is for GCS (frontend)

  # HTTPS configuration
  enable_https               = true
  create_managed_certificate = true
  ssl_certificates = [module.loadbalancer.ssl_certificate_self_link]
  managed_certificate_domains = ["nahueldog.duckdns.org"]

  # --- START: Pass GKE backend variables ---
  enable_gke_backend            = true                                                                                          # Enable the GKE backend
  gke_neg_name = "k8s1-98d6217d-default-microservice-1-80-247119ef"
  gke_neg_zone = "us-central1-c"
  gke_backend_service_port_name = "http"                                                                                        # Matches the port name in your microservice-1 k8s Service
  gke_health_check_port         = 3000                                                                                          # Port for microservice-1 health check
  gke_health_check_request_path = "/health"                                                                                     # Path for microservice-1 health check
  # --- END: Pass GKE backend variables ---




  # Cloud Armor configuration (disabled for dev)
  enable_cloud_armor   = false
  enable_rate_limiting = false

  labels = local.common_labels

  depends_on = [module.storage, module.gke] # Added module.gke dependency
}

# Pub/Sub Module
module "pubsub" {
  source = "../../modules/pubsub"

  project_id  = var.project_id
  name_prefix = local.name_prefix
  environment = local.environment

  labels = local.common_labels
}

# Firestore Module
module "firestore" {
  source = "../../modules/firestore"

  project_id  = var.project_id
  name_prefix = local.name_prefix
  environment = local.environment

  labels = local.common_labels
}

# IAM Module
module "iam" {
  source = "../../modules/iam"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix
  environment = local.environment

  gke_cluster_name = module.gke.cluster_name
  # Disable workload identity bindings until GKE cluster is created
  enable_workload_identity = false

  labels = local.common_labels

  depends_on = [module.gke]
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"

  project_id  = var.project_id
  name_prefix = local.name_prefix
  environment = local.environment

  gke_cluster_name   = module.gke.cluster_name
  notification_email = var.notification_email

  labels = local.common_labels

  depends_on = [module.gke]
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/environments/dev/terraform.tfvars
FILE_CONTENT_START
# Project Configuration
project_id   = "nahuelgabe-test"
project_name = "dogfydiet"
environment  = "dev"

# Regional Configuration
region = "us-central1"
zone   = "us-central1-a"

# Network Configuration
vpc_cidr            = "10.0.0.0/16"
private_subnet_cidr = "10.0.1.0/24"
public_subnet_cidr  = "10.0.2.0/24"
pods_cidr_range     = "10.1.0.0/16"
services_cidr_range = "10.2.0.0/16"
gke_master_cidr     = "172.16.0.0/28"

# GKE Cluster Configuration
gke_node_count        = 2
gke_node_machine_type = "e2-standard-2"
gke_node_disk_size    = 50
gke_max_node_count    = 5
gke_min_node_count    = 1

# Monitoring Configuration (change test)
notification_email = "nahuelgavilanbe@gmail.com"
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/environments/dev/variables.tf
FILE_CONTENT_START
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
  default     = "nahuel@example.com" # Update with your email
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

# In ./environments/dev/variables.tf
# ... (other variables)

variable "k8s_namespace_for_ms1_helm_chart" {
  description = "Kubernetes namespace where microservice-1 is deployed (used for NEG naming)."
  type        = string
  default     = "default" # Or whatever namespace you use in your Helm chart for microservice-1
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/firestore/outputs.tf
FILE_CONTENT_START
output "database_name" {
  description = "The name of the Firestore database"
  value       = google_firestore_database.main.name
}

output "database_id" {
  description = "The ID of the Firestore database"
  value       = google_firestore_database.main.id
}

output "app_engine_application_id" {
  description = "The App Engine application ID"
  value       = google_app_engine_application.default.app_id
}

output "firestore_location" {
  description = "The location of the Firestore database"
  value       = var.firestore_location
}

output "database_connection_string" {
  description = "Connection string for the Firestore database"
  value       = "projects/${var.project_id}/databases/${google_firestore_database.main.name}"
}

output "backup_schedule_name" {
  description = "The name of the backup schedule (if enabled)"
  value       = var.enable_backup ? google_firestore_backup_schedule.main[0].name : ""
}

output "security_rules_deployed" {
  description = "Whether security rules have been deployed"
  value       = var.deploy_security_rules
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/firestore/main.tf
FILE_CONTENT_START
# Enable required APIs
resource "google_project_service" "firestore" {
  service            = "firestore.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "appengine" {
  service            = "appengine.googleapis.com"
  disable_on_destroy = false
}

# App Engine application (required for Firestore)
resource "google_app_engine_application" "default" {
  project     = var.project_id
  location_id = var.app_engine_location
  # database_type = "CLOUD_FIRESTORE"

  depends_on = [
    google_project_service.appengine,
    google_project_service.firestore
  ]
}

# Firestore Database
resource "google_firestore_database" "main" {
  project                           = var.project_id
  name                              = var.database_name
  location_id                       = var.firestore_location
  type                              = var.database_type
  concurrency_mode                  = var.concurrency_mode
  app_engine_integration_mode       = var.app_engine_integration_mode
  point_in_time_recovery_enablement = var.enable_point_in_time_recovery ? "POINT_IN_TIME_RECOVERY_ENABLED" : "POINT_IN_TIME_RECOVERY_DISABLED"
  delete_protection_state           = var.enable_delete_protection ? "DELETE_PROTECTION_ENABLED" : "DELETE_PROTECTION_DISABLED"

  depends_on = [google_app_engine_application.default]
}

# Firestore Backup Schedule
resource "google_firestore_backup_schedule" "main" {
  count = var.enable_backup ? 1 : 0

  project  = var.project_id
  database = google_firestore_database.main.name

  retention = var.backup_retention

  dynamic "daily_recurrence" {
    for_each = var.backup_frequency == "daily" ? [1] : []
    content {}
  }

  dynamic "weekly_recurrence" {
    for_each = var.backup_frequency == "weekly" ? [1] : []
    content {
      day = var.backup_day
    }
  }
}

# IAM bindings for service accounts
resource "google_project_iam_member" "firestore_user" {
  for_each = toset(var.firestore_users)

  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${each.value}"
}

resource "google_project_iam_member" "firestore_viewer" {
  for_each = toset(var.firestore_viewers)

  project = var.project_id
  role    = "roles/datastore.viewer"
  member  = "serviceAccount:${each.value}"
}

# Security Rules (basic rules for development)
resource "google_firebaserules_ruleset" "firestore" {
  count = var.deploy_security_rules ? 1 : 0

  project = var.project_id

  source {
    files {
      content = var.security_rules_content
      name    = "firestore.rules"
    }
  }

  depends_on = [google_firestore_database.main]
}

resource "google_firebaserules_release" "firestore" {
  count = var.deploy_security_rules ? 1 : 0

  name         = "cloud.firestore"
  ruleset_name = google_firebaserules_ruleset.firestore[0].name
  project      = var.project_id

  depends_on = [google_firebaserules_ruleset.firestore]
}

# Monitoring alerts for Firestore
resource "google_monitoring_alert_policy" "firestore_read_ops" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "${var.name_prefix} Firestore Read Operations"

  documentation {
    content = "Alert when Firestore read operations exceed threshold"
  }

  conditions {
    display_name = "High read operations"

    condition_threshold {
      filter          = "resource.type=\"firestore.googleapis.com/Database\" AND resource.labels.database_id=\"${google_firestore_database.main.name}\" AND metric.type=\"firestore.googleapis.com/document/read_ops_count\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.read_ops_threshold

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  combiner              = "OR"
  enabled               = true
  notification_channels = var.notification_channels
}

resource "google_monitoring_alert_policy" "firestore_write_ops" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "${var.name_prefix} Firestore Write Operations"

  documentation {
    content = "Alert when Firestore write operations exceed threshold"
  }

  conditions {
    display_name = "High write operations"

    condition_threshold {
      filter          = "resource.type=\"firestore.googleapis.com/Database\" AND resource.labels.database_id=\"${google_firestore_database.main.name}\" AND metric.type=\"firestore.googleapis.com/document/write_ops_count\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.write_ops_threshold

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  combiner              = "OR"
  enabled               = true
  notification_channels = var.notification_channels
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/firestore/variables.tf
FILE_CONTENT_START
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
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/loadbalancer/outputs.tf
FILE_CONTENT_START
output "load_balancer_ip" {
  description = "The IP address of the load balancer"
  value       = google_compute_global_address.main.address
}

output "load_balancer_ip_name" {
  description = "The name of the load balancer IP address resource"
  value       = google_compute_global_address.main.name
}

output "load_balancer_ip_self_link" {
  description = "The self-link of the load balancer IP address"
  value       = google_compute_global_address.main.self_link
}

output "url_map_id" {
  description = "The ID of the URL map"
  value       = google_compute_url_map.main.id
}

output "url_map_self_link" {
  description = "The self-link of the URL map"
  value       = google_compute_url_map.main.self_link
}

output "http_proxy_id" {
  description = "The ID of the HTTP proxy"
  value       = google_compute_target_http_proxy.main.id
}

output "https_proxy_id" {
  description = "The ID of the HTTPS proxy (if enabled)"
  value       = var.enable_https ? google_compute_target_https_proxy.main[0].id : null
}

output "http_forwarding_rule_id" {
  description = "The ID of the HTTP forwarding rule"
  value       = google_compute_global_forwarding_rule.http.id
}

output "https_forwarding_rule_id" {
  description = "The ID of the HTTPS forwarding rule (if enabled)"
  value       = var.enable_https ? google_compute_global_forwarding_rule.https[0].id : null
}

output "ssl_certificate_id" {
  description = "The ID of the managed SSL certificate (if created)"
  value       = var.enable_https && var.create_managed_certificate ? google_compute_managed_ssl_certificate.main[0].id : null
}

output "ssl_certificate_self_link" {
  description = "The self-link of the managed SSL certificate (if created)"
  value       = var.enable_https && var.create_managed_certificate ? google_compute_managed_ssl_certificate.main[0].self_link : null
}

output "ssl_policy_id" {
  description = "The ID of the SSL policy (if created)"
  value       = var.enable_https && var.create_ssl_policy ? google_compute_ssl_policy.main[0].id : null
}

output "cloud_armor_policy_id" {
  description = "The ID of the Cloud Armor security policy (if enabled)"
  value       = var.enable_cloud_armor ? google_compute_security_policy.main[0].id : null
}

# output "backend_service_id" {
#   description = "The ID of the backend service (if created)"
#   value       = var.create_backend_service ? google_compute_backend_service.main[0].id : null
# }



output "load_balancer_url" {
  description = "The URL to access the load balancer"
  value       = "http://${google_compute_global_address.main.address}"
}

output "load_balancer_https_url" {
  description = "The HTTPS URL to access the load balancer (if enabled)"
  value       = var.enable_https ? "https://${google_compute_global_address.main.address}" : null
}


output "gke_ms1_backend_service_id" {
  description = "The ID of the backend service for Microservice 1 GKE NEG"
  value       = var.enable_gke_backend ? google_compute_backend_service.gke_ms1_backend[0].id : null
}

output "gke_ms1_backend_service_self_link" {
  description = "The self-link of the backend service for Microservice 1 GKE NEG"
  value       = var.enable_gke_backend ? google_compute_backend_service.gke_ms1_backend[0].self_link : null
}

output "gke_ms1_health_check_id" {
  description = "The ID of the health check for Microservice 1 GKE backend"
  value       = var.enable_gke_backend ? google_compute_health_check.gke_ms1_health_check[0].id : null
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/loadbalancer/main.tf
FILE_CONTENT_START
resource "google_compute_global_address" "main" {
  name         = "${var.name_prefix}-lb-ip"
  description  = "Static IP address for load balancer"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"

  labels = var.labels
}

# --- START: Health Check for GKE Backend (microservice-1) ---
resource "google_compute_health_check" "gke_ms1_health_check" {
  count = var.enable_gke_backend ? 1 : 0

  name                = "${var.name_prefix}-ms1-hc"
  description         = "Health check for Microservice 1"
  check_interval_sec  = 15 # From your backendconfig.yaml
  timeout_sec         = 5  # From your backendconfig.yaml
  healthy_threshold   = 2  # From your backendconfig.yaml
  unhealthy_threshold = 2  # From your backendconfig.yaml

  http_health_check {
    port_specification = "USE_SERVING_PORT" # NEG will provide the port
    request_path       = var.gke_health_check_request_path
  }
}
# --- END: Health Check for GKE Backend (microservice-1) ---

# --- START: Backend Service for GKE NEG (microservice-1) ---
data "google_compute_network_endpoint_group" "gke_ms1_neg" {
  count = var.enable_gke_backend ? 1 : 0

  name    = var.gke_neg_name
  zone    = var.gke_neg_zone # Make sure this is the zone of your GKE cluster/nodes
  project = var.project_id
}

resource "google_compute_backend_service" "gke_ms1_backend" {
  count = var.enable_gke_backend ? 1 : 0

  name                  = "${var.name_prefix}-ms1-backend"
  description           = "Backend service for Microservice 1 (GKE NEG)"
  protocol              = "HTTP"                            # Assuming microservice-1 serves HTTP
  port_name             = var.gke_backend_service_port_name # Should match the service port name in k8s service for ms1
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED" # For Global HTTP(S) LB with NEGs
  enable_cdn            = false              # Usually not needed for API backends

  backend {
    group                 = data.google_compute_network_endpoint_group.gke_ms1_neg[0].self_link
    balancing_mode        = "RATE" # Good for HTTP services
    max_rate_per_endpoint = 100    # Adjust as needed
  }

  health_checks = [google_compute_health_check.gke_ms1_health_check[0].self_link]

  log_config {
    enable      = var.enable_logging
    sample_rate = var.log_sample_rate
  }

  # If you have a BackendConfig for this service in k8s, its settings (like IAP, CDN)
  # are applied by GKE. For Terraform managed backend services with NEGs,
  # you often configure these directly here or leave them to GKE if using `BackendConfig`
  # with the service.
  # If using BackendConfig for IAP, timeout, etc. from GKE, ensure it's correctly associated
  # with the K8s service. For health checks, it's safer to also define it in TF for the backend_service.

  # security_policy = var.enable_cloud_armor ? google_compute_security_policy.main[0].id : null
  # dynamic "iap" {
  #   for_each = var.iap_oauth2_client_id != "" ? [1] : []
  #   content {
  #     oauth2_client_id     = var.iap_oauth2_client_id
  #     oauth2_client_secret = var.iap_oauth2_client_secret
  #   }
  # }
}
# --- END: Backend Service for GKE NEG (microservice-1) ---

resource "google_compute_url_map" "main" {
  name        = "${var.name_prefix}-lb-urlmap"
  description = "URL map for load balancer"
  default_service = var.default_backend_service

  dynamic "host_rule" {
    for_each = var.host_rules
    content {
      hosts        = host_rule.value.hosts
      path_matcher = host_rule.value.path_matcher
    }
  }

  path_matcher {
    name            = "allpaths"
    default_service = var.default_backend_service # GCS bucket

    dynamic "path_rule" {
      for_each = var.enable_gke_backend ? [1] : []
      content {
        paths   = ["/api/*"]
        service = google_compute_backend_service.gke_ms1_backend[0].self_link
      }
    }

    path_rule {
      paths   = ["/*"]
      service = var.default_backend_service
    }
  }
}


# HTTP(S) Load Balancer - HTTPS proxy
resource "google_compute_target_https_proxy" "main" {
  count = var.enable_https ? 1 : 0

  name             = "${var.name_prefix}-lb-https-proxy"
  description      = "HTTPS proxy for load balancer"
  url_map          = google_compute_url_map.main.id
  ssl_certificates = var.ssl_certificates
  ssl_policy       = var.ssl_policy

  quic_override = var.enable_quic ? "ENABLE" : "DISABLE"
}

# For HTTP to HTTPS redirect
resource "google_compute_target_http_proxy" "main" {
  name        = "${var.name_prefix}-lb-http-proxy"
  description = "HTTP proxy for load balancer"
  url_map     = var.enable_https && var.https_redirect ? google_compute_url_map.redirect[0].id : google_compute_url_map.main.id
}

# URL map for HTTP to HTTPS redirect
resource "google_compute_url_map" "redirect" {
  count = var.enable_https && var.https_redirect ? 1 : 0

  name        = "${var.name_prefix}-lb-redirect-urlmap"
  description = "URL map for HTTP to HTTPS redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_global_forwarding_rule" "https" {
  count = var.enable_https ? 1 : 0

  name                  = "${var.name_prefix}-lb-https-forwarding-rule"
  description           = "HTTPS forwarding rule for load balancer"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.main[0].id
  ip_address            = google_compute_global_address.main.id

  labels = var.labels
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.name_prefix}-lb-http-forwarding-rule"
  description           = "HTTP forwarding rule for load balancer"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.main.id
  ip_address            = google_compute_global_address.main.id

  labels = var.labels
}

# SSL Certificate (managed by Google)
resource "google_compute_managed_ssl_certificate" "main" {
  count = var.enable_https && var.create_managed_certificate ? 1 : 0

  name        = "${var.name_prefix}-lb-ssl-cert"
  description = "Managed SSL certificate for load balancer"

  managed {
    domains = var.managed_certificate_domains
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_ssl_policy" "main" {
  count = var.enable_https && var.create_ssl_policy ? 1 : 0

  name            = "${var.name_prefix}-lb-ssl-policy"
  description     = "SSL policy for load balancer"
  profile         = var.ssl_policy_profile
  min_tls_version = var.ssl_policy_min_tls_version
}

resource "google_compute_security_policy" "main" {
  count = var.enable_cloud_armor ? 1 : 0

  name        = "${var.name_prefix}-lb-security-policy"
  description = "Cloud Armor security policy for load balancer"

  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule"
  }

  dynamic "rule" {
    for_each = var.enable_rate_limiting ? [1] : []
    content {
      action   = "rate_based_ban"
      priority = "1000"
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = ["*"]
        }
      }
      rate_limit_options {
        conform_action = "allow"
        exceed_action  = "deny(429)"
        rate_limit_threshold {
          count        = var.rate_limit_threshold
          interval_sec = var.rate_limit_interval
        }
        ban_duration_sec = var.rate_limit_ban_duration
      }
      description = "Rate limiting rule"
    }
  }

  dynamic "rule" {
    for_each = var.cloud_armor_rules
    content {
      action   = rule.value.action
      priority = rule.value.priority
      match {
        versioned_expr = rule.value.versioned_expr
        config {
          src_ip_ranges = rule.value.src_ip_ranges
        }
      }
      description = rule.value.description
    }
  }
}

# resource "google_compute_backend_service" "main" {
#   count = var.create_backend_service ? 1 : 0

#   name        = "${var.name_prefix}-lb-backend-service"
#   description = "Backend service for load balancer"

#   protocol    = var.backend_protocol
#   port_name   = var.backend_port_name
#   timeout_sec = var.backend_timeout

#   health_checks = var.health_checks

#   security_policy = var.enable_cloud_armor ? google_compute_security_policy.main[0].id : null

#   log_config {
#     enable      = var.enable_logging
#     sample_rate = var.log_sample_rate
#   }

#   iap {
#     oauth2_client_id     = var.iap_oauth2_client_id
#     oauth2_client_secret = var.iap_oauth2_client_secret
#   }
# }
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/loadbalancer/variables.tf
FILE_CONTENT_START
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

# New variables for GKE Backend
variable "enable_gke_backend" {
  description = "Whether to enable the GKE backend service for microservice-1"
  type        = bool
  default     = false # Set to true in  dev.tfvars / main.tf module call
}

variable "gke_neg_name" {
  description = "The name of the Network Endpoint Group for microservice-1. This is typically auto-generated by GKE."
  type        = string
}

variable "gke_neg_zone" {
  description = "The zone where the GKE NEG for microservice-1 is located."
  type        = string
}

variable "gke_backend_service_port_name" {
  description = "The port name for the GKE backend service (should match service port name)."
  type        = string
  default     = "http" # This should match the 'name: http' in your k8s service and deployment port
}

variable "gke_health_check_port" {
  description = "Port for the GKE backend health check. Should match microservice-1 containerPort."
  type        = number
  default     = 3000
}

variable "gke_health_check_request_path" {
  description = "Request path for GKE backend health check."
  type        = string
  default     = "/health" # Aligns with your microservice-1 backendconfig.yaml
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/storage/outputs.tf
FILE_CONTENT_START
output "frontend_bucket_name" {
  description = "The name of the frontend storage bucket"
  value       = google_storage_bucket.frontend.name
}

output "frontend_bucket_url" {
  description = "The URL of the frontend storage bucket"
  value       = google_storage_bucket.frontend.url
}

output "frontend_bucket_self_link" {
  description = "The self-link of the frontend storage bucket"
  value       = google_storage_bucket.frontend.self_link
}

output "frontend_bucket_website_url" {
  description = "The website URL of the frontend storage bucket"
  value       = "https://storage.googleapis.com/${google_storage_bucket.frontend.name}/index.html"
}

output "backend_bucket_id" {
  description = "The ID of the backend bucket resource"
  value       = google_compute_backend_bucket.frontend.id
}

output "backend_bucket_self_link" {
  description = "The self-link of the backend bucket"
  value       = google_compute_backend_bucket.frontend.self_link
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/storage/main.tf
FILE_CONTENT_START
# Enable required APIs
resource "google_project_service" "storage" {
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

# Frontend hosting bucket
resource "google_storage_bucket" "frontend" {
  name          = "${var.name_prefix}-frontend-${random_id.bucket_suffix.hex}"
  location      = var.bucket_location
  force_destroy = var.force_destroy

  # Website configuration
  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

  # CORS configuration for SPA
  cors {
    origin          = var.cors_origins
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  versioning {
    enabled = var.enable_versioning
  }

  lifecycle_rule {
    condition {
      age = var.object_lifecycle_days
    }
    action {
      type = "Delete"
    }
  }

  public_access_prevention = "inherited"

  uniform_bucket_level_access = true

  labels = var.labels

  depends_on = [google_project_service.storage]
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.frontend.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_compute_backend_bucket" "frontend" {
  name        = "${var.name_prefix}-frontend-backend"
  description = "Backend bucket for frontend static files"
  bucket_name = google_storage_bucket.frontend.name

  enable_cdn = var.enable_cdn

  dynamic "cdn_policy" {
    for_each = var.enable_cdn ? [1] : []
    content {
      cache_mode        = "CACHE_ALL_STATIC"
      default_ttl       = var.cdn_default_ttl
      max_ttl           = var.cdn_max_ttl
      client_ttl        = var.cdn_client_ttl
      negative_caching  = true
      serve_while_stale = 86400

      negative_caching_policy {
        code = 404
        ttl  = 120
      }

      negative_caching_policy {
        code = 410
        ttl  = 120
      }
    }
  }
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/storage/variables.tf
FILE_CONTENT_START
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
  default     = true # Set to false in production
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
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/iam/outputs.tf
FILE_CONTENT_START
output "microservice_1_service_account" {
  description = "Email of the microservice 1 service account"
  value       = google_service_account.microservice_1.email
}

output "microservice_2_service_account" {
  description = "Email of the microservice 2 service account"
  value       = google_service_account.microservice_2.email
}

output "cicd_service_account" {
  description = "Email of the CI/CD service account"
  value       = google_service_account.cicd.email
}

output "artifact_registry_repository" {
  description = "Name of the Artifact Registry repository"
  value       = google_artifact_registry_repository.main.name
}

output "artifact_registry_location" {
  description = "Location of the Artifact Registry repository"
  value       = google_artifact_registry_repository.main.location
}

output "docker_repository_url" {
  description = "URL of the Docker repository"
  value       = "${google_artifact_registry_repository.main.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}"
}

# CI/CD Service Account Key (sensitive)
output "cicd_service_account_key" {
  description = "Base64 encoded private key for CI/CD service account"
  value       = google_service_account_key.cicd_key.private_key
  sensitive   = true
}

# Secret Manager secret names
output "microservice_1_secret_name" {
  description = "Name of the Secret Manager secret for microservice 1"
  value       = google_secret_manager_secret.microservice_1_sa.secret_id
}

output "microservice_2_secret_name" {
  description = "Name of the Secret Manager secret for microservice 2"
  value       = google_secret_manager_secret.microservice_2_sa.secret_id
}

# Service account keys (sensitive)
output "microservice_1_service_account_key" {
  description = "Base64 encoded private key for microservice 1 service account"
  value       = google_service_account_key.microservice_1_key.private_key
  sensitive   = true
}

output "microservice_2_service_account_key" {
  description = "Base64 encoded private key for microservice 2 service account"
  value       = google_service_account_key.microservice_2_key.private_key
  sensitive   = true
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/iam/main.tf
FILE_CONTENT_START
# Service Account for Microservice 1 (Publisher)
resource "google_service_account" "microservice_1" {
  account_id   = "${var.name_prefix}-microservice-1"
  display_name = "Microservice 1 Service Account"
  description  = "Service account for microservice 1 in ${var.environment} environment"
}

# Service Account for Microservice 2 (Subscriber)
resource "google_service_account" "microservice_2" {
  account_id   = "${var.name_prefix}-microservice-2"
  display_name = "Microservice 2 Service Account"
  description  = "Service account for microservice 2 in ${var.environment} environment"
}

# Service Account for CI/CD
resource "google_service_account" "cicd" {
  account_id   = "${var.name_prefix}-cicd"
  display_name = "CI/CD Service Account"
  description  = "Service account for CI/CD pipeline in ${var.environment} environment"
}

# Workload Identity bindings for microservices
resource "google_service_account_iam_binding" "microservice_1_workload_identity" {
  service_account_id = google_service_account.microservice_1.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/microservice-1]"
  ]
}

resource "google_service_account_iam_binding" "microservice_2_workload_identity" {
  service_account_id = google_service_account.microservice_2.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/microservice-2]"
  ]
}

# Microservice 1 IAM permissions (Publisher role for Pub/Sub)
resource "google_project_iam_member" "microservice_1_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.microservice_1.email}"
}

resource "google_project_iam_member" "microservice_1_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.microservice_1.email}"
}

resource "google_project_iam_member" "microservice_1_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.microservice_1.email}"
}

resource "google_project_iam_member" "microservice_1_trace" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.microservice_1.email}"
}

# Microservice 2 IAM permissions (Subscriber role for Pub/Sub, Firestore access)
resource "google_project_iam_member" "microservice_2_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

resource "google_project_iam_member" "microservice_2_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

resource "google_project_iam_member" "microservice_2_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

resource "google_project_iam_member" "microservice_2_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

resource "google_project_iam_member" "microservice_2_trace" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

# CI/CD IAM permissions
resource "google_project_iam_member" "cicd_gke_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# Create service account keys for CI/CD (not recommended for production)
resource "google_service_account_key" "cicd_key" {
  service_account_id = google_service_account.cicd.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Secret Manager secrets for service accounts
resource "google_secret_manager_secret" "microservice_1_sa" {
  secret_id = "${var.name_prefix}-microservice-1-sa"

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "microservice_1_sa" {
  secret      = google_secret_manager_secret.microservice_1_sa.id
  secret_data = base64decode(google_service_account_key.microservice_1_key.private_key)
}

resource "google_secret_manager_secret" "microservice_2_sa" {
  secret_id = "${var.name_prefix}-microservice-2-sa"

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "microservice_2_sa" {
  secret      = google_secret_manager_secret.microservice_2_sa.id
  secret_data = base64decode(google_service_account_key.microservice_2_key.private_key)
}

# Service account keys for microservices (for local development)
resource "google_service_account_key" "microservice_1_key" {
  service_account_id = google_service_account.microservice_1.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

resource "google_service_account_key" "microservice_2_key" {
  service_account_id = google_service_account.microservice_2.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Custom IAM roles for fine-grained permissions
resource "google_project_iam_custom_role" "microservice_minimal" {
  role_id     = "${replace(var.name_prefix, "-", "_")}_microservice_minimal"
  title       = "Microservice Minimal Permissions"
  description = "Minimal permissions required for microservices"

  permissions = [
    "logging.logEntries.create",
    "monitoring.timeSeries.create",
    "cloudtrace.traces.patch"
  ]

  stage = "GA"
}

# Bind custom role to service accounts
resource "google_project_iam_member" "microservice_1_custom" {
  project = var.project_id
  role    = google_project_iam_custom_role.microservice_minimal.id
  member  = "serviceAccount:${google_service_account.microservice_1.email}"
}

resource "google_project_iam_member" "microservice_2_custom" {
  project = var.project_id
  role    = google_project_iam_custom_role.microservice_minimal.id
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

# Enable required APIs
resource "google_project_service" "iam" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# Artifact Registry repository for Docker images
resource "google_artifact_registry_repository" "main" {
  location      = var.region
  repository_id = "${var.name_prefix}-docker-repo"
  description   = "Docker repository for ${var.environment} environment"
  format        = "DOCKER"

  labels = var.labels

  depends_on = [google_project_service.artifactregistry]
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/iam/variables.tf
FILE_CONTENT_START
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
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/gke/outputs.tf
FILE_CONTENT_START
output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_id" {
  description = "The ID of the GKE cluster"
  value       = google_container_cluster.primary.id
}

output "endpoint" {
  description = "The endpoint of the GKE cluster"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "ca_certificate" {
  description = "The CA certificate of the GKE cluster"
  value       = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
  sensitive   = true
}

output "location" {
  description = "The location of the GKE cluster"
  value       = google_container_cluster.primary.location
}

output "master_version" {
  description = "The current master version of the GKE cluster"
  value       = google_container_cluster.primary.master_version
}

output "node_version" {
  description = "The current node version of the GKE cluster"
  value       = google_container_cluster.primary.node_version
}

output "node_pool_name" {
  description = "The name of the primary node pool"
  value       = google_container_node_pool.primary.name
}

output "node_service_account" {
  description = "The service account used by GKE nodes"
  value       = google_service_account.gke_nodes.email
}

output "cluster_resource_labels" {
  description = "The resource labels applied to the cluster"
  value       = google_container_cluster.primary.resource_labels
}

# Connection information for kubectl
output "kubectl_config" {
  description = "kubectl configuration command"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location} --project ${var.project_id}"
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/gke/main.tf
FILE_CONTENT_START
# Enable required APIs
resource "google_project_service" "container" {
  project            = var.project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# Service account for GKE nodes
resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-gke-nodes"
  display_name = "GKE Nodes Service Account"
}

# Minimal IAM roles for the service account
resource "google_project_iam_member" "gke_nodes_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# GKE Cluster - Private configuration
resource "google_container_cluster" "primary" {
  project  = var.project_id
  name     = "${var.name_prefix}-cluster"
  location = var.region

  # We can't create a cluster with 0 nodes, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Basic network config
  network    = var.network_name
  subnetwork = var.subnet_name

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Set to true for full private, false allows public API access
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # IP allocation policy - REQUIRED for private clusters
  ip_allocation_policy {
    cluster_secondary_range_name  = "${var.name_prefix}-pods"
    services_secondary_range_name = "${var.name_prefix}-services"
  }

  # Master authorized networks - who can access the Kubernetes API
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0" # WARNING: Open to all. Restrict in production!
      display_name = "All networks"
    }
  }

  # Basic addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  # Workload Identity for secure pod-to-GCP service communication
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  depends_on = [
    google_project_service.container,
    google_project_service.compute,
  ]
}

# Node Pool - Private nodes configuration
resource "google_container_node_pool" "primary" {
  project    = var.project_id
  name       = "${var.name_prefix}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.min_node_count

  node_config {
    preemptible     = var.preemptible_nodes
    machine_type    = var.node_machine_type
    disk_size_gb    = var.node_disk_size_gb
    disk_type       = var.node_disk_type
    service_account = google_service_account.gke_nodes.email

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = var.labels
    tags   = ["gke-node", "${var.name_prefix}-gke-node"]

    # Shielded instance for added security
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/gke/variables.tf
FILE_CONTENT_START
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

# Network Configuration
variable "network_name" {
  description = "The name of the VPC network"
  type        = string
}

variable "subnet_name" {
  description = "The name of the subnet"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "The IP range for the GKE master nodes"
  type        = string
  default     = "172.16.0.0/28"
}

# Cluster Configuration
variable "release_channel" {
  description = "The release channel for GKE cluster"
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "Release channel must be one of: RAPID, REGULAR, STABLE."
  }
}

# Node Pool Configuration
variable "min_node_count" {
  description = "Minimum number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes in the node pool"
  type        = number
  default     = 5
}

variable "node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "node_disk_size_gb" {
  description = "Disk size for GKE nodes in GB"
  type        = number
  default     = 50
}

variable "node_disk_type" {
  description = "Disk type for GKE nodes"
  type        = string
  default     = "pd-standard"

  validation {
    condition     = contains(["pd-standard", "pd-ssd", "pd-balanced"], var.node_disk_type)
    error_message = "Disk type must be one of: pd-standard, pd-ssd, pd-balanced."
  }
}

variable "preemptible_nodes" {
  description = "Whether to use preemptible nodes"
  type        = bool
  default     = false
}

variable "node_taints" {
  description = "List of node taints to apply"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/pubsub/outputs.tf
FILE_CONTENT_START
output "topic_name" {
  description = "The name of the Pub/Sub topic"
  value       = google_pubsub_topic.main.name
}

output "topic_id" {
  description = "The ID of the Pub/Sub topic"
  value       = google_pubsub_topic.main.id
}

output "subscription_name" {
  description = "The name of the Pub/Sub subscription"
  value       = google_pubsub_subscription.microservice_2.name
}

output "subscription_id" {
  description = "The ID of the Pub/Sub subscription"
  value       = google_pubsub_subscription.microservice_2.id
}

output "dead_letter_topic_name" {
  description = "The name of the dead letter topic (if enabled)"
  value       = var.enable_dead_letter_queue ? google_pubsub_topic.dead_letter[0].name : ""
}

output "dead_letter_subscription_name" {
  description = "The name of the dead letter subscription (if enabled)"
  value       = var.enable_dead_letter_queue ? google_pubsub_subscription.dead_letter[0].name : ""
}

output "schema_name" {
  description = "The name of the Pub/Sub schema (if created)"
  value       = var.create_schema ? google_pubsub_schema.main[0].name : ""
}

# Connection strings for applications
output "topic_connection_string" {
  description = "Connection string for publishing to the topic"
  value       = "projects/${var.project_id}/topics/${google_pubsub_topic.main.name}"
}

output "subscription_connection_string" {
  description = "Connection string for subscribing to the subscription"
  value       = "projects/${var.project_id}/subscriptions/${google_pubsub_subscription.microservice_2.name}"
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/pubsub/main.tf
FILE_CONTENT_START
# terraform/modules/pubsub/main.tf

# Enable required APIs
resource "google_project_service" "pubsub" {
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

# Pub/Sub Topic for microservices communication
resource "google_pubsub_topic" "main" {
  name = "${var.name_prefix}-items-topic"

  labels = var.labels

  # Message retention duration
  message_retention_duration = var.message_retention_duration

  # Message storage policy
  message_storage_policy {
    allowed_persistence_regions = var.allowed_persistence_regions
  }

  # Schema settings (if schema is provided)
  dynamic "schema_settings" {
    for_each = var.schema_name != "" ? [1] : []
    content {
      schema   = var.schema_name
      encoding = var.schema_encoding
    }
  }

  depends_on = [google_project_service.pubsub]
}

# Pub/Sub Subscription for Microservice 2
resource "google_pubsub_subscription" "microservice_2" {
  name  = "${var.name_prefix}-items-subscription"
  topic = google_pubsub_topic.main.name

  labels = var.labels

  # Acknowledgment deadline
  ack_deadline_seconds = var.ack_deadline_seconds

  # Message retention duration
  message_retention_duration = var.message_retention_duration

  # Retain acknowledged messages
  retain_acked_messages = var.retain_acked_messages

  # Expiration policy
  expiration_policy {
    ttl = var.subscription_ttl
  }

  # Retry policy
  retry_policy {
    minimum_backoff = var.retry_minimum_backoff
    maximum_backoff = var.retry_maximum_backoff
  }

  # Dead letter policy
  dynamic "dead_letter_policy" {
    for_each = var.enable_dead_letter_queue ? [1] : []
    content {
      dead_letter_topic     = google_pubsub_topic.dead_letter[0].id
      max_delivery_attempts = var.max_delivery_attempts
    }
  }

  # Push configuration for HTTP endpoint (if provided)
  dynamic "push_config" {
    for_each = var.push_endpoint != "" ? [1] : []
    content {
      push_endpoint = var.push_endpoint

      attributes = var.push_attributes

      # OIDC token for authentication
      dynamic "oidc_token" {
        for_each = var.oidc_service_account_email != "" ? [1] : []
        content {
          service_account_email = var.oidc_service_account_email
          audience              = var.oidc_audience
        }
      }
    }
  }

  # Enable message ordering
  enable_message_ordering = var.enable_message_ordering

  # Filter for subscription
  filter = var.subscription_filter
}

# Dead Letter Topic (if enabled)
resource "google_pubsub_topic" "dead_letter" {
  count = var.enable_dead_letter_queue ? 1 : 0

  name = "${var.name_prefix}-items-dead-letter-topic"

  labels = merge(var.labels, {
    purpose = "dead-letter"
  })

  message_retention_duration = "604800s" # 7 days

  depends_on = [google_project_service.pubsub]
}

# Dead Letter Subscription (if enabled)
resource "google_pubsub_subscription" "dead_letter" {
  count = var.enable_dead_letter_queue ? 1 : 0

  name  = "${var.name_prefix}-items-dead-letter-subscription"
  topic = google_pubsub_topic.dead_letter[0].name

  labels = merge(var.labels, {
    purpose = "dead-letter"
  })

  ack_deadline_seconds       = 600
  message_retention_duration = "604800s" # 7 days
  retain_acked_messages      = true

  expiration_policy {
    ttl = "2678400s" # 31 days
  }
}

# Pub/Sub Schema (if schema validation is needed)
resource "google_pubsub_schema" "main" {
  count = var.create_schema ? 1 : 0

  name = "${var.name_prefix}-items-schema"
  type = var.schema_type

  definition = var.schema_definition
}

# IAM bindings for service accounts
resource "google_pubsub_topic_iam_member" "publisher" {
  for_each = toset(var.publisher_service_accounts)

  topic  = google_pubsub_topic.main.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${each.value}"
}

resource "google_pubsub_subscription_iam_member" "subscriber" {
  for_each = toset(var.subscriber_service_accounts)

  subscription = google_pubsub_subscription.microservice_2.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${each.value}"
}

# # Monitoring: Topic metrics
# resource "google_monitoring_alert_policy" "topic_undelivered_messages" {
#   count        = var.enable_monitoring ? 1 : 0
#   display_name = "${var.name_prefix} Pub/Sub Topic Undelivered Messages"

#   documentation {
#     content = "Alert when there are too many undelivered messages in the Pub/Sub topic"
#   }

#   conditions {
#     display_name = "Undelivered messages condition"

#     condition_threshold {
#       filter = "resource.type=\"pubsub_topic\" AND resource.labels.topic_id=\"${google_pubsub_topic.main.name}\" AND metric.type=\"pubsub.googleapis.com/topic/num_undelivered_messages\""
#       duration        = "300s"
#       comparison      = "COMPARISON_GT"
#       threshold_value = var.undelivered_messages_threshold

#       aggregations {
#         alignment_period   = "300s"
#         per_series_aligner = "ALIGN_MEAN"
#       }
#     }
#   }

#   alert_strategy {
#     auto_close = "1800s"
#   }

#   combiner              = "OR"
#   enabled               = true
#   notification_channels = var.notification_channels
# }

# # Monitoring: Subscription age metrics
# resource "google_monitoring_alert_policy" "subscription_oldest_unacked_message" {
#   count        = var.enable_monitoring ? 1 : 0
#   display_name = "${var.name_prefix} Pub/Sub Subscription Oldest Unacked Message"

#   documentation {
#     content = "Alert when messages in subscription are too old"
#   }

#   conditions {
#     display_name = "Oldest unacked message age condition"

#     condition_threshold {
#       filter = "resource.type=\"pubsub_subscription\" AND resource.labels.subscription_id=\"${google_pubsub_subscription.microservice_2.name}\" AND metric.type=\"pubsub.googleapis.com/subscription/oldest_unacked_message_age\""
#       duration        = "300s"
#       comparison      = "COMPARISON_GT"
#       threshold_value = var.oldest_unacked_message_threshold

#       aggregations {
#         alignment_period   = "300s"
#         per_series_aligner = "ALIGN_MAX"
#       }
#     }
#   }

#   alert_strategy {
#     auto_close = "1800s"
#   }

#   combiner              = "OR"
#   enabled               = true
#   notification_channels = var.notification_channels
# }
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/pubsub/variables.tf
FILE_CONTENT_START
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
  default     = "604800s" # 7 days
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
  default     = "2678400s" # 31 days
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
  default     = 600 # 10 minutes
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/vpc/outputs.tf
FILE_CONTENT_START
# terraform/modules/vpc/outputs.tf

output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.main.name
}

output "network_self_link" {
  description = "The self-link of the VPC network"
  value       = google_compute_network.main.self_link
}

output "network_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.main.id
}

output "private_subnet_name" {
  description = "The name of the private subnet"
  value       = google_compute_subnetwork.private.name
}

output "private_subnet_self_link" {
  description = "The self-link of the private subnet"
  value       = google_compute_subnetwork.private.self_link
}

output "private_subnet_cidr" {
  description = "The CIDR block of the private subnet"
  value       = google_compute_subnetwork.private.ip_cidr_range
}

output "public_subnet_name" {
  description = "The name of the public subnet"
  value       = google_compute_subnetwork.public.name
}

output "public_subnet_self_link" {
  description = "The self-link of the public subnet"
  value       = google_compute_subnetwork.public.self_link
}

output "public_subnet_cidr" {
  description = "The CIDR block of the public subnet"
  value       = google_compute_subnetwork.public.ip_cidr_range
}

output "pods_cidr_range" {
  description = "The CIDR range for GKE pods"
  value       = var.pods_cidr_range
}

output "services_cidr_range" {
  description = "The CIDR range for GKE services"
  value       = var.services_cidr_range
}

output "gke_master_cidr" {
  description = "The CIDR range for GKE master nodes"
  value       = var.gke_master_cidr
}

output "router_name" {
  description = "The name of the Cloud Router"
  value       = google_compute_router.main.name
}

output "nat_name" {
  description = "The name of the NAT gateway"
  value       = google_compute_router_nat.main.name
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/vpc/main.tf
FILE_CONTENT_START
# VPC Network
resource "google_compute_network" "main" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  description             = "VPC network for ${var.environment} environment"

  depends_on = [
    google_project_service.compute,
    google_project_service.container
  ]
}

# Private Subnet for GKE and internal resources
resource "google_compute_subnetwork" "private" {
  name          = "${var.name_prefix}-private-subnet"
  ip_cidr_range = var.private_subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id
  description   = "Private subnet for GKE cluster and internal services"

  # Enable private Google access for GKE nodes
  private_ip_google_access = true

  # Secondary IP ranges for GKE
  secondary_ip_range {
    range_name    = "${var.name_prefix}-pods"
    ip_cidr_range = var.pods_cidr_range
  }

  secondary_ip_range {
    range_name    = "${var.name_prefix}-services"
    ip_cidr_range = var.services_cidr_range
  }
}

# Public Subnet for Load Balancer and NAT Gateway
resource "google_compute_subnetwork" "public" {
  name          = "${var.name_prefix}-public-subnet"
  ip_cidr_range = var.public_subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id
  description   = "Public subnet for load balancers and NAT gateway"
}

# Cloud Router for NAT Gateway
resource "google_compute_router" "main" {
  name    = "${var.name_prefix}-router"
  region  = var.region
  network = google_compute_network.main.id

  description = "Cloud Router for NAT gateway"
}

# NAT Gateway for private subnet internet access
resource "google_compute_router_nat" "main" {
  name                               = "${var.name_prefix}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall Rules
# Allow internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.name_prefix}-allow-internal"
  network = google_compute_network.main.name

  description = "Allow internal communication between subnets"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.private_subnet_cidr,
    var.public_subnet_cidr,
    var.pods_cidr_range,
    var.services_cidr_range
  ]
}

# Allow HTTP/HTTPS from internet to load balancer
resource "google_compute_firewall" "allow_http_https" {
  name    = "${var.name_prefix}-allow-http-https"
  network = google_compute_network.main.name

  description = "Allow HTTP and HTTPS traffic from internet"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
}

# Allow SSH for debugging (restricted to specific source ranges in production)
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.name_prefix}-allow-ssh"
  network = google_compute_network.main.name

  description = "Allow SSH access for debugging"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = ["ssh-server"]
}

# Allow GKE master to nodes communication
resource "google_compute_firewall" "allow_gke_master" {
  name    = "${var.name_prefix}-allow-gke-master"
  network = google_compute_network.main.name

  description = "Allow GKE master to communicate with nodes"

  allow {
    protocol = "tcp"
    ports    = ["443", "10250"]
  }

  source_ranges = [var.gke_master_cidr]
  target_tags   = ["gke-node"]
}

# Enable required APIs
resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/vpc/variables.tf
FILE_CONTENT_START
# terraform/modules/vpc/variables.tf

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

# Network CIDR Configuration
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

# Security Configuration
variable "ssh_source_ranges" {
  description = "Source IP ranges allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/monitoring/outputs.tf
FILE_CONTENT_START
output "notification_channel_id" {
  description = "ID of the email notification channel"
  value       = google_monitoring_notification_channel.email.name
}

output "notification_channel_name" {
  description = "Name of the email notification channel"
  value       = google_monitoring_notification_channel.email.display_name
}

output "dashboard_url" {
  description = "URL to access the monitoring dashboard"
  value       = "https://console.cloud.google.com/monitoring/dashboards/custom/${basename(google_monitoring_dashboard.main.id)}?project=${var.project_id}"
}

# output "alert_policies" {
#   description = "List of created alert policy names"
#   value = [
#     google_monitoring_alert_policy.gke_cpu_usage.display_name,
#     google_monitoring_alert_policy.gke_memory_usage.display_name,
#     google_monitoring_alert_policy.gke_node_not_ready.display_name,
#     google_monitoring_alert_policy.http_error_rate.display_name,
#     google_monitoring_alert_policy.http_latency.display_name,
#     google_monitoring_alert_policy.low_request_volume.display_name,
#     google_monitoring_alert_policy.error_logs.display_name
#   ]
# }

output "log_metric_name" {
  description = "Name of the error count log metric"
  value       = google_logging_metric.error_count.name
}

output "dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = google_monitoring_dashboard.main.id
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/monitoring/main.tf
FILE_CONTENT_START
# Enable required APIs
resource "google_project_service" "monitoring" {
  service            = "monitoring.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "logging" {
  service            = "logging.googleapis.com"
  disable_on_destroy = false
}

# Notification channel for alerts
resource "google_monitoring_notification_channel" "email" {
  display_name = "${var.name_prefix} Email Notification Channel"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }

  enabled = true
}

# Infrastructure Monitoring Alerts

# GKE Cluster CPU Usage Alert
resource "google_monitoring_alert_policy" "gke_cpu_usage" {
  display_name = "${var.name_prefix} GKE CPU Usage High"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Alert when GKE cluster CPU usage is consistently high"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "GKE CPU usage > 80%"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.namespace_name", "resource.labels.pod_name"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# GKE Cluster Memory Usage Alert
resource "google_monitoring_alert_policy" "gke_memory_usage" {
  display_name = "${var.name_prefix} GKE Memory Usage High"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Alert when GKE cluster memory usage is consistently high"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "GKE Memory usage > 85%"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\" AND metric.type=\"kubernetes.io/container/memory/used_bytes\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 435159040 # ~415MB (85% of 512MB)

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.namespace_name", "resource.labels.pod_name"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# GKE Pod Restart Alert
resource "google_monitoring_alert_policy" "gke_pod_restarts" {
  display_name = "${var.name_prefix} GKE Pod Restart Alert"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Alert when GKE pods are restarting frequently"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Pod restart rate is high"

    condition_threshold {
      filter          = "resource.type=\"k8s_pod\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\" AND metric.type=\"kubernetes.io/pod/restart_count\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.pod_name"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# Application Monitoring Alerts

# HTTP Error Rate Alert (placeholder - will work when service mesh is enabled)
resource "google_monitoring_alert_policy" "http_error_rate" {
  display_name = "${var.name_prefix} HTTP Error Rate High"
  combiner     = "OR"
  enabled      = false # Disabled until service mesh metrics are available

  documentation {
    content   = "Alert when HTTP error rate is high (requires service mesh)"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "HTTP 5xx error rate > 5%"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.05

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# HTTP Latency Alert (placeholder - will work when service mesh is enabled)
resource "google_monitoring_alert_policy" "http_latency" {
  display_name = "${var.name_prefix} HTTP Latency High"
  combiner     = "OR"
  enabled      = false # Disabled until service mesh metrics are available

  documentation {
    content   = "Alert when HTTP latency is consistently high (requires service mesh)"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "HTTP latency > 2s"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 2000

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# Business Metrics Alert - Low Pod Count
resource "google_monitoring_alert_policy" "low_pod_count" {
  display_name = "${var.name_prefix} Low Pod Count"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Alert when pod count is too low"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Pod count < 2"

    condition_threshold {
      filter          = "resource.type=\"k8s_pod\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\" AND metric.type=\"kubernetes.io/pod/uptime\""
      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = 2

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_COUNT"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# Error Log Count Metric
resource "google_logging_metric" "error_count" {
  name   = "${var.name_prefix}_error_count"
  filter = "resource.type=\"k8s_container\" AND severity>=ERROR AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""

  metric_descriptor {
    metric_kind  = "DELTA"
    value_type   = "INT64"
    display_name = "Error Log Count"

    labels {
      key         = "severity"
      value_type  = "STRING"
      description = "Severity of the log entry"
    }

    labels {
      key         = "service_name"
      value_type  = "STRING"
      description = "Name of the service"
    }
  }

  label_extractors = {
    "severity"     = "EXTRACT(severity)"
    "service_name" = "EXTRACT(resource.labels.container_name)"
  }
}

# Log-based Alert for Errors
resource "google_monitoring_alert_policy" "error_logs" {
  display_name = "${var.name_prefix} High Error Log Count"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Alert when error log count is high"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Error log count > 10/minute"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.error_count.name}\" AND resource.type=\"k8s_container\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 10

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# Dashboard
resource "google_monitoring_dashboard" "main" {
  dashboard_json = jsonencode({
    displayName = "${var.name_prefix} Platform Dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "GKE CPU Usage"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields      = ["resource.labels.namespace_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "CPU cores"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          xPos   = 6
          width  = 6
          height = 4
          widget = {
            title = "Memory Usage"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/memory/used_bytes\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields      = ["resource.labels.namespace_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Memory (bytes)"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          yPos   = 4
          width  = 12
          height = 4
          widget = {
            title = "Pod Restart Count"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_pod\" AND metric.type=\"kubernetes.io/pod/restart_count\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["resource.labels.pod_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Restarts/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          yPos   = 8
          width  = 6
          height = 4
          widget = {
            title = "Error Log Rate"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.error_count.name}\" AND resource.type=\"k8s_container\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.labels.service_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Errors/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          xPos   = 6
          yPos   = 8
          width  = 6
          height = 4
          widget = {
            title = "Pod Count"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_pod\" AND metric.type=\"kubernetes.io/pod/uptime\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_COUNT"
                        groupByFields      = ["resource.labels.namespace_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Pod Count"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/monitoring/variables.tf
FILE_CONTENT_START
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
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./LICENSE
FILE_CONTENT_START
MIT License

Copyright (c) 2025 gavilanbe

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./Makefile
FILE_CONTENT_START
# DogfyDiet Platform Makefile

.PHONY: help bootstrap init plan apply destroy clean lint validate

# Default target
help:
	@echo "DogfyDiet Platform - Available Commands:"
	@echo "  make bootstrap    - Run initial setup (create state bucket, service accounts)"
	@echo "  make init        - Initialize Terraform"
	@echo "  make plan        - Run Terraform plan"
	@echo "  make apply       - Apply Terraform changes"
	@echo "  make destroy     - Destroy all infrastructure (careful!)"
	@echo "  make clean       - Clean local files"
	@echo "  make lint        - Lint Terraform files"
	@echo "  make validate    - Validate Terraform configuration"

# Run bootstrap setup
bootstrap:
	@echo "Running bootstrap setup..."
	@chmod +x scripts/bootstrap.sh
	@./scripts/bootstrap.sh

# Initialize Terraform
init:
	@echo "Initializing Terraform..."
	@cd terraform/environments/dev && terraform init

# Run Terraform plan
plan:
	@echo "Running Terraform plan..."
	@cd terraform/environments/dev && terraform plan

# Apply Terraform changes
apply:
	@echo "Applying Terraform changes..."
	@cd terraform/environments/dev && terraform apply

# Destroy infrastructure
destroy:
	@echo "WARNING: This will destroy all infrastructure!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && \
	if [ "$$confirm" = "yes" ]; then \
		cd terraform/environments/dev && terraform destroy; \
	else \
		echo "Destroy cancelled."; \
	fi

# Clean local files
clean:
	@echo "Cleaning local files..."
	@rm -f sa-key.json sa-key-encoded.txt
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.tfplan" -exec rm -f {} + 2>/dev/null || true
	@find . -type f -name "*.tfstate*" -exec rm -f {} + 2>/dev/null || true
	@echo "Clean complete!"

# Lint Terraform files
lint:
	@echo "Linting Terraform files..."
	@terraform fmt -recursive terraform/

# Validate Terraform configuration
validate:
	@echo "Validating Terraform configuration..."
	@cd terraform/environments/dev && terraform validate

# Quick setup (bootstrap + init + plan)
quickstart: bootstrap init plan
	@echo "Quickstart complete! Review the plan and run 'make apply' when ready."
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-2/Chart.yaml
FILE_CONTENT_START
apiVersion: v2
name: microservice-2
description: DogfyDiet Microservice 2 - Subscriber and Data Processor
type: application
version: 1.0.0
appVersion: "1.0.0"
home: https://github.com/your-username/dogfydiet-platform
sources:
  - https://github.com/your-username/dogfydiet-platform
maintainers:
  - name: DogfyDiet Platform Team
    email: team@dogfydiet.com
keywords:
  - microservice
  - subscriber
  - firestore
  - pubsub
  - dogfydiet
annotations:
  category: Application
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-2/values.yaml
FILE_CONTENT_START
replicaCount: 2

image:
  repository: us-central1-docker.pkg.dev/nahuelgabe-test/dogfydiet-dev-docker-repo/microservice-2
  pullPolicy: IfNotPresent
  tag: "latest"

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations:
    iam.gke.io/gcp-service-account: dogfydiet-dev-microservice-2@nahuelgabe-test.iam.gserviceaccount.com
  name: "microservice-2"

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "3001"
  prometheus.io/path: "/metrics"

podSecurityContext:
  fsGroup: 1001
  runAsNonRoot: true
  runAsUser: 1001

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1001

service:
  type: ClusterIP
  port: 80
  targetPort: 3001
  protocol: TCP

ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: processor.dogfydiet.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 8
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - microservice-2
        topologyKey: kubernetes.io/hostname

# Environment variables
env:
  GOOGLE_CLOUD_PROJECT: "nahuelgabe-test"
  PUBSUB_SUBSCRIPTION: "dogfydiet-dev-items-subscription"
  FIRESTORE_COLLECTION: "items"
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  RATE_LIMIT: "100"
  CORS_ORIGIN: "https://*.dogfydiet.com,http://localhost:8080"

# Probes configuration
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

# PodDisruptionBudget
podDisruptionBudget:
  enabled: true
  minAvailable: 1

# NetworkPolicy
networkPolicy:
  enabled: true
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: istio-system
      - namespaceSelector:
          matchLabels:
            name: default
      ports:
      - protocol: TCP
        port: 3001
  egress:
    - to: []
      ports:
      - protocol: TCP
        port: 443  # HTTPS to Google APIs
      - protocol: TCP
        port: 53   # DNS
      - protocol: UDP
        port: 53   # DNS
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-1/Chart.yaml
FILE_CONTENT_START
apiVersion: v2
name: microservice-1
description: DogfyDiet Microservice 1 - API Gateway and Publisher
type: application
version: 1.0.0
appVersion: "1.0.0"
home: https://github.com/gavilanbe/dogfydiet-platform
sources:
  - https://github.com/gavilanbe/dogfydiet-platform
maintainers:
  - name: DogfyDiet Platform Team
    email: nahuel@gavilanbe.io
keywords:
  - microservice
  - api
  - pubsub
  - dogfydiet
annotations:
  category: Application
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-1/templates/deployment.yaml
FILE_CONTENT_START
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "microservice-1.fullname" . }}
  labels:
    {{- include "microservice-1.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "microservice-1.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "microservice-1.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "microservice-1.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.image.containerPort | default 3000 }}
              protocol: TCP
          env:
            {{- range $key, $value := .Values.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
          livenessProbe:
            {{- toYaml .Values.livenessProbe | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe | nindent 12 }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          volumeMounts:
            - name: tmp-volume
              mountPath: /tmp
              readOnly: false
      volumes:
        - name: tmp-volume
          emptyDir: {}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-1/templates/backendconfig.yaml
FILE_CONTENT_START
{{- if .Values.backendConfig.enabled }}
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: {{ include "microservice-1.fullname" . }}-backendconfig
  labels:
    {{- include "microservice-1.labels" . | nindent 4 }}
spec:
  healthCheck:
    checkIntervalSec: {{ .Values.backendConfig.healthCheck.checkIntervalSec | default 15 }}
    timeoutSec: {{ .Values.backendConfig.healthCheck.timeoutSec | default 5 }}
    healthyThreshold: {{ .Values.backendConfig.healthCheck.healthyThreshold | default 2 }}
    unhealthyThreshold: {{ .Values.backendConfig.healthCheck.unhealthyThreshold | default 2 }}
    type: HTTP
    port: {{ .Values.image.containerPort | default 3000 }} # Port your container listens on
    requestPath: {{ .Values.backendConfig.healthCheck.requestPath | default "/health" }}
{{- end }}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-1/templates/service.yaml
FILE_CONTENT_START
apiVersion: v1
kind: Service
metadata:
  name: {{ include "microservice-1.fullname" . }}
  annotations:
    cloud.google.com/neg: '{"exposed_ports": {"80":{}}}'
    {{- if .Values.backendConfig.enabled }}
    cloud.google.com/backend-config: '{"ports": {"http":"{{ include "microservice-1.fullname" . }}-backendconfig"}}'
    {{- end }}
  labels:
    {{- include "microservice-1.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}

      targetPort: http # This should match the name of the port in your deployment's container spec
      protocol: {{ .Values.service.protocol }}
      name: http
  selector:
    {{- include "microservice-1.selectorLabels" . | nindent 4 }}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-1/templates/hpa.yaml
FILE_CONTENT_START
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "microservice-1.fullname" . }}
  labels:
    {{- include "microservice-1.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "microservice-1.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-1/templates/serviceaccount.yaml
FILE_CONTENT_START
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "microservice-1.serviceAccountName" . }}
  labels:
    {{- include "microservice-1.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-1/templates/_helpers.tpl
FILE_CONTENT_START
{{/*
Expand the name of the chart.
*/}}
{{- define "microservice-1.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "microservice-1.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "microservice-1.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "microservice-1.labels" -}}
helm.sh/chart: {{ include "microservice-1.chart" . }}
{{ include "microservice-1.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: api-gateway
app.kubernetes.io/part-of: dogfydiet-platform
{{- end }}

{{/*
Selector labels
*/}}
{{- define "microservice-1.selectorLabels" -}}
app.kubernetes.io/name: {{ include "microservice-1.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "microservice-1.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "microservice-1.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-1/values.yaml
FILE_CONTENT_START
replicaCount: 2

image:
  repository: us-central1-docker.pkg.dev/nahuelgabe-test/dogfydiet-dev-docker-repo/microservice-1
  pullPolicy: IfNotPresent
  tag: "latest"
  containerPort: 3000

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations:
    iam.gke.io/gcp-service-account: dogfydiet-dev-microservice-1@nahuelgabe-test.iam.gserviceaccount.com
  name: "microservice-1"

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "3000"
  prometheus.io/path: "/metrics"

podSecurityContext:
  fsGroup: 1001
  runAsNonRoot: true
  runAsUser: 1001

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1001

service:
  type: ClusterIP
  port: 80
  #targetPort: 3000
  protocol: TCP
  targetPort: http # Referencing the named port of the container
  protocol: TCP


backendConfig:
  enabled: true
  healthCheck:
    requestPath: "/health"
    checkIntervalSec: 15
    timeoutSec: 5
    healthyThreshold: 2
    unhealthyThreshold: 2
    

# ingress:
#   enabled: false
#   className: ""
#   annotations: {}
#   hosts:
#     - host: 
#       paths:
#         - path: /
#           pathType: Prefix
#   tls: []

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - microservice-1
        topologyKey: kubernetes.io/hostname

# Environment variables
env:
  GOOGLE_CLOUD_PROJECT: "nahuelgabe-test"
  PUBSUB_TOPIC: "dogfydiet-dev-items-topic"
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  RATE_LIMIT: "100"
  CORS_ORIGIN: "https://nahueldog.duckdns.org,http://localhost:8080" # Add your frontend origin

# Probes configuration
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

# PodDisruptionBudget
podDisruptionBudget:
  enabled: true
  minAvailable: 1

# NetworkPolicy
networkPolicy:
  enabled: true
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: istio-system
      - namespaceSelector:
          matchLabels:
            name: default
      ports:
      - protocol: TCP
        port: 3000
  egress:
    - to: []
      ports:
      - protocol: TCP
        port: 443  # HTTPS to Google APIs
      - protocol: TCP
        port: 53   # DNS
      - protocol: UDP
        port: 53   # DNS
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./README.md
FILE_CONTENT_START
# DogfyDiet Platform

A cloud-native full-stack application deployed on Google Cloud Platform, demonstrating microservices architecture, Infrastructure as Code, and modern DevOps practices.

## 🏗️ Architecture Overview

This solution implements a microservices-based architecture with:
- **Frontend**: Vue.js 3 SPA hosted on Google Cloud Storage with CDN
- **Backend**: Two Node.js microservices deployed on Google Kubernetes Engine
- **Messaging**: Event-driven communication via Google Pub/Sub
- **Database**: Google Firestore for NoSQL data storage
- **Infrastructure**: Managed via Terraform with comprehensive monitoring

## 🚀 Technology Stack

### Infrastructure & Cloud
- **Google Cloud Platform** - Cloud provider
- **Terraform** - Infrastructure as Code
- **Google Kubernetes Engine (GKE)** - Container orchestration
- **Google Cloud Storage** - Static website hosting with CDN
- **Google Cloud Load Balancer** - Traffic distribution and SSL termination
- **Google Pub/Sub** - Event messaging system
- **Google Firestore** - NoSQL document database
- **Google Cloud Monitoring** - Observability and alerting

### Applications  
- **Vue.js 3** - Frontend framework with Composition API
- **Node.js + Express.js** - Backend microservices
- **Docker** - Multi-stage containerization
- **Helm** - Kubernetes package management

### DevOps & Security
- **GitHub Actions** - CI/CD pipeline
- **Google Artifact Registry** - Container registry
- **Google Secret Manager** - Secret management
- **Workload Identity** - Secure GKE-to-GCP authentication
- **Network Policies** - Kubernetes microsegmentation

## 📋 Prerequisites

- Google Cloud Platform account with billing enabled
- `gcloud` CLI installed and configured
- `terraform` >= 1.5.0
- `kubectl` configured for GKE
- `helm` >= 3.12.0
- Node.js >= 18.0.0 (for local development)
- Docker (for building images)

## 🔧 Quick Start

### 1. Infrastructure Deployment

```bash
# Clone the repository
git clone https://github.com/your-username/dogfydiet-platform.git
cd dogfydiet-platform

# Set up Terraform backend (create GCS bucket first)
gsutil mb gs://your-project-terraform-state

# Initialize and deploy infrastructure
cd terraform/environments/dev
terraform init
terraform plan
terraform apply

# Get GKE credentials
gcloud container clusters get-credentials dogfydiet-dev-gke-cluster --region us-central1
```

### 2. Application Deployment

```bash
# Build and push Docker images
docker build -t us-central1-docker.pkg.dev/your-project/dogfydiet-dev-docker-repo/microservice-1:latest applications/microservice-1/
docker push us-central1-docker.pkg.dev/your-project/dogfydiet-dev-docker-repo/microservice-1:latest

docker build -t us-central1-docker.pkg.dev/your-project/dogfydiet-dev-docker-repo/microservice-2:latest applications/microservice-2/
docker push us-central1-docker.pkg.dev/your-project/dogfydiet-dev-docker-repo/microservice-2:latest

# Deploy microservices using Helm
cd k8s/helm-charts/microservice-1
helm install microservice-1 . --set image.tag=latest

cd ../microservice-2
helm install microservice-2 . --set image.tag=latest

# Deploy frontend to Cloud Storage
cd applications/frontend
npm install
npm run build
gsutil -m rsync -r -d dist/ gs://your-frontend-bucket/
```

### 3. Configure CI/CD

Set up GitHub repository secrets:
- `GCP_SA_KEY`: Base64 encoded service account key
- `NOTIFICATION_EMAIL`: Email for monitoring alerts
- `FRONTEND_BUCKET_NAME`: Cloud Storage bucket name
- `API_URL`: Backend API URL

## 🏛️ Project Structure

```
dogfydiet-platform/
├── README.md                     # This file
├── .github/workflows/           # GitHub Actions CI/CD pipelines
├── terraform/                   # Infrastructure as Code
│   ├── environments/dev/        # Development environment
│   └── modules/                 # Reusable Terraform modules
├── applications/                # Application source code
│   ├── frontend/               # Vue.js frontend application
│   ├── microservice-1/         # API Gateway & Publisher
│   └── microservice-2/         # Subscriber & Data Processor
├── k8s/                        # Kubernetes manifests and Helm charts
│   └── helm-charts/            # Helm charts for microservices
├── docs/                       # Architecture and technical documentation
└── scripts/                    # Utility scripts
```

## 🔄 Application Flow

1. **User Interaction**: User adds items through Vue.js frontend
2. **API Request**: Frontend sends HTTP POST to Microservice 1
3. **Validation**: Microservice 1 validates input and processes request
4. **Event Publishing**: Microservice 1 publishes event to Pub/Sub topic
5. **Event Processing**: Microservice 2 subscribes and processes the event
6. **Data Persistence**: Microservice 2 stores data in Firestore
7. **Real-time Updates**: Frontend displays updated item list

## 🛡️ Security Features

- **Workload Identity**: Secure service-to-service authentication
- **Network Policies**: Kubernetes microsegmentation
- **IAM Roles**: Least privilege access control
- **Secret Management**: Google Secret Manager integration
- **Container Security**: Non-root users, read-only filesystems
- **Input Validation**: Comprehensive request validation and sanitization

## 📊 Monitoring & Observability

- **Health Checks**: Liveness and readiness probes for all services
- **Metrics**: Custom application and business metrics
- **Logging**: Structured logging with correlation IDs
- **Alerting**: Multi-tier alerting (infrastructure, SRE, business)
- **Dashboards**: GCP Monitoring dashboards for operational visibility
- **Distributed Tracing**: Request tracing across microservices

## 🎯 Key Features Implemented

### Infrastructure
- ✅ VPC with private/public subnets and NAT gateway
- ✅ GKE cluster with autoscaling and security hardening
- ✅ Cloud Storage + Load Balancer for cost-effective frontend hosting
- ✅ Pub/Sub for event-driven architecture
- ✅ Firestore for scalable NoSQL data storage
- ✅ Comprehensive IAM with service accounts and workload identity

### Applications
- ✅ Vue.js 3 frontend with modern UI/UX and PWA capabilities
- ✅ Node.js microservices with comprehensive error handling
- ✅ RESTful APIs with validation and rate limiting
- ✅ Event-driven communication between services
- ✅ Production-ready Docker containers with multi-stage builds

### DevOps
- ✅ Terraform modules for reusable infrastructure components
- ✅ GitHub Actions CI/CD with automated testing and deployment
- ✅ Helm charts for Kubernetes application management
- ✅ Automated Docker image building and registry management
- ✅ Environment-specific configuration management

### Monitoring
- ✅ Application health endpoints and metrics
- ✅ Infrastructure monitoring with custom dashboards
- ✅ Log aggregation and structured logging
- ✅ Multi-tier alerting strategy
- ✅ Performance monitoring and SLA tracking

## 🎮 Local Development

### Frontend Development
```bash
cd applications/frontend
npm install
npm run serve  # Development server on http://localhost:8080
```

### Microservice Development  
```bash
cd applications/microservice-1
npm install
npm run dev    # Development server with hot reload

cd applications/microservice-2  
npm install
npm run dev    # Development server with hot reload
```

### Testing
```bash
# Run frontend tests
cd applications/frontend
npm run test:unit

# Run microservice tests
cd applications/microservice-1
npm test

cd applications/microservice-2
npm test
```

## 🚀 Deployment

### Automated Deployment (Recommended)
Push to `main` branch triggers automatic deployment via GitHub Actions:
1. Terraform infrastructure updates
2. Docker image building and pushing
3. Kubernetes application deployment
4. Frontend deployment to Cloud Storage

### Manual Deployment
```bash
# Infrastructure
cd terraform/environments/dev
terraform apply

# Applications
# (See Quick Start section above)
```

## 📈 Scaling and Performance

- **Horizontal Pod Autoscaler**: Automatic scaling based on CPU/memory
- **Cluster Autoscaler**: Node pool scaling based on resource demands
- **CDN Caching**: Global content delivery with Cloud CDN
- **Connection Pooling**: Efficient database connection management
- **Async Processing**: Non-blocking operations with event-driven design

## 💰 Cost Optimization

- **Cloud Storage**: 90% cost reduction vs. compute instances for frontend
- **Preemptible Nodes**: Cost-effective compute for non-critical workloads
- **Auto-scaling**: Scale to zero during low usage periods
- **Resource Right-sizing**: Proper CPU/memory allocation to avoid waste

## 🔍 Troubleshooting

### Check Application Health
```bash
# Check pod status
kubectl get pods

# Check service endpoints
kubectl get services

# View application logs
kubectl logs -l app=microservice-1
kubectl logs -l app=microservice-2

# Check ingress status
kubectl describe ingress
```

### Common Issues
- **Pod CrashLoopBackOff**: Check resource limits and application logs
- **ImagePullBackOff**: Verify image names and registry permissions
- **Service Connection Issues**: Check network policies and service discovery
- **Pub/Sub Issues**: Verify IAM permissions and topic/subscription configuration

## 📚 Documentation

- [Architecture Documentation](docs/architecture.md) - Detailed system architecture
- [Production Recommendations](docs/production-recommendations.md) - Production readiness guide
- [Technical Decisions](docs/technical-decisions.md) - ADRs and design rationale

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🎊 Acknowledgments

- Google Cloud Platform for comprehensive cloud services
- Kubernetes community for container orchestration
- Vue.js team for excellent frontend framework
- Terraform community for infrastructure as code tooling

---

**DogfyDiet Platform** - Demonstrating cloud-native architecture excellence 🐕❤️
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./CONTRIBUTING.md
FILE_CONTENT_START
# Contributing to DogfyDiet Platform

Thank you for your interest in contributing to the DogfyDiet Platform! This document provides guidelines and instructions for contributing to this project.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Process](#development-process)
- [Pull Request Process](#pull-request-process)
- [Infrastructure Changes](#infrastructure-changes)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)
- [Security](#security)

## 📜 Code of Conduct

We are committed to providing a welcoming and inspiring community for all. Please read and follow our Code of Conduct:

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on what is best for the community
- Show empathy towards other community members

## 🚀 Getting Started

### Prerequisites

1. **Fork the Repository**
   ```bash
   # Fork via GitHub UI, then clone your fork
   git clone https://github.com/YOUR_USERNAME/dogfydiet-platform.git
   cd dogfydiet-platform
   ```

2. **Set Up Development Environment**
   ```bash
   # Install required tools
   - terraform >= 1.5.0
   - gcloud CLI
   - kubectl
   - helm >= 3.12.0
   - node.js >= 18.0.0
   - docker
   ```

3. **Configure Git**
   ```bash
   git config user.name "Your Name"
   git config user.email "your.email@example.com"
   ```

## 💻 Development Process

### 1. Branch Naming Convention

Create branches following this pattern:
- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring
- `test/description` - Test additions/updates
- `chore/description` - Maintenance tasks

Example:
```bash
git checkout -b feature/add-redis-cache
```

### 2. Commit Message Format

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Test additions/modifications
- `chore`: Maintenance tasks
- `perf`: Performance improvements
- `ci`: CI/CD changes

Examples:
```bash
feat(api): add rate limiting to microservice-1

- Implement rate limiting middleware
- Add configuration for rate limits
- Update documentation

Closes #123
```

### 3. Development Workflow

1. **Create a Feature Branch**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/your-feature
   ```

2. **Make Changes**
   - Write clean, documented code
   - Follow existing patterns and conventions
   - Add tests for new functionality

3. **Test Locally**
   ```bash
   # Run application tests
   cd applications/microservice-1
   npm test
   
   # Validate Terraform
   cd terraform/environments/dev
   terraform fmt -recursive
   terraform validate
   ```

4. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat(scope): description"
   ```

5. **Push and Create PR**
   ```bash
   git push origin feature/your-feature
   ```

## 🔄 Pull Request Process

### 1. PR Requirements

Before submitting a PR, ensure:

- [ ] Code follows project coding standards
- [ ] All tests pass
- [ ] Documentation is updated
- [ ] Terraform is formatted (`terraform fmt`)
- [ ] No sensitive data is committed
- [ ] PR has a clear description
- [ ] Related issues are linked

### 2. PR Template

When creating a PR, use this template:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Infrastructure change

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] My code follows the project style guidelines
- [ ] I have performed a self-review
- [ ] I have commented my code where necessary
- [ ] I have updated the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix/feature works
- [ ] New and existing unit tests pass locally

## Related Issues
Closes #(issue number)

## Screenshots (if applicable)
```

### 3. Review Process

1. **Automated Checks**
   - GitHub Actions will run automatically
   - All checks must pass before review

2. **Code Review**
   - At least one maintainer approval required
   - Address all feedback constructively
   - Re-request review after changes

3. **Merge Requirements**
   - All CI checks pass
   - Approved by maintainer
   - No merge conflicts
   - Up to date with main branch

## 🏗️ Infrastructure Changes

### Special Requirements for Terraform

1. **Planning Phase**
   - All Terraform changes trigger a plan in PR
   - Review the plan output carefully
   - Check for unintended changes

2. **Approval Process**
   - Infrastructure changes require senior engineer approval
   - Cost estimates should be reviewed
   - Security scan must pass

3. **Testing**
   ```bash
   # Format check
   terraform fmt -check -recursive
   
   # Validate
   terraform validate
   
   # Plan
   terraform plan
   ```

4. **Documentation**
   - Update module documentation
   - Document any new variables
   - Update architecture diagrams if needed

## 📏 Coding Standards

### JavaScript/Node.js

- Use ESLint configuration
- Follow Airbnb style guide
- Use async/await over callbacks
- Proper error handling

### Terraform

- Use meaningful resource names
- Group related resources
- Comment complex logic
- Use consistent formatting

### Vue.js

- Use Composition API
- Follow Vue style guide
- Component names in PascalCase
- Props validation required

## 🧪 Testing Requirements

### Unit Tests
- Minimum 80% code coverage
- Test edge cases
- Mock external dependencies

### Integration Tests
- Test API endpoints
- Verify database operations
- Test message queue interactions

### Infrastructure Tests
- Validate Terraform plans
- Test module inputs/outputs
- Verify security policies

## 📚 Documentation

### Code Documentation
- JSDoc for JavaScript functions
- Comments for complex logic
- README for each module

### API Documentation
- Update OpenAPI/Swagger specs
- Document all endpoints
- Include request/response examples

### Architecture Documentation
- Update diagrams for significant changes
- Document design decisions
- Keep ADRs up to date

## 🔐 Security

### Security Guidelines

1. **Never Commit Secrets**
   - No API keys, passwords, or tokens
   - Use environment variables
   - Utilize secret management

2. **Dependency Management**
   - Keep dependencies updated
   - Run `npm audit` regularly
   - Address vulnerabilities promptly

3. **Code Security**
   - Validate all inputs
   - Sanitize user data
   - Follow OWASP guidelines

### Reporting Security Issues

For security vulnerabilities, please email security@dogfydiet.com instead of creating a public issue.

## 🎯 Areas for Contribution

We welcome contributions in these areas:

1. **Features**
   - Performance optimizations
   - New API endpoints
   - UI/UX improvements

2. **Infrastructure**
   - Cost optimization
   - Security hardening
   - Monitoring improvements

3. **Documentation**
   - API documentation
   - Deployment guides
   - Architecture diagrams

4. **Testing**
   - Increase test coverage
   - Add integration tests
   - Performance testing

## 🤝 Getting Help

- Create an issue for bugs/features
- Join our Slack channel: [#dogfydiet-dev]
- Email: contributors@dogfydiet.com

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to DogfyDiet Platform! 🐕❤️
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./scripts/bootstrap.sh
FILE_CONTENT_START
#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-nahuelgabe-test}"
REGION="${GCP_REGION:-us-central1}"
TERRAFORM_STATE_BUCKET="${TERRAFORM_STATE_BUCKET:-${PROJECT_ID}-terraform-state}"

echo -e "${GREEN}🚀 DogfyDiet Platform - Bootstrap Setup${NC}"
echo "================================================"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI is not installed. Please install it first.${NC}"
    echo "Visit: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform is not installed. Please install it first.${NC}"
    echo "Visit: https://learn.hashicorp.com/tutorials/terraform/install-cli"
    exit 1
fi

# Check gcloud authentication
echo -e "\n${YELLOW}Checking GCP authentication...${NC}"
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo -e "${RED}❌ Not authenticated with GCP. Running 'gcloud auth login'...${NC}"
    gcloud auth login
fi

# Set project
echo -e "\n${YELLOW}Setting GCP project to: ${PROJECT_ID}${NC}"
gcloud config set project ${PROJECT_ID}

# Create terraform state bucket if it doesn't exist
echo -e "\n${YELLOW}Creating Terraform state bucket...${NC}"
if ! gsutil ls -b gs://${TERRAFORM_STATE_BUCKET} &> /dev/null; then
    echo "Creating bucket: gs://${TERRAFORM_STATE_BUCKET}"
    gsutil mb -p ${PROJECT_ID} -l ${REGION} gs://${TERRAFORM_STATE_BUCKET}
    
    # Enable versioning
    gsutil versioning set on gs://${TERRAFORM_STATE_BUCKET}
    
    # Set lifecycle rule to delete old versions after 30 days
    cat > /tmp/lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 30,
          "isLive": false
        }
      }
    ]
  }
}
EOF
    gsutil lifecycle set /tmp/lifecycle.json gs://${TERRAFORM_STATE_BUCKET}
    rm /tmp/lifecycle.json
    
    echo -e "${GREEN}✅ Terraform state bucket created successfully${NC}"
else
    echo -e "${GREEN}✅ Terraform state bucket already exists${NC}"
fi

# Create a service account for GitHub Actions CI/CD
echo -e "\n${YELLOW}Creating CI/CD service account...${NC}"
SA_NAME="dogfydiet-github-actions"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if ! gcloud iam service-accounts describe ${SA_EMAIL} --project=${PROJECT_ID} &> /dev/null; then
    echo "Creating service account: ${SA_NAME}"
    gcloud iam service-accounts create ${SA_NAME} \
        --display-name="DogfyDiet GitHub Actions CI/CD" \
        --description="Service account for GitHub Actions CI/CD pipeline" \
        --project=${PROJECT_ID}
    
    # Grant necessary roles
    echo "Granting IAM roles..."
    roles=(
        "roles/compute.admin"
        "roles/container.admin"
        "roles/storage.admin"
        "roles/iam.serviceAccountUser"
        "roles/artifactregistry.admin"
        "roles/secretmanager.admin"
        "roles/pubsub.admin"
        "roles/datastore.owner"
        "roles/monitoring.admin"
        "roles/logging.admin"
    )
    
    for role in "${roles[@]}"; do
        echo "  - ${role}"
        gcloud projects add-iam-policy-binding ${PROJECT_ID} \
            --member="serviceAccount:${SA_EMAIL}" \
            --role="${role}" \
            --quiet
    done
    
    echo -e "${GREEN}✅ Service account created and configured${NC}"
else
    echo -e "${GREEN}✅ Service account already exists${NC}"
fi

# Create and download service account key
echo -e "\n${YELLOW}Creating service account key...${NC}"
KEY_FILE="./sa-key.json"
if [ ! -f "${KEY_FILE}" ]; then
    gcloud iam service-accounts keys create ${KEY_FILE} \
        --iam-account=${SA_EMAIL} \
        --project=${PROJECT_ID}
    
    echo -e "${GREEN}✅ Service account key created: ${KEY_FILE}${NC}"
    echo -e "${YELLOW}⚠️  IMPORTANT: This key will be used for GitHub Actions. Keep it secure!${NC}"
else
    echo -e "${YELLOW}⚠️  Service account key already exists: ${KEY_FILE}${NC}"
fi

# Update terraform backend configuration
echo -e "\n${YELLOW}Updating Terraform backend configuration...${NC}"
BACKEND_FILE="terraform/environments/dev/backend.tf"
if [ ! -f "${BACKEND_FILE}" ]; then
    cat > ${BACKEND_FILE} <<EOF
terraform {
  backend "gcs" {
    bucket = "${TERRAFORM_STATE_BUCKET}"
    prefix = "dogfydiet-platform/dev"
  }
}
EOF
    echo -e "${GREEN}✅ Created backend configuration: ${BACKEND_FILE}${NC}"
else
    echo -e "${YELLOW}⚠️  Backend configuration already exists. Please verify bucket name is correct.${NC}"
fi

# Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Bootstrap setup completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nNext steps:"
echo -e "1. Configure GitHub secrets (see docs/github-secrets-setup.md)"
echo -e "2. Base64 encode the service account key:"
echo -e "   ${YELLOW}cat ${KEY_FILE} | base64 -w 0${NC}"
echo -e "3. Add the encoded key as GitHub secret: GCP_SA_KEY"
echo -e "4. Initialize Terraform:"
echo -e "   ${YELLOW}cd terraform/environments/dev && terraform init${NC}"
echo -e "5. Review and apply Terraform:"
echo -e "   ${YELLOW}terraform plan && terraform apply${NC}"
echo -e "\n${RED}⚠️  Remember to keep ${KEY_FILE} secure and delete it after adding to GitHub secrets!${NC}"
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./.github/workflows/release.yml
FILE_CONTENT_START
name: 'Release'

on:
  push:
    tags:
      - 'v*'

env:
  REGISTRY_REGION: us-central1
  PROJECT_ID: nahuelgabe-test
  REPOSITORY: dogfydiet-dev-docker-repo

jobs:
  generate-changelog:
    runs-on: ubuntu-latest
    outputs:
      changelog: ${{ steps.changelog.outputs.changelog }}
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Generate Changelog
      id: changelog
      run: |
        # Get the previous tag
        PREVIOUS_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
        
        if [ -z "$PREVIOUS_TAG" ]; then
          # If no previous tag, get all commits
          COMMITS=$(git log --pretty=format:"- %s (%h)" --reverse)
        else
          # Get commits since previous tag
          COMMITS=$(git log --pretty=format:"- %s (%h)" --reverse $PREVIOUS_TAG..HEAD)
        fi
        
        # Create changelog
        CHANGELOG="## Changes in ${GITHUB_REF_NAME}

        ### Infrastructure Changes
        $(echo "$COMMITS" | grep -E "(feat|fix|chore).*terraform|infrastructure|gcp|gke" || echo "- No infrastructure changes")

        ### Application Changes
        $(echo "$COMMITS" | grep -E "(feat|fix).*app|frontend|microservice|api" || echo "- No application changes")

        ### DevOps Changes
        $(echo "$COMMITS" | grep -E "(feat|fix|chore).*(ci|cd|pipeline|workflow|deploy)" || echo "- No DevOps changes")

        ### Other Changes
        $(echo "$COMMITS" | grep -vE "(terraform|infrastructure|gcp|gke|app|frontend|microservice|api|ci|cd|pipeline|workflow|deploy)" || echo "- No other changes")

        ### Full Commit History
        $COMMITS"
        
        # Save to file and output
        echo "$CHANGELOG" > changelog.md
        {
          echo 'changelog<<EOF'
          echo "$CHANGELOG"
          echo EOF
        } >> $GITHUB_OUTPUT

    - name: Upload Changelog
      uses: actions/upload-artifact@v4
      with:
        name: changelog
        path: changelog.md

  build-and-tag-images:
    runs-on: ubuntu-latest
    environment: dev
    
    strategy:
      matrix:
        service: [microservice-1, microservice-2]
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Extract version from tag
      id: version
      run: echo "version=${GITHUB_REF_NAME#v}" >> $GITHUB_OUTPUT

    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}

    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v2

    - name: Configure Docker to use gcloud as a credential helper
      run: gcloud auth configure-docker ${{ env.REGISTRY_REGION }}-docker.pkg.dev

    - name: Build and push release image
      run: |
        cd applications/${{ matrix.service }}
        
        # Build image with version tag
        docker build -t ${{ env.REGISTRY_REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ matrix.service }}:${{ steps.version.outputs.version }} .
        docker build -t ${{ env.REGISTRY_REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ matrix.service }}:stable .
        
        # Push images
        docker push ${{ env.REGISTRY_REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ matrix.service }}:${{ steps.version.outputs.version }}
        docker push ${{ env.REGISTRY_REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ matrix.service }}:stable

  create-release:
    needs: [generate-changelog, build-and-tag-images]
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Download Changelog
      uses: actions/download-artifact@v4
      with:
        name: changelog

    - name: Create GitHub Release
      uses: actions/create-release@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        tag_name: ${{ github.ref_name }}
        release_name: Release ${{ github.ref_name }}
        body_path: changelog.md
        draft: false
        prerelease: false

    - name: Release Summary
      run: |
        echo "## 🎉 Release ${{ github.ref_name }} Created!" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY
        echo "### Released Components:" >> $GITHUB_STEP_SUMMARY
        echo "- **microservice-1:** \`${{ github.ref_name }}\`" >> $GITHUB_STEP_SUMMARY
        echo "- **microservice-2:** \`${{ github.ref_name }}\`" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY
        echo "### Docker Images:" >> $GITHUB_STEP_SUMMARY
        echo "- \`${{ env.REGISTRY_REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/microservice-1:${GITHUB_REF_NAME#v}\`" >> $GITHUB_STEP_SUMMARY
        echo "- \`${{ env.REGISTRY_REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/microservice-2:${GITHUB_REF_NAME#v}\`" >> $GITHUB_STEP_SUMMARY
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./.github/workflows/terraform-plan.yml
FILE_CONTENT_START
name: 'Terraform Plan'

on:
  pull_request:
    branches: [ "main" ]
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-*.yml'

env:
  TF_VERSION: '1.5.7'
  TF_IN_AUTOMATION: true
  TF_INPUT: false

permissions:
  contents: read
  pull-requests: write
  issues: write

jobs:
  terraform-security:
    name: 'Security Scan'
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Run Checkov security scan
      id: checkov
      uses: bridgecrewio/checkov-action@master
      with:
        directory: terraform/
        framework: terraform
        output_format: github_failed_only
        soft_fail: true
    
    - name: Run tfsec
      uses: aquasecurity/tfsec-action@v1.0.0
      with:
        working_directory: terraform
        soft_fail: true
        format: github
    
    - name: Upload Security Results
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: security-results
        path: |
          checkov-results.sarif
          tfsec-results.sarif
        retention-days: 7

  terraform-validate:
    name: 'Validate Configuration'
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        environment: [dev]  # Add staging, prod as needed
    
    defaults:
      run:
        working-directory: terraform/environments/${{ matrix.environment }}
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}
    
    - name: Terraform Format Check
      id: fmt
      run: terraform fmt -check -recursive -diff
      continue-on-error: true
    
    - name: Post Format Check Comment
      if: steps.fmt.outcome == 'failure'
      uses: actions/github-script@v7
      with:
        script: |
          github.rest.issues.createComment({
            owner: context.repo.owner,
            repo: context.repo.repo,
            issue_number: context.issue.number,
            body: '❌ **Terraform Format Check Failed**\n\nPlease run `terraform fmt -recursive` to fix formatting issues.'
          })
    
    - name: Initialize Terraform
      run: |
        terraform init -backend=false
    
    - name: Validate Terraform
      id: validate
      run: terraform validate

  terraform-plan:
    name: 'Plan Changes'
    needs: [terraform-security, terraform-validate]
    runs-on: ubuntu-latest
    environment: dev
    
    strategy:
      matrix:
        environment: [dev]
    
    defaults:
      run:
        working-directory: terraform/environments/${{ matrix.environment }}
    
    outputs:
      plan_exit_code: ${{ steps.plan.outputs.exit_code }}
      plan_summary: ${{ steps.summary.outputs.summary }}
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}
    
    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}
    
    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v2
    
    - name: Initialize Terraform
      run: terraform init
    
    - name: Create Plan
      id: plan
      run: |
        terraform plan -detailed-exitcode -out=tfplan -no-color > plan_output.txt 2>&1 || echo "exit_code=$?" >> $GITHUB_OUTPUT
        echo "exit_code=${exit_code:-0}" >> $GITHUB_OUTPUT
      env:
        TF_VAR_notification_email: ${{ secrets.NOTIFICATION_EMAIL }}
      continue-on-error: true
    
    - name: Generate Plan Summary
      id: summary
      run: |
        PLAN_OUTPUT=$(cat plan_output.txt)
        
        # Extract summary statistics
        RESOURCES_TO_ADD=$(echo "$PLAN_OUTPUT" | grep -E "^  \+" | wc -l || echo "0")
        RESOURCES_TO_CHANGE=$(echo "$PLAN_OUTPUT" | grep -E "^  ~" | wc -l || echo "0")
        RESOURCES_TO_DESTROY=$(echo "$PLAN_OUTPUT" | grep -E "^  -" | wc -l || echo "0")
        
        # Create summary
        SUMMARY="### 📊 Terraform Plan Summary\n\n"
        SUMMARY+="| Action | Count |\n"
        SUMMARY+="|--------|-------|\n"
        SUMMARY+="| **Create** | $RESOURCES_TO_ADD |\n"
        SUMMARY+="| **Update** | $RESOURCES_TO_CHANGE |\n"
        SUMMARY+="| **Delete** | $RESOURCES_TO_DESTROY |\n\n"
        
        if [ "$RESOURCES_TO_DESTROY" -gt 0 ]; then
          SUMMARY+="⚠️ **Warning**: This plan includes resource deletions!\n\n"
        fi
        
        echo "summary<<EOF" >> $GITHUB_OUTPUT
        echo "$SUMMARY" >> $GITHUB_OUTPUT
        echo "EOF" >> $GITHUB_OUTPUT
    
    - name: Save Plan Output
      run: |
        terraform show -no-color tfplan > tfplan.txt
    
    - name: Upload Plan
      uses: actions/upload-artifact@v4
      with:
        name: terraform-plan-${{ matrix.environment }}
        path: |
          terraform/environments/${{ matrix.environment }}/tfplan
          terraform/environments/${{ matrix.environment }}/tfplan.txt
          terraform/environments/${{ matrix.environment }}/plan_output.txt
        retention-days: 7
    
    - name: Post Plan to PR
      uses: actions/github-script@v7
      with:
        script: |
          const fs = require('fs');
          const planOutput = fs.readFileSync('terraform/environments/${{ matrix.environment }}/tfplan.txt', 'utf8');
          const exitCode = ${{ steps.plan.outputs.exit_code }};
          const summary = `${{ steps.summary.outputs.summary }}`;
          
          // Truncate plan if too long
          const maxLength = 60000;
          const truncatedPlan = planOutput.length > maxLength 
            ? planOutput.substring(0, maxLength) + '\n\n... (truncated)'
            : planOutput;
          
          // Find and update existing comment or create new one
          const { data: comments } = await github.rest.issues.listComments({
            owner: context.repo.owner,
            repo: context.repo.repo,
            issue_number: context.issue.number,
          });
          
          const botComment = comments.find(comment => 
            comment.user.type === 'Bot' && 
            comment.body.includes('Terraform Plan Results')
          );
          
          let status = '✅ **No changes required**';
          if (exitCode === 2) {
            status = '📝 **Changes will be applied**';
          } else if (exitCode === 1) {
            status = '❌ **Plan failed**';
          }
          
          const commentBody = `## 🔧 Terraform Plan Results - \`${{ matrix.environment }}\`
          
          ${status}
          
          ${summary}
          
          <details>
          <summary>📄 Full Plan Output</summary>
          
          \`\`\`hcl
          ${truncatedPlan}
          \`\`\`
          
          </details>
          
          ---
          
          **Actions Required:**
          - Review the plan carefully
          - Ensure all changes are intentional
          - Get approval from a maintainer before merging
          `;
          
          if (botComment) {
            await github.rest.issues.updateComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              comment_id: botComment.id,
              body: commentBody
            });
          } else {
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: commentBody
            });
          }

  terraform-cost:
    name: 'Cost Estimation'
    needs: terraform-plan
    runs-on: ubuntu-latest
    continue-on-error: true
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Download Plan
      uses: actions/download-artifact@v4
      with:
        name: terraform-plan-dev
        path: terraform/environments/dev
    
    - name: Setup Infracost
      uses: infracost/setup-infracost@v2
      with:
        api-key: ${{ secrets.INFRACOST_API_KEY }}
      continue-on-error: true
    
    - name: Generate Cost Estimate
      run: |
        infracost breakdown --path=terraform/environments/dev \
          --format=json \
          --out-file=/tmp/infracost.json
      continue-on-error: true
    
    - name: Post Cost Estimate
      if: success()
      uses: infracost/infracost-gh-action@v1
      with:
        path: /tmp/infracost.json
        behavior: update
      continue-on-error: true

  approval-check:
    name: 'Approval Status'
    needs: terraform-plan
    runs-on: ubuntu-latest
    if: needs.terraform-plan.outputs.plan_exit_code == '2'
    
    steps:
    - name: Check Approvals
      uses: actions/github-script@v7
      with:
        script: |
          const { data: reviews } = await github.rest.pulls.listReviews({
            owner: context.repo.owner,
            repo: context.repo.repo,
            pull_number: context.issue.number,
          });
          
          const approvals = reviews.filter(review => review.state === 'APPROVED');
          const requiresApproval = approvals.length === 0;
          
          if (requiresApproval) {
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: '🔒 **Approval Required**\n\nThis PR contains infrastructure changes and requires approval from a maintainer before it can be merged.'
            });
          }
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./.github/workflows/terraform-apply.yml
FILE_CONTENT_START
name: 'Terraform Apply'

on:
  push:
    branches: [ "main" ]
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-*.yml'

env:
  TF_VERSION: '1.5.7'
  TF_IN_AUTOMATION: true
  TF_INPUT: false

permissions:
  contents: read
  id-token: write

jobs:
  terraform-apply:
    name: 'Apply Infrastructure Changes'
    runs-on: ubuntu-latest
    environment: 
      name: dev
      url: ${{ steps.output.outputs.app_url }}
    
    outputs:
      frontend_bucket: ${{ steps.output.outputs.frontend_bucket }}
      load_balancer_ip: ${{ steps.output.outputs.load_balancer_ip }}
      
    defaults:
      run:
        shell: bash
        working-directory: terraform/environments/dev

    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}
        terraform_wrapper: false

    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}

    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v2

    - name: Terraform Init
      id: init
      run: |
        terraform init
        terraform workspace select dev || terraform workspace new dev

    - name: Terraform Plan
      id: plan
      run: |
        terraform plan -detailed-exitcode -out=tfplan
      env:
        TF_VAR_notification_email: ${{ secrets.NOTIFICATION_EMAIL }}
      continue-on-error: true

    - name: Check Plan Status
      if: steps.plan.outputs.exitcode == '1'
      run: |
        echo "❌ Terraform plan failed!"
        exit 1

    - name: Terraform Apply
      if: steps.plan.outputs.exitcode == '2'
      id: apply
      run: |
        terraform apply -auto-approve tfplan
        echo "✅ Terraform apply completed successfully!"

    - name: Capture Outputs
      id: output
      run: |
        # Capture key outputs
        FRONTEND_BUCKET=$(terraform output -raw frontend_bucket_name)
        LOAD_BALANCER_IP=$(terraform output -raw load_balancer_ip)
        DOCKER_REPO=$(terraform output -raw docker_repository_url)
        
        echo "frontend_bucket=$FRONTEND_BUCKET" >> $GITHUB_OUTPUT
        echo "load_balancer_ip=$LOAD_BALANCER_IP" >> $GITHUB_OUTPUT
        echo "docker_repo=$DOCKER_REPO" >> $GITHUB_OUTPUT
        echo "app_url=http://$LOAD_BALANCER_IP" >> $GITHUB_OUTPUT
        
        # Save outputs to file
        terraform output -json > outputs.json

    - name: Upload Outputs
      uses: actions/upload-artifact@v4
      with:
        name: terraform-outputs
        path: terraform/environments/dev/outputs.json
        retention-days: 90

    - name: Update GitHub Secrets
      uses: actions/github-script@v7
      with:
        script: |
          const sodium = require('tweetsodium');
          
          async function updateSecret(secretName, secretValue) {
            // Get the repository public key
            const { data: { key, key_id } } = await github.rest.actions.getRepoPublicKey({
              owner: context.repo.owner,
              repo: context.repo.repo,
            });
            
            // Encrypt the secret value
            const messageBytes = Buffer.from(secretValue);
            const keyBytes = Buffer.from(key, 'base64');
            const encryptedBytes = sodium.seal(messageBytes, keyBytes);
            const encryptedValue = Buffer.from(encryptedBytes).toString('base64');
            
            // Create or update the secret
            await github.rest.actions.createOrUpdateRepoSecret({
              owner: context.repo.owner,
              repo: context.repo.repo,
              secret_name: secretName,
              encrypted_value: encryptedValue,
              key_id: key_id,
            });
          }
          
          // Update secrets with Terraform outputs
          const outputs = {
            FRONTEND_BUCKET_NAME: '${{ steps.output.outputs.frontend_bucket }}',
            API_URL: 'http://${{ steps.output.outputs.load_balancer_ip }}/api'
          };
          
          for (const [key, value] of Object.entries(outputs)) {
            if (value && value !== 'null') {
              console.log(`Updating secret: ${key}`);
              await updateSecret(key, value);
            }
          }
      continue-on-error: true

    - name: Generate Summary
      run: |
        cat >> $GITHUB_STEP_SUMMARY << EOF
        ## 🚀 Infrastructure Deployment Summary
        
        **Status:** ✅ Successfully Applied
        
        ### 📊 Key Resources
        
        | Resource | Value |
        |----------|-------|
        | **Frontend Bucket** | \`${{ steps.output.outputs.frontend_bucket }}\` |
        | **Load Balancer IP** | \`${{ steps.output.outputs.load_balancer_ip }}\` |
        | **Application URL** | [http://${{ steps.output.outputs.load_balancer_ip }}](http://${{ steps.output.outputs.load_balancer_ip }}) |
        
        ### 🔧 Next Steps
        
        1. Wait for DNS propagation (if using custom domain)
        2. Deploy applications using the build-deploy workflow
        3. Monitor the deployment in [GCP Console](https://console.cloud.google.com)
        
        ### 📝 Configuration Commands
        
        \`\`\`bash
        # Configure kubectl
        gcloud container clusters get-credentials dogfydiet-dev-gke-cluster --region us-central1
        
        # Check cluster status
        kubectl get nodes
        kubectl get pods --all-namespaces
        \`\`\`
        EOF

    - name: Notify Slack
      if: always()
      uses: 8398a7/action-slack@v3
      with:
        status: ${{ job.status }}
        text: |
          Terraform Apply ${{ job.status }}
          Environment: dev
          Actor: ${{ github.actor }}
          Commit: ${{ github.sha }}
        webhook_url: ${{ secrets.SLACK_WEBHOOK }}
      continue-on-error: true

  post-deployment-tests:
    name: 'Post Deployment Tests'
    needs: terraform-apply
    runs-on: ubuntu-latest
    if: success()
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Test Load Balancer
      run: |
        LB_IP="${{ needs.terraform-apply.outputs.load_balancer_ip }}"
        echo "Testing Load Balancer at: http://$LB_IP"
        
        # Wait for LB to be ready
        for i in {1..30}; do
          if curl -s -o /dev/null -w "%{http_code}" "http://$LB_IP" | grep -q "404\|200"; then
            echo "✅ Load Balancer is responding"
            break
          fi
          echo "Waiting for Load Balancer... ($i/30)"
          sleep 10
        done
    
    - name: Validate GKE Cluster
      run: |
        # Authenticate
        gcloud auth activate-service-account --key-file=<(echo '${{ secrets.GCP_SA_KEY }}' | base64 -d)
        
        # Get cluster credentials
        gcloud container clusters get-credentials dogfydiet-dev-gke-cluster \
          --region us-central1 \
          --project nahuelgabe-test
        
        # Check cluster health
        kubectl get nodes
        kubectl get namespaces
        kubectl get pods --all-namespaces
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./.github/workflows/build-deploy.yml
FILE_CONTENT_START
name: 'Build and Deploy Applications'

on:
  push:
    branches: [ "main" ]
    paths: # These path filters will now be the primary gate for push triggers
      - 'applications/**'
      - 'k8s/**'
      - '.github/workflows/build-deploy.yml'
  
  workflow_dispatch:
    inputs:
      deploy_frontend:
        description: 'Deploy Frontend'
        required: true
        default: true
        type: boolean
      deploy_microservices:
        description: 'Deploy Microservices'
        required: true
        default: true
        type: boolean

env:
  REGISTRY_REGION: us-central1
  PROJECT_ID: nahuelgabe-test
  REPOSITORY: dogfydiet-dev-docker-repo

jobs:
  # Build and push Docker images
  build-microservice-1:
    # 'needs: changes' is removed
    # Runs if manually dispatched to deploy microservices OR if it's a push event (filtered by workflow paths)
    if: github.event.inputs.deploy_microservices == 'true' || github.event_name == 'push'
    runs-on: ubuntu-latest # Changed from ubuntu-24.04 in original changes job, ensure consistency or use ubuntu-latest
    environment: dev
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}

    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v2

    - name: Configure Docker to use gcloud as a credential helper
      run: gcloud auth configure-docker ${{ env.REGISTRY_REGION }}-docker.pkg.dev

    - name: Build Docker image
      run: |
        cd applications/microservice-1
        docker build -t ${{ env.REGISTRY_REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/microservice-1:${{ github.sha }} .
        docker build -t ${{ env.REGISTRY_REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/microservice-1:latest .

    - name: Push Docker image
      run: |
        docker push ${{ env.REGISTRY_REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/microservice-1:${{ github.sha }}
        docker push ${{ env.REGISTRY_REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/microservice-1:latest

  build-microservice-2:
    # 'needs: changes' is removed
    # Runs if manually dispatched to deploy microservices OR if it's a push event (filtered by workflow paths)
    if: github.event.inputs.deploy_microservices == 'true' || github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: dev
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}

    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v2

    - name: Configure Docker to use gcloud as a credential helper
      run: gcloud auth configure-docker ${{ env.REGISTRY_REGION }}-docker.pkg.dev

    - name: Build Docker image
      run: |
        cd applications/microservice-2
        docker build -t ${{ env.REGISTRY_REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/microservice-2:${{ github.sha }} .
        docker build -t ${{ env.REGISTRY_REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/microservice-2:latest .

    - name: Push Docker image
      run: |
        docker push ${{ env.REGISTRY_REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/microservice-2:${{ github.sha }}
        docker push ${{ env.REGISTRY_REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/microservice-2:latest

  # Deploy frontend
  deploy-frontend:
    # 'needs: changes' is removed
    # Runs if manually dispatched to deploy frontend OR if it's a push event (filtered by workflow paths)
    if: github.event.inputs.deploy_frontend == 'true' || github.event_name == 'push'
    runs-on: ubuntu-22.04
    environment: dev
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
        cache-dependency-path: applications/frontend/package-lock.json

    - name: Install dependencies
      run: |
        cd applications/frontend
        npm ci

    - name: Build frontend
      run: |
        cd applications/frontend
        npm run build
      env:
        VUE_APP_API_URL: ${{ secrets.API_URL }}
        VUE_APP_ENVIRONMENT: dev

    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}

    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v2

    - name: Deploy to Cloud Storage
      run: |
        cd applications/frontend
        echo "--- Contents of dist/ folder before rsync ---"
        ls -R dist/
        echo "--- Starting rsync to GCS bucket: ${{ secrets.FRONTEND_BUCKET_NAME }} ---"
        gsutil -m rsync -r -d dist/ gs://${{ secrets.FRONTEND_BUCKET_NAME }}/
        
        echo "--- Setting Cache-Control for HTML files ---"
        gsutil -m setmeta -h "Cache-Control:public, max-age=3600" gs://${{ secrets.FRONTEND_BUCKET_NAME }}/**/*.html
        
        echo "--- Setting Cache-Control for JS and CSS files ---"
        # Estos archivos sabemos que existen por el build de Vue
        gsutil -m setmeta -h "Cache-Control:public, max-age=31536000" gs://${{ secrets.FRONTEND_BUCKET_NAME }}/**/*.js gs://${{ secrets.FRONTEND_BUCKET_NAME }}/**/*.css

        echo "--- Attempting to set Cache-Control for specific optional files ---"
        # Para favicon.ico en la raíz del bucket (si existe en dist/)
        if [ -f dist/favicon.ico ]; then
          echo "Setting metadata for favicon.ico"
          # No se necesita -f aquí. Si el rsync lo copió, el archivo existe en el bucket.
          gsutil -m setmeta -h "Cache-Control:public, max-age=86400" gs://${{ secrets.FRONTEND_BUCKET_NAME }}/favicon.ico
        else
          echo "favicon.ico not found in dist/, skipping metadata for it."
        fi
        
        # Para otros tipos de imágenes. Si no existen, gsutil setmeta imprimirá "No URLs matched"
        # pero no debería fallar todo el paso a menos que sea el único error.
        # Para asegurar que el paso no falle si NO se encuentra NINGÚN archivo de un tipo específico:
        IMAGE_EXTENSIONS=("png" "jpg" "jpeg" "gif" "svg")
        for ext in "${IMAGE_EXTENSIONS[@]}"; do
          echo "Attempting to set metadata for *.$ext files"
          # Ejecutamos el comando en un subshell y usamos '|| true' para que si el comando gsutil
          # devuelve un código de error (por ejemplo, porque no encontró archivos),
          # el 'true' asegure que esta línea particular no haga fallar todo el script.
          (gsutil -m setmeta -h "Cache-Control:public, max-age=31536000" gs://${{ secrets.FRONTEND_BUCKET_NAME }}/**/*.$ext) || echo "No *.$ext files found or non-critical gsutil error for $ext, continuing."
        done

  # Deploy microservices to GKE
  deploy-microservices:
    needs: [build-microservice-1, build-microservice-2] # Depends on the build jobs
    # This condition ensures it runs if either build job succeeds.
    # It will only run if the preceding build jobs were triggered and at least one succeeded.
    if: always() && (needs.build-microservice-1.result == 'success' || needs.build-microservice-2.result == 'success')
    runs-on: ubuntu-latest
    environment: dev

    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}

    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v2

    - name: Install gke-gcloud-auth-plugin
      run: |
        gcloud components install gke-gcloud-auth-plugin --quiet

    - name: Get GKE credentials
      run: |
        gcloud container clusters get-credentials dogfydiet-dev-cluster --region us-central1 --project ${{ env.PROJECT_ID }}

    - name: Setup Helm
      uses: azure/setup-helm@v3
      with:
        version: '3.12.0'

    - name: Deploy Microservice 1
      # Only run if build-microservice-1 was successful
      if: needs.build-microservice-1.result == 'success'
      run: |
        cd k8s/helm-charts/microservice-1
        helm upgrade --install microservice-1 . \
          --namespace default \
          --set image.repository=${{ env.REGISTRY_REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/microservice-1 \
          --set image.tag=${{ github.sha }} \
          --set serviceAccount.name=microservice-1 \
          --set serviceAccount.annotations."iam\.gke\.io/gcp-service-account"=dogfydiet-dev-microservice-1@${{ env.PROJECT_ID }}.iam.gserviceaccount.com \
          --wait

    - name: Deploy Microservice 2
      # Only run if build-microservice-2 was successful
      if: needs.build-microservice-2.result == 'success'
      run: |
        cd k8s/helm-charts/microservice-2
        helm upgrade --install microservice-2 . \
          --namespace default \
          --set image.repository=${{ env.REGISTRY_REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/microservice-2 \
          --set image.tag=${{ github.sha }} \
          --set serviceAccount.name=microservice-2 \
          --set serviceAccount.annotations."iam\.gke\.io/gcp-service-account"=dogfydiet-dev-microservice-2@${{ env.PROJECT_ID }}.iam.gserviceaccount.com \
          --wait

    - name: Verify deployment
      run: |
        kubectl get pods -l app.kubernetes.io/instance=microservice-1 -o wide
        kubectl get pods -l app.kubernetes.io/instance=microservice-2 -o wide
        kubectl get services

    - name: Deployment Summary
      run: |
        echo "## 🚀 Application Deployment Summary" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY
        echo "### Deployed Components:" >> $GITHUB_STEP_SUMMARY
        # Adjust summary based on which components were actually deployed
        if [[ "${{ needs.deploy-frontend.if }}" != "false" && "${{ needs.deploy-frontend.result }}" == "success" ]]; then
          echo "- **Frontend:** Deployed to Cloud Storage" >> $GITHUB_STEP_SUMMARY
        fi
        if [[ "${{ needs.build-microservice-1.if }}" != "false" && "${{ needs.build-microservice-1.result }}" == "success" ]]; then
          echo "- **Microservice 1:** Image tag \`${{ github.sha }}\`" >> $GITHUB_STEP_SUMMARY
        fi
        if [[ "${{ needs.build-microservice-2.if }}" != "false" && "${{ needs.build-microservice-2.result }}" == "success" ]]; then
          echo "- **Microservice 2:** Image tag \`${{ github.sha }}\`" >> $GITHUB_STEP_SUMMARY
        fi
        echo "" >> $GITHUB_STEP_SUMMARY
        echo "### Next Steps:" >> $GITHUB_STEP_SUMMARY
        echo "1. Test the application endpoints" >> $GITHUB_STEP_SUMMARY
        echo "2. Monitor application health in GCP Console" >> $GITHUB_STEP_SUMMARY
        echo "3. Check application logs: \`kubectl logs -l app=microservice-1\`" >> $GITHUB_STEP_SUMMARY
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/frontend/public/index.html
FILE_CONTENT_START
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <link rel="icon" href="<%= BASE_URL %>favicon.ico">
  <title>DogfyDiet - Item Management</title>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
</head>
<body>
  <noscript>
    <strong>We're sorry but this application doesn't work properly without JavaScript enabled. Please enable it to continue.</strong>
  </noscript>
  <div id="app"></div>
  </body>
</html>
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/frontend/package.json
FILE_CONTENT_START
{
  "name": "dogfydiet-frontend-simple",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "serve": "vue-cli-service serve",
    "build": "vue-cli-service build",
    "lint": "vue-cli-service lint"
  },
  "dependencies": {
    "axios": "^1.5.0",
    "vue": "^3.3.4"
  },
  "devDependencies": {
    "@vue/cli-plugin-eslint": "~5.0.8",
    "@vue/cli-plugin-typescript": "~5.0.8",
    "@vue/cli-service": "~5.0.8",
    "@vue/eslint-config-typescript": "^11.0.3",
    "eslint": "^8.49.0",
    "eslint-plugin-vue": "^9.17.0",
    "typescript": "~4.5.5"
  },
  "eslintConfig": {
    "root": true,
    "env": {
      "node": true
    },
    "extends": [
      "plugin:vue/vue3-essential",
      "eslint:recommended",
      "@vue/typescript"
    ],
    "parserOptions": {
      "parser": "@typescript-eslint/parser"
    },
    "rules": {}
  },
  "browserslist": [
    "> 1%",
    "last 2 versions",
    "not dead",
    "not ie 11"
  ]
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/frontend/tsconfig.json
FILE_CONTENT_START
{
  "compilerOptions": {
    "target": "esnext",
    "module": "esnext",
    "strict": true,
    "jsx": "preserve",
    "importHelpers": true,
    "moduleResolution": "node",
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "sourceMap": true,
    "baseUrl": ".",
    "types": [
      "webpack-env",
      "jest" // If you plan to use Jest for unit tests
    ],
    "paths": {
      "@/*": [
        "src/*"
      ]
    },
    "lib": [
      "esnext",
      "dom",
      "dom.iterable",
      "scripthost"
    ]
  },
  "include": [
    "src/**/*.ts",
    "src/**/*.tsx",
    "src/**/*.vue",
    "tests/**/*.ts",
    "tests/**/*.tsx"
  ],
  "exclude": [
    "node_modules"
  ]
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/frontend/src/App.vue
FILE_CONTENT_START
<template>
  <div id="app-container">
    <h1>My DogfyDiet Items</h1>

    <form @submit.prevent="addItem" class="form-container">
      <input
        type="text"
        v-model="newItemName"
        placeholder="Enter item name (e.g., Favorite Toy)"
        class="input-field"
        required
      />
      <select v-model="newItemCategory" class="input-field" required>
        <option value="food">Food</option>
        <option value="treats">Treats</option>
        <option value="supplements">Supplements</option>
        <option value="toys">Toys</option>
      </select>
      <input
        type="text"
        v-model="newItemDescription"
        placeholder="Optional description"
        class="input-field"
      />
      <button type="submit" class="btn-primary" :disabled="isLoading">
        {{ isLoading ? 'Adding...' : 'Add Item' }}
      </button>
    </form>
    </div>
</template>

<script lang="ts">
import { defineComponent, ref, onMounted } from 'vue';
import axios, { AxiosError } from 'axios'; // <--- AÑADIR AxiosError AQUÍ

// Interfaz para la estructura de un detalle de error de validación
interface ValidationErrorDetail {
  type: string;
  value: any;
  msg: string;
  path: string;
  location: string;
}

// Interfaz para la estructura de error.response.data
interface ErrorResponseData {
  error: string;
  details?: ValidationErrorDetail[];
  requestId?: string;
}

// ... resto de tus interfaces (Item, MessageType) ...
interface Item {
  id?: string | number;
  name: string;
  category?: string;
  description?: string;
  status?: 'pending' | 'confirmed';
}

type MessageType = 'success' | 'error' | 'loading' | '';

export default defineComponent({
  name: 'App',
  setup() {
    // ... (tus refs: newItemName, newItemCategory, etc. se mantienen como en la solución anterior)
    const newItemName = ref('');
    const newItemCategory = ref('food');
    const newItemDescription = ref('');
    const items = ref<Item[]>([]);
    const isLoading = ref(false);
    const message = ref('');
    const messageType = ref<MessageType>('');
    const initialLoadError = ref(false);

    const apiUrl = process.env.VUE_APP_API_URL || '/api/microservice1';

    const clearMessage = () => { /* ... se mantiene igual ... */
      message.value = '';
      messageType.value = '';
    };

    const showMessage = (text: string, type: MessageType, duration: number = 3000) => { /* ... se mantiene igual ... */
      message.value = text;
      messageType.value = type;
      if (type !== 'loading') {
        setTimeout(clearMessage, duration);
      }
    };

    const addItem = async () => {
      if (!newItemName.value.trim() || !newItemCategory.value) {
        showMessage('Item name and category are required.', 'error');
        return;
      }

      isLoading.value = true;
      showMessage('Adding item...', 'loading');

      const itemPayload = {
        name: newItemName.value,
        category: newItemCategory.value,
        description: newItemDescription.value
      };

      const itemForUI: Item = {
        name: newItemName.value,
        category: newItemCategory.value,
        status: 'pending'
      };

      items.value.push(itemForUI);
      const currentItemIndex = items.value.length - 1;

      try {
        const response = await axios.post<{ data: Item, messageId: string, success: boolean, requestId: string }>(`${apiUrl}/items`, itemPayload);
        
        if (response.data && response.data.data && items.value[currentItemIndex]) {
          items.value[currentItemIndex] = { ...items.value[currentItemIndex], ...response.data.data, status: 'confirmed' };
        } else if (items.value[currentItemIndex]) {
          items.value[currentItemIndex].status = 'confirmed';
        }
        
        showMessage(`Item "${newItemName.value}" added successfully!`, 'success');
        newItemName.value = '';
        newItemCategory.value = 'food';
        newItemDescription.value = '';
      } catch (err) { // <--- Cambiar 'error' a 'err' o mantener 'error' y usarlo abajo
        console.error('Error adding item:', err);
        let errorMessage = `Failed to add item "${itemForUI.name}". Please try again.`;
        
        // Verificación de tipo para AxiosError y su estructura
        if (axios.isAxiosError(err)) { // Usar type guard de Axios
          const axiosError = err as AxiosError<ErrorResponseData>; // Hacer type assertion
          if (axiosError.response && axiosError.response.data && axiosError.response.data.details) {
            const errorDetails = axiosError.response.data.details.map(
              (d: ValidationErrorDetail) => `${d.path}: ${d.msg}` // <--- Especificar tipo para 'd'
            ).join('; ');
            errorMessage = `Validation failed: ${errorDetails}`;
          } else if (axiosError.response && axiosError.response.data && axiosError.response.data.error) {
            errorMessage = `Error: ${axiosError.response.data.error}`;
          } else if (axiosError.message) {
            errorMessage = axiosError.message;
          }
        } else if (err instanceof Error) { // Manejar otros errores estándar
            errorMessage = err.message;
        }
        
        showMessage(errorMessage, 'error', 5000);
        items.value.splice(currentItemIndex, 1);
      } finally {
        isLoading.value = false;
        if (messageType.value === 'loading') {
            clearMessage();
        }
      }
    };

    onMounted(() => {
      console.log("VUE_APP_API_URL used by App.vue:", process.env.VUE_APP_API_URL);
      console.log("Effective API base URL for App.vue:", apiUrl);
    });

    return {
      newItemName,
      newItemCategory,
      newItemDescription,
      items,
      isLoading,
      addItem,
      message,
      messageType,
      initialLoadError
    };
  },
});
</script>
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/frontend/src/main.ts
FILE_CONTENT_START
import { createApp } from 'vue'
import App from './App.vue'
import './style.css'

const app = createApp(App)

// Optional: Global error handler (from your original main.ts)
app.config.errorHandler = (err, instance, info) => {
  console.error('Global error:', err, info)
  // In production, you might want to send this to a logging service
  if (process.env.NODE_ENV === 'production') {
    // Example: sendToLoggingService(err, instance, info);
  }
}

app.mount('#app')
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/frontend/src/style.css
FILE_CONTENT_START
/* Global Resets and Base Styles */
body {
  font-family: 'Inter', system-ui, sans-serif;
  margin: 0;
  padding: 0;
  background-color: #f4f7f9; /* Light gray background */
  color: #333;
  line-height: 1.6;
  display: flex;
  justify-content: center;
  align-items: flex-start; /* Align to top for longer lists */
  min-height: 100vh;
  padding-top: 20px; /* Add some padding at the top */
}

#app {
  width: 100%;
  max-width: 600px; /* Max width for the content */
  margin: 20px;
  padding: 20px;
  background-color: #fff; /* White card background */
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08); /* Softer shadow */
}

/* Header */
h1 {
  color: #2c3e50; /* Darker shade for heading */
  text-align: center;
  margin-bottom: 25px;
  font-weight: 600;
}

/* Form Elements */
.form-container {
  display: flex;
  gap: 10px; /* Space between input and button */
  margin-bottom: 25px;
}

.input-field {
  flex-grow: 1; /* Input takes available space */
  padding: 12px 15px;
  border: 1px solid #ccc; /* Lighter border */
  border-radius: 6px;
  font-size: 1rem;
  transition: border-color 0.2s ease-in-out, box-shadow 0.2s ease-in-out;
}

.input-field:focus {
  outline: none;
  border-color: #ec4899; /* Pink focus color, from your original theme */
  box-shadow: 0 0 0 2px rgba(236, 72, 153, 0.2);
}

.btn-primary {
  padding: 12px 20px;
  background-color: #ec4899; /* Pink brand color */
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 1rem;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s ease-in-out;
}

.btn-primary:hover {
  background-color: #d93682; /* Darker pink on hover */
}

.btn-primary:disabled {
  background-color: #f3a0c8; /* Lighter pink when disabled */
  cursor: not-allowed;
}


/* Item List */
.item-list {
  list-style-type: none;
  padding: 0;
  margin: 0;
}

.item-list li {
  background-color: #f9fafb; /* Very light gray for list items */
  padding: 10px 15px;
  border: 1px solid #e5e7eb; /* Light border for items */
  border-radius: 6px;
  margin-bottom: 10px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.95rem;
}

.item-list li:last-child {
  margin-bottom: 0;
}

/* Message Styling */
.message {
  padding: 10px;
  margin-bottom: 15px;
  border-radius: 4px;
  text-align: center;
  font-size: 0.9rem;
}
.message.success {
  background-color: #e6fffa;
  color: #00796b;
  border: 1px solid #b2f5ea;
}
.message.error {
  background-color: #ffebee;
  color: #c62828;
  border: 1px solid #ffcdd2;
}
.message.loading {
  background-color: #e3f2fd;
  color: #1565c0;
  border: 1px solid #bbdefb;
}

/* Responsive adjustments */
@media (max-width: 600px) {
  body {
    padding-top: 10px;
  }
  #app {
    margin: 10px;
    padding: 15px;
  }
  .form-container {
    flex-direction: column; /* Stack input and button on small screens */
  }
  .btn-primary {
    width: 100%; /* Full width button on small screens */
  }
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/microservice-2/Dockerfile
FILE_CONTENT_START
FROM node:18-alpine AS base

WORKDIR /app

RUN apk add --no-cache dumb-init

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 -G nodejs

FROM base AS deps

COPY package*.json ./

RUN npm ci --only=production && \
    npm cache clean --force

FROM base AS builder

COPY package*.json ./

RUN npm ci --silent

COPY . .

RUN npm run lint

FROM base AS production

ENV NODE_ENV=production
ENV PORT=3001

COPY --from=deps --chown=nextjs:nodejs /app/node_modules ./node_modules

COPY --chown=nextjs:nodejs . .

RUN rm -rf tests/ *.test.js *.spec.js .eslintrc.js

LABEL maintainer="DogfyDiet Platform Team"
LABEL version="1.0.0"
LABEL description="DogfyDiet Microservice 2 - Subscriber and Data Processor"

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js || exit 1

RUN echo 'const http = require("http"); \
const options = { hostname: "localhost", port: 3001, path: "/health", timeout: 2000 }; \
const req = http.request(options, (res) => { \
  process.exit(res.statusCode === 200 ? 0 : 1); \
}); \
req.on("error", () => process.exit(1)); \
req.end();' > healthcheck.js

USER nextjs

EXPOSE 3001

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/index.js"]
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/microservice-2/package.json
FILE_CONTENT_START
{
  "name": "dogfydiet-microservice-2",
  "version": "1.0.0",
  "description": "DogfyDiet Microservice 2 - Subscriber and Data Processor",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest --coverage",
    "test:watch": "jest --watch",
    "lint": "eslint src/",
    "lint:fix": "eslint src/ --fix"
  },
  "dependencies": {
    "@google-cloud/pubsub": "^4.0.0",
    "@google-cloud/secret-manager": "^5.0.0",
    "@google-cloud/trace-agent": "^8.0.0",
    "compression": "^1.7.4",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "express-rate-limit": "^7.1.0",
    "helmet": "^7.1.0",
    "mongodb": "^6.3.0",
    "morgan": "^1.10.0",
    "winston": "^3.11.0"
  },
  "devDependencies": {
    "eslint": "^8.54.0",
    "jest": "^29.7.0",
    "nodemon": "^3.0.1",
    "supertest": "^6.3.3"
  },
  "engines": {
    "node": ">=18.0.0"
  },
  "keywords": [
    "microservice",
    "pubsub",
    "mongodb",
    "dogfydiet"
  ],
  "author": "DogfyDiet Platform Team",
  "license": "MIT"
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/microservice-2/src/index.js
FILE_CONTENT_START
const express = require('express')
const cors = require('cors')
const helmet = require('helmet')
const compression = require('compression')
const morgan = require('morgan')
const rateLimit = require('express-rate-limit')
const { PubSub } = require('@google-cloud/pubsub')
const { Firestore } = require('@google-cloud/firestore')
const winston = require('winston')
require('dotenv').config()

// Initialize Google Cloud Tracing (must be before other imports)
if (process.env.GOOGLE_CLOUD_PROJECT) {
  require('@google-cloud/trace-agent').start()
}

// Configure Winston logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { 
    service: 'microservice-2',
    version: process.env.npm_package_version || '1.0.0'
  },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
})

// Initialize Express app
const app = express()
const PORT = process.env.PORT || 3001

// Initialize Google Cloud clients
const pubsub = new PubSub({
  projectId: process.env.GOOGLE_CLOUD_PROJECT || 'nahuelgabe-test'
})

const firestore = new Firestore({
  projectId: process.env.GOOGLE_CLOUD_PROJECT || 'nahuelgabe-test'
})

const SUBSCRIPTION_NAME = process.env.PUBSUB_SUBSCRIPTION || 'dogfydiet-dev-items-subscription'
const COLLECTION_NAME = process.env.FIRESTORE_COLLECTION || 'items'

// Statistics tracking
let stats = {
  messagesProcessed: 0,
  itemsStored: 0,
  errors: 0,
  startTime: new Date(),
  lastProcessed: null
}

// Middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"]
    }
  }
}))

app.use(compression())
app.use(express.json({ limit: '10mb' }))
app.use(express.urlencoded({ extended: true, limit: '10mb' }))

// CORS configuration
app.use(cors({
  origin: process.env.CORS_ORIGIN || ['http://localhost:8080', 'https://*.googleapis.com'],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  credentials: true
}))

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: process.env.RATE_LIMIT || 100,
  message: {
    error: 'Too many requests from this IP, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false
})

app.use('/api/', limiter)

// Logging middleware
app.use(morgan('combined', {
  stream: {
    write: (message) => logger.info(message.trim())
  }
}))

// Request ID middleware
app.use((req, res, next) => {
  req.id = require('crypto').randomUUID()
  res.setHeader('X-Request-ID', req.id)
  next()
})

// Health check endpoint
app.get('/health', (req, res) => {
  const healthStatus = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'microservice-2',
    version: process.env.npm_package_version || '1.0.0',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    environment: process.env.NODE_ENV || 'development',
    stats: stats
  }
  
  res.status(200).json(healthStatus)
})

// Readiness check endpoint
app.get('/ready', async (req, res) => {
  try {
    // Check Pub/Sub connectivity
    const subscription = pubsub.subscription(SUBSCRIPTION_NAME)
    await subscription.exists()
    
    // Check Firestore connectivity
    await firestore.collection(COLLECTION_NAME).limit(1).get()
    
    res.status(200).json({
      status: 'ready',
      timestamp: new Date().toISOString(),
      checks: {
        pubsub: 'connected',
        firestore: 'connected'
      }
    })
  } catch (error) {
    logger.error('Readiness check failed:', error)
    res.status(503).json({
      status: 'not ready',
      timestamp: new Date().toISOString(),
      error: error.message
    })
  }
})

// Metrics endpoint for monitoring
app.get('/metrics', (req, res) => {
  const metrics = {
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    cpu: process.cpuUsage(),
    environment: process.env.NODE_ENV || 'development',
    nodejs_version: process.version,
    stats: stats,
    processing_rate: stats.messagesProcessed / (process.uptime() / 60) // messages per minute
  }
  
  res.status(200).json(metrics)
})

// API Routes

// Get items from Firestore
app.get('/api/items', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50
    const offset = parseInt(req.query.offset) || 0
    
    const snapshot = await firestore
      .collection(COLLECTION_NAME)
      .orderBy('timestamp', 'desc')
      .limit(limit)
      .offset(offset)
      .get()
    
    const items = []
    snapshot.forEach(doc => {
      items.push({
        id: doc.id,
        ...doc.data()
      })
    })
    
    logger.info(`Retrieved ${items.length} items from Firestore`, {
      requestId: req.id,
      count: items.length,
      limit,
      offset
    })
    
    res.status(200).json({
      items: items,
      count: items.length,
      limit,
      offset,
      requestId: req.id
    })
    
  } catch (error) {
    logger.error('Error retrieving items from Firestore:', {
      requestId: req.id,
      error: error.message,
      stack: error.stack
    })
    
    res.status(500).json({
      error: 'Failed to retrieve items',
      requestId: req.id
    })
  }
})

// Get statistics
app.get('/api/stats', (req, res) => {
  const uptime = process.uptime()
  const processingRate = stats.messagesProcessed / (uptime / 60) // per minute
  
  res.status(200).json({
    ...stats,
    uptime: uptime,
    processingRate: Math.round(processingRate * 100) / 100,
    requestId: req.id
  })
})

// Function to process Pub/Sub messages
const processMessage = async (message) => {
  const startTime = Date.now()
  
  try {
    // Parse message data
    const messageData = JSON.parse(message.data.toString())
    const attributes = message.attributes || {}
    
    logger.info('Processing message:', {
      messageId: message.id,
      eventType: attributes.eventType,
      source: attributes.source,
      itemId: messageData.id
    })
    
    // Validate message data
    if (!messageData.id || !messageData.name || !messageData.category) {
      throw new Error('Invalid message data: missing required fields')
    }
    
    // Prepare document for Firestore
    const document = {
      ...messageData,
      processedAt: new Date().toISOString(),
      processedBy: 'microservice-2',
      messageId: message.id,
      messageAttributes: attributes
    }
    
    // Store in Firestore
    const docRef = firestore.collection(COLLECTION_NAME).doc(messageData.id)
    await docRef.set(document, { merge: true })
    
    // Update statistics
    stats.messagesProcessed++
    stats.itemsStored++
    stats.lastProcessed = new Date().toISOString()
    
    const processingTime = Date.now() - startTime
    
    logger.info('Message processed successfully:', {
      messageId: message.id,
      itemId: messageData.id,
      processingTime: `${processingTime}ms`,
      category: messageData.category
    })
    
    // Acknowledge the message
    message.ack()
    
  } catch (error) {
    stats.errors++
    
    logger.error('Error processing message:', {
      messageId: message.id,
      error: error.message,
      stack: error.stack,
      processingTime: `${Date.now() - startTime}ms`
    })
    
    // Nack the message to retry later
    message.nack()
  }
}

// Initialize Pub/Sub subscription
const initializeSubscription = () => {
  const subscription = pubsub.subscription(SUBSCRIPTION_NAME)
  
  // Configure subscription options
  subscription.options = {
    ackDeadlineSeconds: 60,
    maxMessages: 10,
    allowExcessMessages: false,
    maxExtension: 600
  }
  
  // Set up message handler
  subscription.on('message', processMessage)
  
  // Handle subscription errors
  subscription.on('error', (error) => {
    logger.error('Subscription error:', {
      error: error.message,
      stack: error.stack
    })
    stats.errors++
  })
  
  // Handle subscription close
  subscription.on('close', () => {
    logger.info('Subscription closed')
  })
  
  logger.info('Pub/Sub subscription initialized:', {
    subscriptionName: SUBSCRIPTION_NAME,
    options: subscription.options
  })
  
  return subscription
}

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', {
    requestId: req.id,
    error: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method
  })

  res.status(500).json({
    error: 'Internal server error',
    requestId: req.id
  })
})

// 404 handler
app.use('*', (req, res) => {
  logger.warn('Route not found:', {
    requestId: req.id,
    url: req.url,
    method: req.method
  })
  
  res.status(404).json({
    error: 'Route not found',
    requestId: req.id
  })
})

// Graceful shutdown
let subscription
const gracefulShutdown = (signal) => {
  logger.info(`Received ${signal}. Starting graceful shutdown...`)
  
  // Close subscription
  if (subscription) {
    subscription.close()
  }
  
  server.close(() => {
    logger.info('HTTP server closed.')
    
    // Close Google Cloud connections
    Promise.all([
      pubsub.close(),
      firestore.terminate()
    ]).then(() => {
      logger.info('Google Cloud connections closed.')
      process.exit(0)
    }).catch((error) => {
      logger.error('Error closing Google Cloud connections:', error)
      process.exit(1)
    })
  })
}

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
  logger.info(`Microservice 2 started on port ${PORT}`, {
    port: PORT,
    environment: process.env.NODE_ENV || 'development',
    nodeVersion: process.version,
    subscriptionName: SUBSCRIPTION_NAME,
    collectionName: COLLECTION_NAME
  })
  
  // Initialize Pub/Sub subscription
  subscription = initializeSubscription()
})

// Handle graceful shutdown
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'))
process.on('SIGINT', () => gracefulShutdown('SIGINT'))

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', {
    error: error.message,
    stack: error.stack
  })
  process.exit(1)
})

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection:', {
    reason: reason,
    promise: promise
  })
  process.exit(1)
})

module.exports = app
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/microservice-1/Dockerfile
FILE_CONTENT_START
FROM node:18-alpine AS base

WORKDIR /app

RUN apk add --no-cache dumb-init

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 -G nodejs

FROM base AS deps

COPY package*.json ./

RUN npm ci --only=production && \
    npm cache clean --force

FROM base AS builder

COPY package*.json ./

RUN npm ci --silent

COPY . .

RUN npm run lint

FROM base AS production

ENV NODE_ENV=production
ENV PORT=3000

COPY --from=deps --chown=nextjs:nodejs /app/node_modules ./node_modules

COPY --chown=nextjs:nodejs . .

RUN rm -rf tests/ *.test.js *.spec.js .eslintrc.js

LABEL maintainer="DogfyDiet Platform Team"
LABEL version="1.0.0"
LABEL description="DogfyDiet Microservice 1 - API Gateway and Publisher"

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js || exit 1

RUN echo 'const http = require("http"); \
const options = { hostname: "localhost", port: 3000, path: "/health", timeout: 2000 }; \
const req = http.request(options, (res) => { \
  process.exit(res.statusCode === 200 ? 0 : 1); \
}); \
req.on("error", () => process.exit(1)); \
req.end();' > healthcheck.js

USER nextjs

EXPOSE 3000

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/index.js"]
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/microservice-1/package.json
FILE_CONTENT_START
{
  "name": "dogfydiet-microservice-1",
  "version": "1.0.0",
  "description": "DogfyDiet Microservice 1 - API Gateway and Publisher",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "lint": "eslint src/",
    "lint:fix": "eslint src/ --fix",
    "docker:build": "docker build -t microservice-1 .",
    "docker:run": "docker run -p 3000:3000 microservice-1"
  },
  "dependencies": {
    "@google-cloud/logging": "^10.5.0",
    "@google-cloud/monitoring": "^4.0.0",
    "@google-cloud/pubsub": "^4.0.7",
    "@google-cloud/trace-agent": "^7.1.0",
    "compression": "^1.7.4",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "express-rate-limit": "^6.10.0",
    "express-validator": "^7.0.1",
    "helmet": "^7.0.0",
    "joi": "^17.10.1",
    "morgan": "^1.10.0",
    "uuid": "^9.0.0",
    "winston": "^3.10.0"
  },
  "devDependencies": {
    "eslint": "^8.49.0",
    "eslint-config-standard": "^17.1.0",
    "eslint-plugin-import": "^2.28.1",
    "eslint-plugin-node": "^11.1.0",
    "eslint-plugin-promise": "^6.1.1",
    "jest": "^29.7.0",
    "nodemon": "^3.0.1",
    "supertest": "^6.3.3"
  },
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=8.0.0"
  },
  "keywords": [
    "microservice",
    "api",
    "pubsub",
    "google-cloud",
    "express"
  ],
  "author": "DogfyDiet Platform Team",
  "license": "UNLICENSED"
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/microservice-1/src/index.js
FILE_CONTENT_START
const express = require('express')
const cors = require('cors')
const helmet = require('helmet')
const compression = require('compression')
const morgan = require('morgan')
const rateLimit = require('express-rate-limit')
const { body, validationResult } = require('express-validator')
const { PubSub } = require('@google-cloud/pubsub')
const winston = require('winston')
require('dotenv').config()

// Initialize Google Cloud Tracing (must be before other imports)
if (process.env.GOOGLE_CLOUD_PROJECT) {
  require('@google-cloud/trace-agent').start()
}

// Configure Winston logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { 
    service: 'microservice-1',
    version: process.env.npm_package_version || '1.0.0'
  },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
})

// Initialize Express app
const app = express()
const PORT = process.env.PORT || 3000

// Initialize Pub/Sub client
const pubsub = new PubSub({
  projectId: process.env.GOOGLE_CLOUD_PROJECT || 'nahuelgabe-test'
})

const TOPIC_NAME = process.env.PUBSUB_TOPIC || 'dogfydiet-dev-items-topic'

// Middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"]
    }
  }
}))

app.use(compression())
app.use(express.json({ limit: '10mb' }))
app.use(express.urlencoded({ extended: true, limit: '10mb' }))

// CORS configuration
app.use(cors({
  origin: process.env.CORS_ORIGIN || ['http://localhost:8080', 'https://*.googleapis.com'],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  credentials: true
}))

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: process.env.RATE_LIMIT || 100, // limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests from this IP, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false
})

app.use('/api/', limiter)

// Logging middleware
app.use(morgan('combined', {
  stream: {
    write: (message) => logger.info(message.trim())
  }
}))

// Request ID middleware
app.use((req, res, next) => {
  req.id = require('crypto').randomUUID()
  res.setHeader('X-Request-ID', req.id)
  next()
})

// Health check endpoint
app.get('/health', (req, res) => {
  const healthStatus = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'microservice-1',
    version: process.env.npm_package_version || '1.0.0',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    environment: process.env.NODE_ENV || 'development'
  }
  
  res.status(200).json(healthStatus)
})

// Readiness check endpoint
app.get('/ready', async (req, res) => {
  try {
    // Check Pub/Sub connectivity
    const topic = pubsub.topic(TOPIC_NAME)
    await topic.exists()
    
    res.status(200).json({
      status: 'ready',
      timestamp: new Date().toISOString(),
      checks: {
        pubsub: 'connected'
      }
    })
  } catch (error) {
    logger.error('Readiness check failed:', error)
    res.status(503).json({
      status: 'not ready',
      timestamp: new Date().toISOString(),
      error: error.message
    })
  }
})

// Metrics endpoint for monitoring
app.get('/metrics', (req, res) => {
  const metrics = {
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    cpu: process.cpuUsage(),
    environment: process.env.NODE_ENV || 'development',
    nodejs_version: process.version
  }
  
  res.status(200).json(metrics)
})

// Validation middleware for items
const validateItem = [
  body('name')
    .isLength({ min: 1, max: 100 })
    .trim()
    .escape()
    .withMessage('Name must be between 1 and 100 characters'),
  body('category')
    .isIn(['treats', 'food', 'supplements', 'toys'])
    .withMessage('Category must be one of: treats, food, supplements, toys'),
  body('description')
    .optional()
    .isLength({ max: 500 })
    .trim()
    .escape()
    .withMessage('Description must be less than 500 characters')
]

// API Routes

// Get items endpoint (for frontend compatibility)
app.get('/api/items', async (req, res) => {
  try {
    // This is a simple in-memory store for demo purposes
    // In production, this would typically come from a database or cache
    const items = req.app.locals.items || []
    
    logger.info(`Retrieved ${items.length} items`, {
      requestId: req.id,
      count: items.length
    })
    
    res.status(200).json(items)
  } catch (error) {
    logger.error('Error retrieving items:', {
      requestId: req.id,
      error: error.message,
      stack: error.stack
    })
    
    res.status(500).json({
      error: 'Internal server error',
      requestId: req.id
    })
  }
})

// Create item endpoint
app.post('/api/items', validateItem, async (req, res) => {
  try {
    // Check validation results
    const errors = validationResult(req)
    if (!errors.isEmpty()) {
      logger.warn('Validation failed:', {
        requestId: req.id,
        errors: errors.array()
      })
      
      return res.status(400).json({
        error: 'Validation failed',
        details: errors.array(),
        requestId: req.id
      })
    }

    const itemData = {
      id: require('crypto').randomUUID(),
      name: req.body.name,
      category: req.body.category,
      description: req.body.description || '',
      timestamp: new Date().toISOString(),
      source: 'microservice-1',
      requestId: req.id
    }

    // Store item locally for GET requests (demo purposes)
    if (!req.app.locals.items) {
      req.app.locals.items = []
    }
    req.app.locals.items.unshift(itemData)

    // Publish message to Pub/Sub
    const topic = pubsub.topic(TOPIC_NAME)
    const messageData = Buffer.from(JSON.stringify(itemData))
    
    const messageId = await topic.publishMessage({
      data: messageData,
      attributes: {
        eventType: 'item.created',
        source: 'microservice-1',
        version: '1.0',
        timestamp: itemData.timestamp,
        requestId: req.id
      }
    })

    logger.info('Item created and published:', {
      requestId: req.id,
      itemId: itemData.id,
      messageId: messageId,
      category: itemData.category
    })

    res.status(201).json({
      success: true,
      data: itemData,
      messageId: messageId,
      requestId: req.id
    })

  } catch (error) {
    logger.error('Error creating item:', {
      requestId: req.id,
      error: error.message,
      stack: error.stack
    })

    res.status(500).json({
      error: 'Failed to create item',
      requestId: req.id
    })
  }
})

// API documentation endpoint
app.get('/api/docs', (req, res) => {
  const apiDocs = {
    name: 'DogfyDiet Microservice 1 API',
    version: '1.0.0',
    description: 'API Gateway and Publisher service for DogfyDiet platform',
    endpoints: {
      'GET /health': 'Health check endpoint',
      'GET /ready': 'Readiness check endpoint', 
      'GET /metrics': 'Metrics endpoint for monitoring',
      'GET /api/items': 'Retrieve all items',
      'POST /api/items': 'Create a new item and publish to Pub/Sub',
      'GET /api/docs': 'This documentation'
    },
    schemas: {
      item: {
        id: 'string (UUID)',
        name: 'string (1-100 chars)',
        category: 'string (treats|food|supplements|toys)',
        description: 'string (optional, max 500 chars)',
        timestamp: 'string (ISO 8601)',
        source: 'string',
        requestId: 'string (UUID)'
      }
    }
  }
  
  res.status(200).json(apiDocs)
})

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', {
    requestId: req.id,
    error: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method
  })

  res.status(500).json({
    error: 'Internal server error',
    requestId: req.id
  })
})

// 404 handler
app.use('*', (req, res) => {
  logger.warn('Route not found:', {
    requestId: req.id,
    url: req.url,
    method: req.method
  })
  
  res.status(404).json({
    error: 'Route not found',
    requestId: req.id
  })
})

// Graceful shutdown
const gracefulShutdown = (signal) => {
  logger.info(`Received ${signal}. Starting graceful shutdown...`)
  
  server.close(() => {
    logger.info('HTTP server closed.')
    
    // Close Pub/Sub connections
    pubsub.close().then(() => {
      logger.info('Pub/Sub connections closed.')
      process.exit(0)
    }).catch((error) => {
      logger.error('Error closing Pub/Sub connections:', error)
      process.exit(1)
    })
  })
}

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
  logger.info(`Microservice 1 started on port ${PORT}`, {
    port: PORT,
    environment: process.env.NODE_ENV || 'development',
    nodeVersion: process.version,
    pubsubTopic: TOPIC_NAME
  })
})

// Handle graceful shutdown
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'))
process.on('SIGINT', () => gracefulShutdown('SIGINT'))

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', {
    error: error.message,
    stack: error.stack
  })
  process.exit(1)
})

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection:', {
    reason: reason,
    promise: promise
  })
  process.exit(1)
})

module.exports = app
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./all.md
FILE_CONTENT_START
FILE_PATH_START
./terraform/environments/dev/outputs.tf
FILE_CONTENT_START
# Network Outputs
output "vpc_network_name" {
  description = "The name of the VPC network"
  value       = module.vpc.network_name
}

output "vpc_network_self_link" {
  description = "The self-link of the VPC network"
  value       = module.vpc.network_self_link
}

output "private_subnet_name" {
  description = "The name of the private subnet"
  value       = module.vpc.private_subnet_name
}

output "public_subnet_name" {
  description = "The name of the public subnet"
  value       = module.vpc.public_subnet_name
}

# GKE Outputs
output "gke_cluster_name" {
  description = "The name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "The endpoint of the GKE cluster"
  value       = module.gke.endpoint
  sensitive   = true
}

output "gke_cluster_ca_certificate" {
  description = "The CA certificate of the GKE cluster"
  value       = module.gke.ca_certificate
  sensitive   = true
}

output "gke_cluster_location" {
  description = "The location of the GKE cluster"
  value       = module.gke.location
}

# Storage Outputs
output "frontend_bucket_name" {
  description = "The name of the frontend storage bucket"
  value       = module.storage.frontend_bucket_name
}

output "frontend_bucket_url" {
  description = "The URL of the frontend storage bucket"
  value       = module.storage.frontend_bucket_url
}

# Load Balancer Outputs
output "load_balancer_ip" {
  description = "The static IP address of the load balancer"
  value       = module.loadbalancer.load_balancer_ip
}

output "load_balancer_url" {
  description = "The URL to access the application via load balancer"
  value       = module.loadbalancer.load_balancer_url
}

output "frontend_url" {
  description = "The URL to access the frontend application"
  value       = "http://${module.loadbalancer.load_balancer_ip}"
}

# Pub/Sub Outputs
output "pubsub_topic_name" {
  description = "The name of the Pub/Sub topic"
  value       = module.pubsub.topic_name
}

output "pubsub_subscription_name" {
  description = "The name of the Pub/Sub subscription"
  value       = module.pubsub.subscription_name
}

# Firestore Outputs
output "firestore_database_name" {
  description = "The name of the Firestore database"
  value       = module.firestore.database_name
}

# IAM Outputs
output "microservice_1_service_account" {
  description = "Service account email for microservice 1"
  value       = module.iam.microservice_1_service_account
}

output "microservice_2_service_account" {
  description = "Service account email for microservice 2"
  value       = module.iam.microservice_2_service_account
}

output "docker_repository_url" {
  description = "URL of the Docker repository"
  value       = module.iam.docker_repository_url
}

# Monitoring Outputs
output "monitoring_notification_channel" {
  description = "Monitoring notification channel ID"
  value       = module.monitoring.notification_channel_id
}

# kubectl configuration command
output "kubectl_config" {
  description = "Command to configure kubectl"
  value       = module.gke.kubectl_config
}

# Important URLs and commands
output "setup_instructions" {
  description = "Post-deployment setup instructions"
  value       = <<-EOT
    
    ========================================
    🚀 DogfyDiet Platform Deployment Complete!
    ========================================
    
    Frontend URL: http://${module.loadbalancer.load_balancer_ip}
    Frontend Bucket: ${module.storage.frontend_bucket_name}
    
    To configure kubectl:
    ${module.gke.kubectl_config}
    
    To deploy applications:
    1. Update GitHub secret FRONTEND_BUCKET_NAME with: ${module.storage.frontend_bucket_name}
    2. Update GitHub secret API_URL with: http://${module.loadbalancer.load_balancer_ip}/api
    3. Push changes to trigger CI/CD pipeline
    
    To access the frontend directly via bucket:
    ${module.storage.frontend_bucket_website_url}
    
  EOT
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/environments/dev/main.tf
FILE_CONTENT_START
terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "gcs" {
    bucket = "nahuelgabe-test-terraform-state"
    prefix = "dogfydiet-platform/dev"
  }
}

# Configure providers
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Data sources
data "google_client_config" "default" {}

# Conditional provider configuration
# Only configure if cluster exists
provider "kubernetes" {
  host                   = try("https://${module.gke.endpoint}", "")
  token                  = try(data.google_client_config.default.access_token, "")
  cluster_ca_certificate = try(base64decode(module.gke.ca_certificate), "")
}

provider "helm" {
  kubernetes {
    host                   = try("https://${module.gke.endpoint}", "")
    token                  = try(data.google_client_config.default.access_token, "")
    cluster_ca_certificate = try(base64decode(module.gke.ca_certificate), "")
  }
}

locals {
  environment = var.environment
  project     = var.project_name

  common_labels = {
    environment = local.environment
    project     = local.project
    managed_by  = "terraform"
  }

  # Naming convention: {project}-{environment}-{resource}
  name_prefix = "${local.project}-${local.environment}"
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix
  environment = local.environment

  private_subnet_cidr = var.private_subnet_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  pods_cidr_range     = var.pods_cidr_range
  services_cidr_range = var.services_cidr_range
  gke_master_cidr     = var.gke_master_cidr

  labels = local.common_labels
}

##### NEW FIREWALL RULE #####
# Firewall rule to allow health checks from Google Cloud Load Balancer to GKE Nodes
resource "google_compute_firewall" "allow_lb_health_checks_to_gke_nodes" {
  project = var.project_id
  name    = "${local.name_prefix}-allow-lb-hc-gke" # e.g., dogfydiet-dev-allow-lb-hc-gke
  network = module.vpc.network_name               # Uses the network created by the vpc module

  description = "Allow health checks from GCP Load Balancer to GKE worker nodes"

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  # Google Cloud health checker IP ranges
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]

  # Target GKE nodes using the tag applied by your GKE module.
  target_tags = ["${local.name_prefix}-gke-node"] # e.g., dogfydiet-dev-gke-node

  priority = 1000 # Standard priority

  depends_on = [module.vpc] # Ensure VPC is created first
}



# GKE Module
module "gke" {
  source = "../../modules/gke"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix
  environment = local.environment

  network_name           = module.vpc.network_name
  subnet_name            = module.vpc.private_subnet_name
  master_ipv4_cidr_block = var.gke_master_cidr

  min_node_count    = var.gke_min_node_count
  max_node_count    = var.gke_max_node_count
  node_machine_type = var.gke_node_machine_type
  node_disk_size_gb = var.gke_node_disk_size

  labels = local.common_labels

  depends_on = [module.vpc]
}

# Cloud Storage Module for Frontend
module "storage" {
  source = "../../modules/storage"

  project_id  = var.project_id
  name_prefix = local.name_prefix
  environment = local.environment

  # CDN configuration
  enable_cdn      = true
  cdn_default_ttl = 3600
  cdn_max_ttl     = 86400

  labels = local.common_labels
}

# Load Balancer Module
module "loadbalancer" {
  source = "../../modules/loadbalancer"

  project_id  = var.project_id
  name_prefix = local.name_prefix
  environment = local.environment

  # Backend configuration
  default_backend_service = module.storage.backend_bucket_self_link # This is for GCS (frontend)

  # HTTPS configuration
  enable_https               = true
  create_managed_certificate = true
  ssl_certificates = [module.loadbalancer.ssl_certificate_self_link]
  managed_certificate_domains = ["nahueldog.duckdns.org"]

  # --- START: Pass GKE backend variables ---
  enable_gke_backend            = true                                                                                          # Enable the GKE backend
  gke_neg_name = "k8s1-98d6217d-default-microservice-1-80-247119ef"
  gke_neg_zone = "us-central1-c"
  gke_backend_service_port_name = "http"                                                                                        # Matches the port name in your microservice-1 k8s Service
  gke_health_check_port         = 3000                                                                                          # Port for microservice-1 health check
  gke_health_check_request_path = "/health"                                                                                     # Path for microservice-1 health check
  # --- END: Pass GKE backend variables ---




  # Cloud Armor configuration (disabled for dev)
  enable_cloud_armor   = false
  enable_rate_limiting = false

  labels = local.common_labels

  depends_on = [module.storage, module.gke] # Added module.gke dependency
}

# Pub/Sub Module
module "pubsub" {
  source = "../../modules/pubsub"

  project_id  = var.project_id
  name_prefix = local.name_prefix
  environment = local.environment

  labels = local.common_labels
}

# Firestore Module
module "firestore" {
  source = "../../modules/firestore"

  project_id  = var.project_id
  name_prefix = local.name_prefix
  environment = local.environment

  labels = local.common_labels
}

# IAM Module
module "iam" {
  source = "../../modules/iam"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix
  environment = local.environment

  gke_cluster_name = module.gke.cluster_name
  # Disable workload identity bindings until GKE cluster is created
  enable_workload_identity = false

  labels = local.common_labels

  depends_on = [module.gke]
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"

  project_id  = var.project_id
  name_prefix = local.name_prefix
  environment = local.environment

  gke_cluster_name   = module.gke.cluster_name
  notification_email = var.notification_email

  labels = local.common_labels

  depends_on = [module.gke]
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/environments/dev/terraform.tfvars
FILE_CONTENT_START
# Project Configuration
project_id   = "nahuelgabe-test"
project_name = "dogfydiet"
environment  = "dev"

# Regional Configuration
region = "us-central1"
zone   = "us-central1-a"

# Network Configuration
vpc_cidr            = "10.0.0.0/16"
private_subnet_cidr = "10.0.1.0/24"
public_subnet_cidr  = "10.0.2.0/24"
pods_cidr_range     = "10.1.0.0/16"
services_cidr_range = "10.2.0.0/16"
gke_master_cidr     = "172.16.0.0/28"

# GKE Cluster Configuration
gke_node_count        = 2
gke_node_machine_type = "e2-standard-2"
gke_node_disk_size    = 50
gke_max_node_count    = 5
gke_min_node_count    = 1

# Monitoring Configuration (change test)
notification_email = "nahuelgavilanbe@gmail.com"
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/environments/dev/variables.tf
FILE_CONTENT_START
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
  default     = "nahuel@example.com" # Update with your email
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

# In ./environments/dev/variables.tf
# ... (other variables)

variable "k8s_namespace_for_ms1_helm_chart" {
  description = "Kubernetes namespace where microservice-1 is deployed (used for NEG naming)."
  type        = string
  default     = "default" # Or whatever namespace you use in your Helm chart for microservice-1
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/firestore/outputs.tf
FILE_CONTENT_START
output "database_name" {
  description = "The name of the Firestore database"
  value       = google_firestore_database.main.name
}

output "database_id" {
  description = "The ID of the Firestore database"
  value       = google_firestore_database.main.id
}

output "app_engine_application_id" {
  description = "The App Engine application ID"
  value       = google_app_engine_application.default.app_id
}

output "firestore_location" {
  description = "The location of the Firestore database"
  value       = var.firestore_location
}

output "database_connection_string" {
  description = "Connection string for the Firestore database"
  value       = "projects/${var.project_id}/databases/${google_firestore_database.main.name}"
}

output "backup_schedule_name" {
  description = "The name of the backup schedule (if enabled)"
  value       = var.enable_backup ? google_firestore_backup_schedule.main[0].name : ""
}

output "security_rules_deployed" {
  description = "Whether security rules have been deployed"
  value       = var.deploy_security_rules
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/firestore/main.tf
FILE_CONTENT_START
# Enable required APIs
resource "google_project_service" "firestore" {
  service            = "firestore.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "appengine" {
  service            = "appengine.googleapis.com"
  disable_on_destroy = false
}

# App Engine application (required for Firestore)
resource "google_app_engine_application" "default" {
  project     = var.project_id
  location_id = var.app_engine_location
  # database_type = "CLOUD_FIRESTORE"

  depends_on = [
    google_project_service.appengine,
    google_project_service.firestore
  ]
}

# Firestore Database
resource "google_firestore_database" "main" {
  project                           = var.project_id
  name                              = var.database_name
  location_id                       = var.firestore_location
  type                              = var.database_type
  concurrency_mode                  = var.concurrency_mode
  app_engine_integration_mode       = var.app_engine_integration_mode
  point_in_time_recovery_enablement = var.enable_point_in_time_recovery ? "POINT_IN_TIME_RECOVERY_ENABLED" : "POINT_IN_TIME_RECOVERY_DISABLED"
  delete_protection_state           = var.enable_delete_protection ? "DELETE_PROTECTION_ENABLED" : "DELETE_PROTECTION_DISABLED"

  depends_on = [google_app_engine_application.default]
}

# Firestore Backup Schedule
resource "google_firestore_backup_schedule" "main" {
  count = var.enable_backup ? 1 : 0

  project  = var.project_id
  database = google_firestore_database.main.name

  retention = var.backup_retention

  dynamic "daily_recurrence" {
    for_each = var.backup_frequency == "daily" ? [1] : []
    content {}
  }

  dynamic "weekly_recurrence" {
    for_each = var.backup_frequency == "weekly" ? [1] : []
    content {
      day = var.backup_day
    }
  }
}

# IAM bindings for service accounts
resource "google_project_iam_member" "firestore_user" {
  for_each = toset(var.firestore_users)

  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${each.value}"
}

resource "google_project_iam_member" "firestore_viewer" {
  for_each = toset(var.firestore_viewers)

  project = var.project_id
  role    = "roles/datastore.viewer"
  member  = "serviceAccount:${each.value}"
}

# Security Rules (basic rules for development)
resource "google_firebaserules_ruleset" "firestore" {
  count = var.deploy_security_rules ? 1 : 0

  project = var.project_id

  source {
    files {
      content = var.security_rules_content
      name    = "firestore.rules"
    }
  }

  depends_on = [google_firestore_database.main]
}

resource "google_firebaserules_release" "firestore" {
  count = var.deploy_security_rules ? 1 : 0

  name         = "cloud.firestore"
  ruleset_name = google_firebaserules_ruleset.firestore[0].name
  project      = var.project_id

  depends_on = [google_firebaserules_ruleset.firestore]
}

# Monitoring alerts for Firestore
resource "google_monitoring_alert_policy" "firestore_read_ops" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "${var.name_prefix} Firestore Read Operations"

  documentation {
    content = "Alert when Firestore read operations exceed threshold"
  }

  conditions {
    display_name = "High read operations"

    condition_threshold {
      filter          = "resource.type=\"firestore.googleapis.com/Database\" AND resource.labels.database_id=\"${google_firestore_database.main.name}\" AND metric.type=\"firestore.googleapis.com/document/read_ops_count\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.read_ops_threshold

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  combiner              = "OR"
  enabled               = true
  notification_channels = var.notification_channels
}

resource "google_monitoring_alert_policy" "firestore_write_ops" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "${var.name_prefix} Firestore Write Operations"

  documentation {
    content = "Alert when Firestore write operations exceed threshold"
  }

  conditions {
    display_name = "High write operations"

    condition_threshold {
      filter          = "resource.type=\"firestore.googleapis.com/Database\" AND resource.labels.database_id=\"${google_firestore_database.main.name}\" AND metric.type=\"firestore.googleapis.com/document/write_ops_count\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.write_ops_threshold

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  combiner              = "OR"
  enabled               = true
  notification_channels = var.notification_channels
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/firestore/variables.tf
FILE_CONTENT_START
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
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/loadbalancer/outputs.tf
FILE_CONTENT_START
output "load_balancer_ip" {
  description = "The IP address of the load balancer"
  value       = google_compute_global_address.main.address
}

output "load_balancer_ip_name" {
  description = "The name of the load balancer IP address resource"
  value       = google_compute_global_address.main.name
}

output "load_balancer_ip_self_link" {
  description = "The self-link of the load balancer IP address"
  value       = google_compute_global_address.main.self_link
}

output "url_map_id" {
  description = "The ID of the URL map"
  value       = google_compute_url_map.main.id
}

output "url_map_self_link" {
  description = "The self-link of the URL map"
  value       = google_compute_url_map.main.self_link
}

output "http_proxy_id" {
  description = "The ID of the HTTP proxy"
  value       = google_compute_target_http_proxy.main.id
}

output "https_proxy_id" {
  description = "The ID of the HTTPS proxy (if enabled)"
  value       = var.enable_https ? google_compute_target_https_proxy.main[0].id : null
}

output "http_forwarding_rule_id" {
  description = "The ID of the HTTP forwarding rule"
  value       = google_compute_global_forwarding_rule.http.id
}

output "https_forwarding_rule_id" {
  description = "The ID of the HTTPS forwarding rule (if enabled)"
  value       = var.enable_https ? google_compute_global_forwarding_rule.https[0].id : null
}

output "ssl_certificate_id" {
  description = "The ID of the managed SSL certificate (if created)"
  value       = var.enable_https && var.create_managed_certificate ? google_compute_managed_ssl_certificate.main[0].id : null
}

output "ssl_certificate_self_link" {
  description = "The self-link of the managed SSL certificate (if created)"
  value       = var.enable_https && var.create_managed_certificate ? google_compute_managed_ssl_certificate.main[0].self_link : null
}

output "ssl_policy_id" {
  description = "The ID of the SSL policy (if created)"
  value       = var.enable_https && var.create_ssl_policy ? google_compute_ssl_policy.main[0].id : null
}

output "cloud_armor_policy_id" {
  description = "The ID of the Cloud Armor security policy (if enabled)"
  value       = var.enable_cloud_armor ? google_compute_security_policy.main[0].id : null
}

# output "backend_service_id" {
#   description = "The ID of the backend service (if created)"
#   value       = var.create_backend_service ? google_compute_backend_service.main[0].id : null
# }



output "load_balancer_url" {
  description = "The URL to access the load balancer"
  value       = "http://${google_compute_global_address.main.address}"
}

output "load_balancer_https_url" {
  description = "The HTTPS URL to access the load balancer (if enabled)"
  value       = var.enable_https ? "https://${google_compute_global_address.main.address}" : null
}


output "gke_ms1_backend_service_id" {
  description = "The ID of the backend service for Microservice 1 GKE NEG"
  value       = var.enable_gke_backend ? google_compute_backend_service.gke_ms1_backend[0].id : null
}

output "gke_ms1_backend_service_self_link" {
  description = "The self-link of the backend service for Microservice 1 GKE NEG"
  value       = var.enable_gke_backend ? google_compute_backend_service.gke_ms1_backend[0].self_link : null
}

output "gke_ms1_health_check_id" {
  description = "The ID of the health check for Microservice 1 GKE backend"
  value       = var.enable_gke_backend ? google_compute_health_check.gke_ms1_health_check[0].id : null
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/loadbalancer/main.tf
FILE_CONTENT_START
resource "google_compute_global_address" "main" {
  name         = "${var.name_prefix}-lb-ip"
  description  = "Static IP address for load balancer"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"

  labels = var.labels
}

# --- START: Health Check for GKE Backend (microservice-1) ---
resource "google_compute_health_check" "gke_ms1_health_check" {
  count = var.enable_gke_backend ? 1 : 0

  name                = "${var.name_prefix}-ms1-hc"
  description         = "Health check for Microservice 1"
  check_interval_sec  = 15 # From your backendconfig.yaml
  timeout_sec         = 5  # From your backendconfig.yaml
  healthy_threshold   = 2  # From your backendconfig.yaml
  unhealthy_threshold = 2  # From your backendconfig.yaml

  http_health_check {
    port_specification = "USE_SERVING_PORT" # NEG will provide the port
    request_path       = var.gke_health_check_request_path
  }
}
# --- END: Health Check for GKE Backend (microservice-1) ---

# --- START: Backend Service for GKE NEG (microservice-1) ---
data "google_compute_network_endpoint_group" "gke_ms1_neg" {
  count = var.enable_gke_backend ? 1 : 0

  name    = var.gke_neg_name
  zone    = var.gke_neg_zone # Make sure this is the zone of your GKE cluster/nodes
  project = var.project_id
}

resource "google_compute_backend_service" "gke_ms1_backend" {
  count = var.enable_gke_backend ? 1 : 0

  name                  = "${var.name_prefix}-ms1-backend"
  description           = "Backend service for Microservice 1 (GKE NEG)"
  protocol              = "HTTP"                            # Assuming microservice-1 serves HTTP
  port_name             = var.gke_backend_service_port_name # Should match the service port name in k8s service for ms1
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED" # For Global HTTP(S) LB with NEGs
  enable_cdn            = false              # Usually not needed for API backends

  backend {
    group                 = data.google_compute_network_endpoint_group.gke_ms1_neg[0].self_link
    balancing_mode        = "RATE" # Good for HTTP services
    max_rate_per_endpoint = 100    # Adjust as needed
  }

  health_checks = [google_compute_health_check.gke_ms1_health_check[0].self_link]

  log_config {
    enable      = var.enable_logging
    sample_rate = var.log_sample_rate
  }

  # If you have a BackendConfig for this service in k8s, its settings (like IAP, CDN)
  # are applied by GKE. For Terraform managed backend services with NEGs,
  # you often configure these directly here or leave them to GKE if using `BackendConfig`
  # with the service.
  # If using BackendConfig for IAP, timeout, etc. from GKE, ensure it's correctly associated
  # with the K8s service. For health checks, it's safer to also define it in TF for the backend_service.

  # security_policy = var.enable_cloud_armor ? google_compute_security_policy.main[0].id : null
  # dynamic "iap" {
  #   for_each = var.iap_oauth2_client_id != "" ? [1] : []
  #   content {
  #     oauth2_client_id     = var.iap_oauth2_client_id
  #     oauth2_client_secret = var.iap_oauth2_client_secret
  #   }
  # }
}
# --- END: Backend Service for GKE NEG (microservice-1) ---

resource "google_compute_url_map" "main" {
  name        = "${var.name_prefix}-lb-urlmap"
  description = "URL map for load balancer"
  default_service = var.default_backend_service

  dynamic "host_rule" {
    for_each = var.host_rules
    content {
      hosts        = host_rule.value.hosts
      path_matcher = host_rule.value.path_matcher
    }
  }

  path_matcher {
    name            = "allpaths"
    default_service = var.default_backend_service # GCS bucket

    dynamic "path_rule" {
      for_each = var.enable_gke_backend ? [1] : []
      content {
        paths   = ["/api/*"]
        service = google_compute_backend_service.gke_ms1_backend[0].self_link
      }
    }

    path_rule {
      paths   = ["/*"]
      service = var.default_backend_service
    }
  }
}


# HTTP(S) Load Balancer - HTTPS proxy
resource "google_compute_target_https_proxy" "main" {
  count = var.enable_https ? 1 : 0

  name             = "${var.name_prefix}-lb-https-proxy"
  description      = "HTTPS proxy for load balancer"
  url_map          = google_compute_url_map.main.id
  ssl_certificates = var.ssl_certificates
  ssl_policy       = var.ssl_policy

  quic_override = var.enable_quic ? "ENABLE" : "DISABLE"
}

# For HTTP to HTTPS redirect
resource "google_compute_target_http_proxy" "main" {
  name        = "${var.name_prefix}-lb-http-proxy"
  description = "HTTP proxy for load balancer"
  url_map     = var.enable_https && var.https_redirect ? google_compute_url_map.redirect[0].id : google_compute_url_map.main.id
}

# URL map for HTTP to HTTPS redirect
resource "google_compute_url_map" "redirect" {
  count = var.enable_https && var.https_redirect ? 1 : 0

  name        = "${var.name_prefix}-lb-redirect-urlmap"
  description = "URL map for HTTP to HTTPS redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_global_forwarding_rule" "https" {
  count = var.enable_https ? 1 : 0

  name                  = "${var.name_prefix}-lb-https-forwarding-rule"
  description           = "HTTPS forwarding rule for load balancer"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.main[0].id
  ip_address            = google_compute_global_address.main.id

  labels = var.labels
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.name_prefix}-lb-http-forwarding-rule"
  description           = "HTTP forwarding rule for load balancer"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.main.id
  ip_address            = google_compute_global_address.main.id

  labels = var.labels
}

# SSL Certificate (managed by Google)
resource "google_compute_managed_ssl_certificate" "main" {
  count = var.enable_https && var.create_managed_certificate ? 1 : 0

  name        = "${var.name_prefix}-lb-ssl-cert"
  description = "Managed SSL certificate for load balancer"

  managed {
    domains = var.managed_certificate_domains
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_ssl_policy" "main" {
  count = var.enable_https && var.create_ssl_policy ? 1 : 0

  name            = "${var.name_prefix}-lb-ssl-policy"
  description     = "SSL policy for load balancer"
  profile         = var.ssl_policy_profile
  min_tls_version = var.ssl_policy_min_tls_version
}

resource "google_compute_security_policy" "main" {
  count = var.enable_cloud_armor ? 1 : 0

  name        = "${var.name_prefix}-lb-security-policy"
  description = "Cloud Armor security policy for load balancer"

  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule"
  }

  dynamic "rule" {
    for_each = var.enable_rate_limiting ? [1] : []
    content {
      action   = "rate_based_ban"
      priority = "1000"
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = ["*"]
        }
      }
      rate_limit_options {
        conform_action = "allow"
        exceed_action  = "deny(429)"
        rate_limit_threshold {
          count        = var.rate_limit_threshold
          interval_sec = var.rate_limit_interval
        }
        ban_duration_sec = var.rate_limit_ban_duration
      }
      description = "Rate limiting rule"
    }
  }

  dynamic "rule" {
    for_each = var.cloud_armor_rules
    content {
      action   = rule.value.action
      priority = rule.value.priority
      match {
        versioned_expr = rule.value.versioned_expr
        config {
          src_ip_ranges = rule.value.src_ip_ranges
        }
      }
      description = rule.value.description
    }
  }
}

# resource "google_compute_backend_service" "main" {
#   count = var.create_backend_service ? 1 : 0

#   name        = "${var.name_prefix}-lb-backend-service"
#   description = "Backend service for load balancer"

#   protocol    = var.backend_protocol
#   port_name   = var.backend_port_name
#   timeout_sec = var.backend_timeout

#   health_checks = var.health_checks

#   security_policy = var.enable_cloud_armor ? google_compute_security_policy.main[0].id : null

#   log_config {
#     enable      = var.enable_logging
#     sample_rate = var.log_sample_rate
#   }

#   iap {
#     oauth2_client_id     = var.iap_oauth2_client_id
#     oauth2_client_secret = var.iap_oauth2_client_secret
#   }
# }
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/loadbalancer/variables.tf
FILE_CONTENT_START
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

# New variables for GKE Backend
variable "enable_gke_backend" {
  description = "Whether to enable the GKE backend service for microservice-1"
  type        = bool
  default     = false # Set to true in  dev.tfvars / main.tf module call
}

variable "gke_neg_name" {
  description = "The name of the Network Endpoint Group for microservice-1. This is typically auto-generated by GKE."
  type        = string
}

variable "gke_neg_zone" {
  description = "The zone where the GKE NEG for microservice-1 is located."
  type        = string
}

variable "gke_backend_service_port_name" {
  description = "The port name for the GKE backend service (should match service port name)."
  type        = string
  default     = "http" # This should match the 'name: http' in your k8s service and deployment port
}

variable "gke_health_check_port" {
  description = "Port for the GKE backend health check. Should match microservice-1 containerPort."
  type        = number
  default     = 3000
}

variable "gke_health_check_request_path" {
  description = "Request path for GKE backend health check."
  type        = string
  default     = "/health" # Aligns with your microservice-1 backendconfig.yaml
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/storage/outputs.tf
FILE_CONTENT_START
output "frontend_bucket_name" {
  description = "The name of the frontend storage bucket"
  value       = google_storage_bucket.frontend.name
}

output "frontend_bucket_url" {
  description = "The URL of the frontend storage bucket"
  value       = google_storage_bucket.frontend.url
}

output "frontend_bucket_self_link" {
  description = "The self-link of the frontend storage bucket"
  value       = google_storage_bucket.frontend.self_link
}

output "frontend_bucket_website_url" {
  description = "The website URL of the frontend storage bucket"
  value       = "https://storage.googleapis.com/${google_storage_bucket.frontend.name}/index.html"
}

output "backend_bucket_id" {
  description = "The ID of the backend bucket resource"
  value       = google_compute_backend_bucket.frontend.id
}

output "backend_bucket_self_link" {
  description = "The self-link of the backend bucket"
  value       = google_compute_backend_bucket.frontend.self_link
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/storage/main.tf
FILE_CONTENT_START
# Enable required APIs
resource "google_project_service" "storage" {
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

# Frontend hosting bucket
resource "google_storage_bucket" "frontend" {
  name          = "${var.name_prefix}-frontend-${random_id.bucket_suffix.hex}"
  location      = var.bucket_location
  force_destroy = var.force_destroy

  # Website configuration
  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

  # CORS configuration for SPA
  cors {
    origin          = var.cors_origins
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  versioning {
    enabled = var.enable_versioning
  }

  lifecycle_rule {
    condition {
      age = var.object_lifecycle_days
    }
    action {
      type = "Delete"
    }
  }

  public_access_prevention = "inherited"

  uniform_bucket_level_access = true

  labels = var.labels

  depends_on = [google_project_service.storage]
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.frontend.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_compute_backend_bucket" "frontend" {
  name        = "${var.name_prefix}-frontend-backend"
  description = "Backend bucket for frontend static files"
  bucket_name = google_storage_bucket.frontend.name

  enable_cdn = var.enable_cdn

  dynamic "cdn_policy" {
    for_each = var.enable_cdn ? [1] : []
    content {
      cache_mode        = "CACHE_ALL_STATIC"
      default_ttl       = var.cdn_default_ttl
      max_ttl           = var.cdn_max_ttl
      client_ttl        = var.cdn_client_ttl
      negative_caching  = true
      serve_while_stale = 86400

      negative_caching_policy {
        code = 404
        ttl  = 120
      }

      negative_caching_policy {
        code = 410
        ttl  = 120
      }
    }
  }
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/storage/variables.tf
FILE_CONTENT_START
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
  default     = true # Set to false in production
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
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/iam/outputs.tf
FILE_CONTENT_START
output "microservice_1_service_account" {
  description = "Email of the microservice 1 service account"
  value       = google_service_account.microservice_1.email
}

output "microservice_2_service_account" {
  description = "Email of the microservice 2 service account"
  value       = google_service_account.microservice_2.email
}

output "cicd_service_account" {
  description = "Email of the CI/CD service account"
  value       = google_service_account.cicd.email
}

output "artifact_registry_repository" {
  description = "Name of the Artifact Registry repository"
  value       = google_artifact_registry_repository.main.name
}

output "artifact_registry_location" {
  description = "Location of the Artifact Registry repository"
  value       = google_artifact_registry_repository.main.location
}

output "docker_repository_url" {
  description = "URL of the Docker repository"
  value       = "${google_artifact_registry_repository.main.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}"
}

# CI/CD Service Account Key (sensitive)
output "cicd_service_account_key" {
  description = "Base64 encoded private key for CI/CD service account"
  value       = google_service_account_key.cicd_key.private_key
  sensitive   = true
}

# Secret Manager secret names
output "microservice_1_secret_name" {
  description = "Name of the Secret Manager secret for microservice 1"
  value       = google_secret_manager_secret.microservice_1_sa.secret_id
}

output "microservice_2_secret_name" {
  description = "Name of the Secret Manager secret for microservice 2"
  value       = google_secret_manager_secret.microservice_2_sa.secret_id
}

# Service account keys (sensitive)
output "microservice_1_service_account_key" {
  description = "Base64 encoded private key for microservice 1 service account"
  value       = google_service_account_key.microservice_1_key.private_key
  sensitive   = true
}

output "microservice_2_service_account_key" {
  description = "Base64 encoded private key for microservice 2 service account"
  value       = google_service_account_key.microservice_2_key.private_key
  sensitive   = true
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/iam/main.tf
FILE_CONTENT_START
# Service Account for Microservice 1 (Publisher)
resource "google_service_account" "microservice_1" {
  account_id   = "${var.name_prefix}-microservice-1"
  display_name = "Microservice 1 Service Account"
  description  = "Service account for microservice 1 in ${var.environment} environment"
}

# Service Account for Microservice 2 (Subscriber)
resource "google_service_account" "microservice_2" {
  account_id   = "${var.name_prefix}-microservice-2"
  display_name = "Microservice 2 Service Account"
  description  = "Service account for microservice 2 in ${var.environment} environment"
}

# Service Account for CI/CD
resource "google_service_account" "cicd" {
  account_id   = "${var.name_prefix}-cicd"
  display_name = "CI/CD Service Account"
  description  = "Service account for CI/CD pipeline in ${var.environment} environment"
}

# Workload Identity bindings for microservices
resource "google_service_account_iam_binding" "microservice_1_workload_identity" {
  service_account_id = google_service_account.microservice_1.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/microservice-1]"
  ]
}

resource "google_service_account_iam_binding" "microservice_2_workload_identity" {
  service_account_id = google_service_account.microservice_2.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/microservice-2]"
  ]
}

# Microservice 1 IAM permissions (Publisher role for Pub/Sub)
resource "google_project_iam_member" "microservice_1_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.microservice_1.email}"
}

resource "google_project_iam_member" "microservice_1_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.microservice_1.email}"
}

resource "google_project_iam_member" "microservice_1_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.microservice_1.email}"
}

resource "google_project_iam_member" "microservice_1_trace" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.microservice_1.email}"
}

# Microservice 2 IAM permissions (Subscriber role for Pub/Sub, Firestore access)
resource "google_project_iam_member" "microservice_2_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

resource "google_project_iam_member" "microservice_2_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

resource "google_project_iam_member" "microservice_2_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

resource "google_project_iam_member" "microservice_2_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

resource "google_project_iam_member" "microservice_2_trace" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

# CI/CD IAM permissions
resource "google_project_iam_member" "cicd_gke_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# Create service account keys for CI/CD (not recommended for production)
resource "google_service_account_key" "cicd_key" {
  service_account_id = google_service_account.cicd.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Secret Manager secrets for service accounts
resource "google_secret_manager_secret" "microservice_1_sa" {
  secret_id = "${var.name_prefix}-microservice-1-sa"

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "microservice_1_sa" {
  secret      = google_secret_manager_secret.microservice_1_sa.id
  secret_data = base64decode(google_service_account_key.microservice_1_key.private_key)
}

resource "google_secret_manager_secret" "microservice_2_sa" {
  secret_id = "${var.name_prefix}-microservice-2-sa"

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "microservice_2_sa" {
  secret      = google_secret_manager_secret.microservice_2_sa.id
  secret_data = base64decode(google_service_account_key.microservice_2_key.private_key)
}

# Service account keys for microservices (for local development)
resource "google_service_account_key" "microservice_1_key" {
  service_account_id = google_service_account.microservice_1.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

resource "google_service_account_key" "microservice_2_key" {
  service_account_id = google_service_account.microservice_2.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Custom IAM roles for fine-grained permissions
resource "google_project_iam_custom_role" "microservice_minimal" {
  role_id     = "${replace(var.name_prefix, "-", "_")}_microservice_minimal"
  title       = "Microservice Minimal Permissions"
  description = "Minimal permissions required for microservices"

  permissions = [
    "logging.logEntries.create",
    "monitoring.timeSeries.create",
    "cloudtrace.traces.patch"
  ]

  stage = "GA"
}

# Bind custom role to service accounts
resource "google_project_iam_member" "microservice_1_custom" {
  project = var.project_id
  role    = google_project_iam_custom_role.microservice_minimal.id
  member  = "serviceAccount:${google_service_account.microservice_1.email}"
}

resource "google_project_iam_member" "microservice_2_custom" {
  project = var.project_id
  role    = google_project_iam_custom_role.microservice_minimal.id
  member  = "serviceAccount:${google_service_account.microservice_2.email}"
}

# Enable required APIs
resource "google_project_service" "iam" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# Artifact Registry repository for Docker images
resource "google_artifact_registry_repository" "main" {
  location      = var.region
  repository_id = "${var.name_prefix}-docker-repo"
  description   = "Docker repository for ${var.environment} environment"
  format        = "DOCKER"

  labels = var.labels

  depends_on = [google_project_service.artifactregistry]
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/iam/variables.tf
FILE_CONTENT_START
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
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/gke/outputs.tf
FILE_CONTENT_START
output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_id" {
  description = "The ID of the GKE cluster"
  value       = google_container_cluster.primary.id
}

output "endpoint" {
  description = "The endpoint of the GKE cluster"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "ca_certificate" {
  description = "The CA certificate of the GKE cluster"
  value       = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
  sensitive   = true
}

output "location" {
  description = "The location of the GKE cluster"
  value       = google_container_cluster.primary.location
}

output "master_version" {
  description = "The current master version of the GKE cluster"
  value       = google_container_cluster.primary.master_version
}

output "node_version" {
  description = "The current node version of the GKE cluster"
  value       = google_container_cluster.primary.node_version
}

output "node_pool_name" {
  description = "The name of the primary node pool"
  value       = google_container_node_pool.primary.name
}

output "node_service_account" {
  description = "The service account used by GKE nodes"
  value       = google_service_account.gke_nodes.email
}

output "cluster_resource_labels" {
  description = "The resource labels applied to the cluster"
  value       = google_container_cluster.primary.resource_labels
}

# Connection information for kubectl
output "kubectl_config" {
  description = "kubectl configuration command"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location} --project ${var.project_id}"
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/gke/main.tf
FILE_CONTENT_START
# Enable required APIs
resource "google_project_service" "container" {
  project            = var.project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# Service account for GKE nodes
resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-gke-nodes"
  display_name = "GKE Nodes Service Account"
}

# Minimal IAM roles for the service account
resource "google_project_iam_member" "gke_nodes_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# GKE Cluster - Private configuration
resource "google_container_cluster" "primary" {
  project  = var.project_id
  name     = "${var.name_prefix}-cluster"
  location = var.region

  # We can't create a cluster with 0 nodes, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Basic network config
  network    = var.network_name
  subnetwork = var.subnet_name

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Set to true for full private, false allows public API access
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # IP allocation policy - REQUIRED for private clusters
  ip_allocation_policy {
    cluster_secondary_range_name  = "${var.name_prefix}-pods"
    services_secondary_range_name = "${var.name_prefix}-services"
  }

  # Master authorized networks - who can access the Kubernetes API
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0" # WARNING: Open to all. Restrict in production!
      display_name = "All networks"
    }
  }

  # Basic addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  # Workload Identity for secure pod-to-GCP service communication
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  depends_on = [
    google_project_service.container,
    google_project_service.compute,
  ]
}

# Node Pool - Private nodes configuration
resource "google_container_node_pool" "primary" {
  project    = var.project_id
  name       = "${var.name_prefix}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.min_node_count

  node_config {
    preemptible     = var.preemptible_nodes
    machine_type    = var.node_machine_type
    disk_size_gb    = var.node_disk_size_gb
    disk_type       = var.node_disk_type
    service_account = google_service_account.gke_nodes.email

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = var.labels
    tags   = ["gke-node", "${var.name_prefix}-gke-node"]

    # Shielded instance for added security
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/gke/variables.tf
FILE_CONTENT_START
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

# Network Configuration
variable "network_name" {
  description = "The name of the VPC network"
  type        = string
}

variable "subnet_name" {
  description = "The name of the subnet"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "The IP range for the GKE master nodes"
  type        = string
  default     = "172.16.0.0/28"
}

# Cluster Configuration
variable "release_channel" {
  description = "The release channel for GKE cluster"
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "Release channel must be one of: RAPID, REGULAR, STABLE."
  }
}

# Node Pool Configuration
variable "min_node_count" {
  description = "Minimum number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes in the node pool"
  type        = number
  default     = 5
}

variable "node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "node_disk_size_gb" {
  description = "Disk size for GKE nodes in GB"
  type        = number
  default     = 50
}

variable "node_disk_type" {
  description = "Disk type for GKE nodes"
  type        = string
  default     = "pd-standard"

  validation {
    condition     = contains(["pd-standard", "pd-ssd", "pd-balanced"], var.node_disk_type)
    error_message = "Disk type must be one of: pd-standard, pd-ssd, pd-balanced."
  }
}

variable "preemptible_nodes" {
  description = "Whether to use preemptible nodes"
  type        = bool
  default     = false
}

variable "node_taints" {
  description = "List of node taints to apply"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/pubsub/outputs.tf
FILE_CONTENT_START
output "topic_name" {
  description = "The name of the Pub/Sub topic"
  value       = google_pubsub_topic.main.name
}

output "topic_id" {
  description = "The ID of the Pub/Sub topic"
  value       = google_pubsub_topic.main.id
}

output "subscription_name" {
  description = "The name of the Pub/Sub subscription"
  value       = google_pubsub_subscription.microservice_2.name
}

output "subscription_id" {
  description = "The ID of the Pub/Sub subscription"
  value       = google_pubsub_subscription.microservice_2.id
}

output "dead_letter_topic_name" {
  description = "The name of the dead letter topic (if enabled)"
  value       = var.enable_dead_letter_queue ? google_pubsub_topic.dead_letter[0].name : ""
}

output "dead_letter_subscription_name" {
  description = "The name of the dead letter subscription (if enabled)"
  value       = var.enable_dead_letter_queue ? google_pubsub_subscription.dead_letter[0].name : ""
}

output "schema_name" {
  description = "The name of the Pub/Sub schema (if created)"
  value       = var.create_schema ? google_pubsub_schema.main[0].name : ""
}

# Connection strings for applications
output "topic_connection_string" {
  description = "Connection string for publishing to the topic"
  value       = "projects/${var.project_id}/topics/${google_pubsub_topic.main.name}"
}

output "subscription_connection_string" {
  description = "Connection string for subscribing to the subscription"
  value       = "projects/${var.project_id}/subscriptions/${google_pubsub_subscription.microservice_2.name}"
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/pubsub/main.tf
FILE_CONTENT_START
# terraform/modules/pubsub/main.tf

# Enable required APIs
resource "google_project_service" "pubsub" {
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

# Pub/Sub Topic for microservices communication
resource "google_pubsub_topic" "main" {
  name = "${var.name_prefix}-items-topic"

  labels = var.labels

  # Message retention duration
  message_retention_duration = var.message_retention_duration

  # Message storage policy
  message_storage_policy {
    allowed_persistence_regions = var.allowed_persistence_regions
  }

  # Schema settings (if schema is provided)
  dynamic "schema_settings" {
    for_each = var.schema_name != "" ? [1] : []
    content {
      schema   = var.schema_name
      encoding = var.schema_encoding
    }
  }

  depends_on = [google_project_service.pubsub]
}

# Pub/Sub Subscription for Microservice 2
resource "google_pubsub_subscription" "microservice_2" {
  name  = "${var.name_prefix}-items-subscription"
  topic = google_pubsub_topic.main.name

  labels = var.labels

  # Acknowledgment deadline
  ack_deadline_seconds = var.ack_deadline_seconds

  # Message retention duration
  message_retention_duration = var.message_retention_duration

  # Retain acknowledged messages
  retain_acked_messages = var.retain_acked_messages

  # Expiration policy
  expiration_policy {
    ttl = var.subscription_ttl
  }

  # Retry policy
  retry_policy {
    minimum_backoff = var.retry_minimum_backoff
    maximum_backoff = var.retry_maximum_backoff
  }

  # Dead letter policy
  dynamic "dead_letter_policy" {
    for_each = var.enable_dead_letter_queue ? [1] : []
    content {
      dead_letter_topic     = google_pubsub_topic.dead_letter[0].id
      max_delivery_attempts = var.max_delivery_attempts
    }
  }

  # Push configuration for HTTP endpoint (if provided)
  dynamic "push_config" {
    for_each = var.push_endpoint != "" ? [1] : []
    content {
      push_endpoint = var.push_endpoint

      attributes = var.push_attributes

      # OIDC token for authentication
      dynamic "oidc_token" {
        for_each = var.oidc_service_account_email != "" ? [1] : []
        content {
          service_account_email = var.oidc_service_account_email
          audience              = var.oidc_audience
        }
      }
    }
  }

  # Enable message ordering
  enable_message_ordering = var.enable_message_ordering

  # Filter for subscription
  filter = var.subscription_filter
}

# Dead Letter Topic (if enabled)
resource "google_pubsub_topic" "dead_letter" {
  count = var.enable_dead_letter_queue ? 1 : 0

  name = "${var.name_prefix}-items-dead-letter-topic"

  labels = merge(var.labels, {
    purpose = "dead-letter"
  })

  message_retention_duration = "604800s" # 7 days

  depends_on = [google_project_service.pubsub]
}

# Dead Letter Subscription (if enabled)
resource "google_pubsub_subscription" "dead_letter" {
  count = var.enable_dead_letter_queue ? 1 : 0

  name  = "${var.name_prefix}-items-dead-letter-subscription"
  topic = google_pubsub_topic.dead_letter[0].name

  labels = merge(var.labels, {
    purpose = "dead-letter"
  })

  ack_deadline_seconds       = 600
  message_retention_duration = "604800s" # 7 days
  retain_acked_messages      = true

  expiration_policy {
    ttl = "2678400s" # 31 days
  }
}

# Pub/Sub Schema (if schema validation is needed)
resource "google_pubsub_schema" "main" {
  count = var.create_schema ? 1 : 0

  name = "${var.name_prefix}-items-schema"
  type = var.schema_type

  definition = var.schema_definition
}

# IAM bindings for service accounts
resource "google_pubsub_topic_iam_member" "publisher" {
  for_each = toset(var.publisher_service_accounts)

  topic  = google_pubsub_topic.main.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${each.value}"
}

resource "google_pubsub_subscription_iam_member" "subscriber" {
  for_each = toset(var.subscriber_service_accounts)

  subscription = google_pubsub_subscription.microservice_2.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${each.value}"
}

# # Monitoring: Topic metrics
# resource "google_monitoring_alert_policy" "topic_undelivered_messages" {
#   count        = var.enable_monitoring ? 1 : 0
#   display_name = "${var.name_prefix} Pub/Sub Topic Undelivered Messages"

#   documentation {
#     content = "Alert when there are too many undelivered messages in the Pub/Sub topic"
#   }

#   conditions {
#     display_name = "Undelivered messages condition"

#     condition_threshold {
#       filter = "resource.type=\"pubsub_topic\" AND resource.labels.topic_id=\"${google_pubsub_topic.main.name}\" AND metric.type=\"pubsub.googleapis.com/topic/num_undelivered_messages\""
#       duration        = "300s"
#       comparison      = "COMPARISON_GT"
#       threshold_value = var.undelivered_messages_threshold

#       aggregations {
#         alignment_period   = "300s"
#         per_series_aligner = "ALIGN_MEAN"
#       }
#     }
#   }

#   alert_strategy {
#     auto_close = "1800s"
#   }

#   combiner              = "OR"
#   enabled               = true
#   notification_channels = var.notification_channels
# }

# # Monitoring: Subscription age metrics
# resource "google_monitoring_alert_policy" "subscription_oldest_unacked_message" {
#   count        = var.enable_monitoring ? 1 : 0
#   display_name = "${var.name_prefix} Pub/Sub Subscription Oldest Unacked Message"

#   documentation {
#     content = "Alert when messages in subscription are too old"
#   }

#   conditions {
#     display_name = "Oldest unacked message age condition"

#     condition_threshold {
#       filter = "resource.type=\"pubsub_subscription\" AND resource.labels.subscription_id=\"${google_pubsub_subscription.microservice_2.name}\" AND metric.type=\"pubsub.googleapis.com/subscription/oldest_unacked_message_age\""
#       duration        = "300s"
#       comparison      = "COMPARISON_GT"
#       threshold_value = var.oldest_unacked_message_threshold

#       aggregations {
#         alignment_period   = "300s"
#         per_series_aligner = "ALIGN_MAX"
#       }
#     }
#   }

#   alert_strategy {
#     auto_close = "1800s"
#   }

#   combiner              = "OR"
#   enabled               = true
#   notification_channels = var.notification_channels
# }
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/pubsub/variables.tf
FILE_CONTENT_START
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
  default     = "604800s" # 7 days
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
  default     = "2678400s" # 31 days
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
  default     = 600 # 10 minutes
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/vpc/outputs.tf
FILE_CONTENT_START
# terraform/modules/vpc/outputs.tf

output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.main.name
}

output "network_self_link" {
  description = "The self-link of the VPC network"
  value       = google_compute_network.main.self_link
}

output "network_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.main.id
}

output "private_subnet_name" {
  description = "The name of the private subnet"
  value       = google_compute_subnetwork.private.name
}

output "private_subnet_self_link" {
  description = "The self-link of the private subnet"
  value       = google_compute_subnetwork.private.self_link
}

output "private_subnet_cidr" {
  description = "The CIDR block of the private subnet"
  value       = google_compute_subnetwork.private.ip_cidr_range
}

output "public_subnet_name" {
  description = "The name of the public subnet"
  value       = google_compute_subnetwork.public.name
}

output "public_subnet_self_link" {
  description = "The self-link of the public subnet"
  value       = google_compute_subnetwork.public.self_link
}

output "public_subnet_cidr" {
  description = "The CIDR block of the public subnet"
  value       = google_compute_subnetwork.public.ip_cidr_range
}

output "pods_cidr_range" {
  description = "The CIDR range for GKE pods"
  value       = var.pods_cidr_range
}

output "services_cidr_range" {
  description = "The CIDR range for GKE services"
  value       = var.services_cidr_range
}

output "gke_master_cidr" {
  description = "The CIDR range for GKE master nodes"
  value       = var.gke_master_cidr
}

output "router_name" {
  description = "The name of the Cloud Router"
  value       = google_compute_router.main.name
}

output "nat_name" {
  description = "The name of the NAT gateway"
  value       = google_compute_router_nat.main.name
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/vpc/main.tf
FILE_CONTENT_START
# VPC Network
resource "google_compute_network" "main" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  description             = "VPC network for ${var.environment} environment"

  depends_on = [
    google_project_service.compute,
    google_project_service.container
  ]
}

# Private Subnet for GKE and internal resources
resource "google_compute_subnetwork" "private" {
  name          = "${var.name_prefix}-private-subnet"
  ip_cidr_range = var.private_subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id
  description   = "Private subnet for GKE cluster and internal services"

  # Enable private Google access for GKE nodes
  private_ip_google_access = true

  # Secondary IP ranges for GKE
  secondary_ip_range {
    range_name    = "${var.name_prefix}-pods"
    ip_cidr_range = var.pods_cidr_range
  }

  secondary_ip_range {
    range_name    = "${var.name_prefix}-services"
    ip_cidr_range = var.services_cidr_range
  }
}

# Public Subnet for Load Balancer and NAT Gateway
resource "google_compute_subnetwork" "public" {
  name          = "${var.name_prefix}-public-subnet"
  ip_cidr_range = var.public_subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id
  description   = "Public subnet for load balancers and NAT gateway"
}

# Cloud Router for NAT Gateway
resource "google_compute_router" "main" {
  name    = "${var.name_prefix}-router"
  region  = var.region
  network = google_compute_network.main.id

  description = "Cloud Router for NAT gateway"
}

# NAT Gateway for private subnet internet access
resource "google_compute_router_nat" "main" {
  name                               = "${var.name_prefix}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall Rules
# Allow internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.name_prefix}-allow-internal"
  network = google_compute_network.main.name

  description = "Allow internal communication between subnets"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.private_subnet_cidr,
    var.public_subnet_cidr,
    var.pods_cidr_range,
    var.services_cidr_range
  ]
}

# Allow HTTP/HTTPS from internet to load balancer
resource "google_compute_firewall" "allow_http_https" {
  name    = "${var.name_prefix}-allow-http-https"
  network = google_compute_network.main.name

  description = "Allow HTTP and HTTPS traffic from internet"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
}

# Allow SSH for debugging (restricted to specific source ranges in production)
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.name_prefix}-allow-ssh"
  network = google_compute_network.main.name

  description = "Allow SSH access for debugging"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = ["ssh-server"]
}

# Allow GKE master to nodes communication
resource "google_compute_firewall" "allow_gke_master" {
  name    = "${var.name_prefix}-allow-gke-master"
  network = google_compute_network.main.name

  description = "Allow GKE master to communicate with nodes"

  allow {
    protocol = "tcp"
    ports    = ["443", "10250"]
  }

  source_ranges = [var.gke_master_cidr]
  target_tags   = ["gke-node"]
}

# Enable required APIs
resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/vpc/variables.tf
FILE_CONTENT_START
# terraform/modules/vpc/variables.tf

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

# Network CIDR Configuration
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

# Security Configuration
variable "ssh_source_ranges" {
  description = "Source IP ranges allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/monitoring/outputs.tf
FILE_CONTENT_START
output "notification_channel_id" {
  description = "ID of the email notification channel"
  value       = google_monitoring_notification_channel.email.name
}

output "notification_channel_name" {
  description = "Name of the email notification channel"
  value       = google_monitoring_notification_channel.email.display_name
}

output "dashboard_url" {
  description = "URL to access the monitoring dashboard"
  value       = "https://console.cloud.google.com/monitoring/dashboards/custom/${basename(google_monitoring_dashboard.main.id)}?project=${var.project_id}"
}

# output "alert_policies" {
#   description = "List of created alert policy names"
#   value = [
#     google_monitoring_alert_policy.gke_cpu_usage.display_name,
#     google_monitoring_alert_policy.gke_memory_usage.display_name,
#     google_monitoring_alert_policy.gke_node_not_ready.display_name,
#     google_monitoring_alert_policy.http_error_rate.display_name,
#     google_monitoring_alert_policy.http_latency.display_name,
#     google_monitoring_alert_policy.low_request_volume.display_name,
#     google_monitoring_alert_policy.error_logs.display_name
#   ]
# }

output "log_metric_name" {
  description = "Name of the error count log metric"
  value       = google_logging_metric.error_count.name
}

output "dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = google_monitoring_dashboard.main.id
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/monitoring/main.tf
FILE_CONTENT_START
# Enable required APIs
resource "google_project_service" "monitoring" {
  service            = "monitoring.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "logging" {
  service            = "logging.googleapis.com"
  disable_on_destroy = false
}

# Notification channel for alerts
resource "google_monitoring_notification_channel" "email" {
  display_name = "${var.name_prefix} Email Notification Channel"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }

  enabled = true
}

# Infrastructure Monitoring Alerts

# GKE Cluster CPU Usage Alert
resource "google_monitoring_alert_policy" "gke_cpu_usage" {
  display_name = "${var.name_prefix} GKE CPU Usage High"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Alert when GKE cluster CPU usage is consistently high"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "GKE CPU usage > 80%"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.namespace_name", "resource.labels.pod_name"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# GKE Cluster Memory Usage Alert
resource "google_monitoring_alert_policy" "gke_memory_usage" {
  display_name = "${var.name_prefix} GKE Memory Usage High"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Alert when GKE cluster memory usage is consistently high"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "GKE Memory usage > 85%"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\" AND metric.type=\"kubernetes.io/container/memory/used_bytes\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 435159040 # ~415MB (85% of 512MB)

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.namespace_name", "resource.labels.pod_name"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# GKE Pod Restart Alert
resource "google_monitoring_alert_policy" "gke_pod_restarts" {
  display_name = "${var.name_prefix} GKE Pod Restart Alert"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Alert when GKE pods are restarting frequently"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Pod restart rate is high"

    condition_threshold {
      filter          = "resource.type=\"k8s_pod\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\" AND metric.type=\"kubernetes.io/pod/restart_count\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.pod_name"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# Application Monitoring Alerts

# HTTP Error Rate Alert (placeholder - will work when service mesh is enabled)
resource "google_monitoring_alert_policy" "http_error_rate" {
  display_name = "${var.name_prefix} HTTP Error Rate High"
  combiner     = "OR"
  enabled      = false # Disabled until service mesh metrics are available

  documentation {
    content   = "Alert when HTTP error rate is high (requires service mesh)"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "HTTP 5xx error rate > 5%"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.05

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# HTTP Latency Alert (placeholder - will work when service mesh is enabled)
resource "google_monitoring_alert_policy" "http_latency" {
  display_name = "${var.name_prefix} HTTP Latency High"
  combiner     = "OR"
  enabled      = false # Disabled until service mesh metrics are available

  documentation {
    content   = "Alert when HTTP latency is consistently high (requires service mesh)"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "HTTP latency > 2s"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 2000

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# Business Metrics Alert - Low Pod Count
resource "google_monitoring_alert_policy" "low_pod_count" {
  display_name = "${var.name_prefix} Low Pod Count"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Alert when pod count is too low"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Pod count < 2"

    condition_threshold {
      filter          = "resource.type=\"k8s_pod\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\" AND metric.type=\"kubernetes.io/pod/uptime\""
      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = 2

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_COUNT"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# Error Log Count Metric
resource "google_logging_metric" "error_count" {
  name   = "${var.name_prefix}_error_count"
  filter = "resource.type=\"k8s_container\" AND severity>=ERROR AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""

  metric_descriptor {
    metric_kind  = "DELTA"
    value_type   = "INT64"
    display_name = "Error Log Count"

    labels {
      key         = "severity"
      value_type  = "STRING"
      description = "Severity of the log entry"
    }

    labels {
      key         = "service_name"
      value_type  = "STRING"
      description = "Name of the service"
    }
  }

  label_extractors = {
    "severity"     = "EXTRACT(severity)"
    "service_name" = "EXTRACT(resource.labels.container_name)"
  }
}

# Log-based Alert for Errors
resource "google_monitoring_alert_policy" "error_logs" {
  display_name = "${var.name_prefix} High Error Log Count"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Alert when error log count is high"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Error log count > 10/minute"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.error_count.name}\" AND resource.type=\"k8s_container\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 10

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# Dashboard
resource "google_monitoring_dashboard" "main" {
  dashboard_json = jsonencode({
    displayName = "${var.name_prefix} Platform Dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "GKE CPU Usage"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields      = ["resource.labels.namespace_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "CPU cores"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          xPos   = 6
          width  = 6
          height = 4
          widget = {
            title = "Memory Usage"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/memory/used_bytes\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields      = ["resource.labels.namespace_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Memory (bytes)"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          yPos   = 4
          width  = 12
          height = 4
          widget = {
            title = "Pod Restart Count"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_pod\" AND metric.type=\"kubernetes.io/pod/restart_count\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["resource.labels.pod_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Restarts/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          yPos   = 8
          width  = 6
          height = 4
          widget = {
            title = "Error Log Rate"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.error_count.name}\" AND resource.type=\"k8s_container\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.labels.service_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Errors/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          xPos   = 6
          yPos   = 8
          width  = 6
          height = 4
          widget = {
            title = "Pod Count"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"k8s_pod\" AND metric.type=\"kubernetes.io/pod/uptime\" AND resource.labels.cluster_name=\"${var.gke_cluster_name}\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_COUNT"
                        groupByFields      = ["resource.labels.namespace_name"]
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Pod Count"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./terraform/modules/monitoring/variables.tf
FILE_CONTENT_START
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
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./LICENSE
FILE_CONTENT_START
MIT License

Copyright (c) 2025 gavilanbe

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./Makefile
FILE_CONTENT_START
# DogfyDiet Platform Makefile

.PHONY: help bootstrap init plan apply destroy clean lint validate

# Default target
help:
	@echo "DogfyDiet Platform - Available Commands:"
	@echo "  make bootstrap    - Run initial setup (create state bucket, service accounts)"
	@echo "  make init        - Initialize Terraform"
	@echo "  make plan        - Run Terraform plan"
	@echo "  make apply       - Apply Terraform changes"
	@echo "  make destroy     - Destroy all infrastructure (careful!)"
	@echo "  make clean       - Clean local files"
	@echo "  make lint        - Lint Terraform files"
	@echo "  make validate    - Validate Terraform configuration"

# Run bootstrap setup
bootstrap:
	@echo "Running bootstrap setup..."
	@chmod +x scripts/bootstrap.sh
	@./scripts/bootstrap.sh

# Initialize Terraform
init:
	@echo "Initializing Terraform..."
	@cd terraform/environments/dev && terraform init

# Run Terraform plan
plan:
	@echo "Running Terraform plan..."
	@cd terraform/environments/dev && terraform plan

# Apply Terraform changes
apply:
	@echo "Applying Terraform changes..."
	@cd terraform/environments/dev && terraform apply

# Destroy infrastructure
destroy:
	@echo "WARNING: This will destroy all infrastructure!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && \
	if [ "$$confirm" = "yes" ]; then \
		cd terraform/environments/dev && terraform destroy; \
	else \
		echo "Destroy cancelled."; \
	fi

# Clean local files
clean:
	@echo "Cleaning local files..."
	@rm -f sa-key.json sa-key-encoded.txt
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.tfplan" -exec rm -f {} + 2>/dev/null || true
	@find . -type f -name "*.tfstate*" -exec rm -f {} + 2>/dev/null || true
	@echo "Clean complete!"

# Lint Terraform files
lint:
	@echo "Linting Terraform files..."
	@terraform fmt -recursive terraform/

# Validate Terraform configuration
validate:
	@echo "Validating Terraform configuration..."
	@cd terraform/environments/dev && terraform validate

# Quick setup (bootstrap + init + plan)
quickstart: bootstrap init plan
	@echo "Quickstart complete! Review the plan and run 'make apply' when ready."
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-2/Chart.yaml
FILE_CONTENT_START
apiVersion: v2
name: microservice-2
description: DogfyDiet Microservice 2 - Subscriber and Data Processor
type: application
version: 1.0.0
appVersion: "1.0.0"
home: https://github.com/your-username/dogfydiet-platform
sources:
  - https://github.com/your-username/dogfydiet-platform
maintainers:
  - name: DogfyDiet Platform Team
    email: team@dogfydiet.com
keywords:
  - microservice
  - subscriber
  - firestore
  - pubsub
  - dogfydiet
annotations:
  category: Application
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-2/values.yaml
FILE_CONTENT_START
replicaCount: 2

image:
  repository: us-central1-docker.pkg.dev/nahuelgabe-test/dogfydiet-dev-docker-repo/microservice-2
  pullPolicy: IfNotPresent
  tag: "latest"

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations:
    iam.gke.io/gcp-service-account: dogfydiet-dev-microservice-2@nahuelgabe-test.iam.gserviceaccount.com
  name: "microservice-2"

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "3001"
  prometheus.io/path: "/metrics"

podSecurityContext:
  fsGroup: 1001
  runAsNonRoot: true
  runAsUser: 1001

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1001

service:
  type: ClusterIP
  port: 80
  targetPort: 3001
  protocol: TCP

ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: processor.dogfydiet.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 8
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - microservice-2
        topologyKey: kubernetes.io/hostname

# Environment variables
env:
  GOOGLE_CLOUD_PROJECT: "nahuelgabe-test"
  PUBSUB_SUBSCRIPTION: "dogfydiet-dev-items-subscription"
  FIRESTORE_COLLECTION: "items"
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  RATE_LIMIT: "100"
  CORS_ORIGIN: "https://*.dogfydiet.com,http://localhost:8080"

# Probes configuration
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

# PodDisruptionBudget
podDisruptionBudget:
  enabled: true
  minAvailable: 1

# NetworkPolicy
networkPolicy:
  enabled: true
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: istio-system
      - namespaceSelector:
          matchLabels:
            name: default
      ports:
      - protocol: TCP
        port: 3001
  egress:
    - to: []
      ports:
      - protocol: TCP
        port: 443  # HTTPS to Google APIs
      - protocol: TCP
        port: 53   # DNS
      - protocol: UDP
        port: 53   # DNS
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-1/Chart.yaml
FILE_CONTENT_START
apiVersion: v2
name: microservice-1
description: DogfyDiet Microservice 1 - API Gateway and Publisher
type: application
version: 1.0.0
appVersion: "1.0.0"
home: https://github.com/gavilanbe/dogfydiet-platform
sources:
  - https://github.com/gavilanbe/dogfydiet-platform
maintainers:
  - name: DogfyDiet Platform Team
    email: nahuel@gavilanbe.io
keywords:
  - microservice
  - api
  - pubsub
  - dogfydiet
annotations:
  category: Application
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-1/templates/deployment.yaml
FILE_CONTENT_START
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "microservice-1.fullname" . }}
  labels:
    {{- include "microservice-1.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "microservice-1.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "microservice-1.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "microservice-1.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.image.containerPort | default 3000 }}
              protocol: TCP
          env:
            {{- range $key, $value := .Values.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
          livenessProbe:
            {{- toYaml .Values.livenessProbe | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe | nindent 12 }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          volumeMounts:
            - name: tmp-volume
              mountPath: /tmp
              readOnly: false
      volumes:
        - name: tmp-volume
          emptyDir: {}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-1/templates/backendconfig.yaml
FILE_CONTENT_START
{{- if .Values.backendConfig.enabled }}
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: {{ include "microservice-1.fullname" . }}-backendconfig
  labels:
    {{- include "microservice-1.labels" . | nindent 4 }}
spec:
  healthCheck:
    checkIntervalSec: {{ .Values.backendConfig.healthCheck.checkIntervalSec | default 15 }}
    timeoutSec: {{ .Values.backendConfig.healthCheck.timeoutSec | default 5 }}
    healthyThreshold: {{ .Values.backendConfig.healthCheck.healthyThreshold | default 2 }}
    unhealthyThreshold: {{ .Values.backendConfig.healthCheck.unhealthyThreshold | default 2 }}
    type: HTTP
    port: {{ .Values.image.containerPort | default 3000 }} # Port your container listens on
    requestPath: {{ .Values.backendConfig.healthCheck.requestPath | default "/health" }}
{{- end }}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-1/templates/service.yaml
FILE_CONTENT_START
apiVersion: v1
kind: Service
metadata:
  name: {{ include "microservice-1.fullname" . }}
  annotations:
    cloud.google.com/neg: '{"exposed_ports": {"80":{}}}'
    {{- if .Values.backendConfig.enabled }}
    cloud.google.com/backend-config: '{"ports": {"http":"{{ include "microservice-1.fullname" . }}-backendconfig"}}'
    {{- end }}
  labels:
    {{- include "microservice-1.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}

      targetPort: http # This should match the name of the port in your deployment's container spec
      protocol: {{ .Values.service.protocol }}
      name: http
  selector:
    {{- include "microservice-1.selectorLabels" . | nindent 4 }}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-1/templates/hpa.yaml
FILE_CONTENT_START
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "microservice-1.fullname" . }}
  labels:
    {{- include "microservice-1.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "microservice-1.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-1/templates/serviceaccount.yaml
FILE_CONTENT_START
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "microservice-1.serviceAccountName" . }}
  labels:
    {{- include "microservice-1.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-1/templates/_helpers.tpl
FILE_CONTENT_START
{{/*
Expand the name of the chart.
*/}}
{{- define "microservice-1.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "microservice-1.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "microservice-1.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "microservice-1.labels" -}}
helm.sh/chart: {{ include "microservice-1.chart" . }}
{{ include "microservice-1.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: api-gateway
app.kubernetes.io/part-of: dogfydiet-platform
{{- end }}

{{/*
Selector labels
*/}}
{{- define "microservice-1.selectorLabels" -}}
app.kubernetes.io/name: {{ include "microservice-1.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "microservice-1.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "microservice-1.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./k8s/helm-charts/microservice-1/values.yaml
FILE_CONTENT_START
replicaCount: 2

image:
  repository: us-central1-docker.pkg.dev/nahuelgabe-test/dogfydiet-dev-docker-repo/microservice-1
  pullPolicy: IfNotPresent
  tag: "latest"
  containerPort: 3000

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations:
    iam.gke.io/gcp-service-account: dogfydiet-dev-microservice-1@nahuelgabe-test.iam.gserviceaccount.com
  name: "microservice-1"

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "3000"
  prometheus.io/path: "/metrics"

podSecurityContext:
  fsGroup: 1001
  runAsNonRoot: true
  runAsUser: 1001

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1001

service:
  type: ClusterIP
  port: 80
  #targetPort: 3000
  protocol: TCP
  targetPort: http # Referencing the named port of the container
  protocol: TCP


backendConfig:
  enabled: true
  healthCheck:
    requestPath: "/health"
    checkIntervalSec: 15
    timeoutSec: 5
    healthyThreshold: 2
    unhealthyThreshold: 2
    

# ingress:
#   enabled: false
#   className: ""
#   annotations: {}
#   hosts:
#     - host: 
#       paths:
#         - path: /
#           pathType: Prefix
#   tls: []

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - microservice-1
        topologyKey: kubernetes.io/hostname

# Environment variables
env:
  GOOGLE_CLOUD_PROJECT: "nahuelgabe-test"
  PUBSUB_TOPIC: "dogfydiet-dev-items-topic"
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  RATE_LIMIT: "100"
  CORS_ORIGIN: "https://nahueldog.duckdns.org,http://localhost:8080" # Add your frontend origin

# Probes configuration
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

# PodDisruptionBudget
podDisruptionBudget:
  enabled: true
  minAvailable: 1

# NetworkPolicy
networkPolicy:
  enabled: true
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: istio-system
      - namespaceSelector:
          matchLabels:
            name: default
      ports:
      - protocol: TCP
        port: 3000
  egress:
    - to: []
      ports:
      - protocol: TCP
        port: 443  # HTTPS to Google APIs
      - protocol: TCP
        port: 53   # DNS
      - protocol: UDP
        port: 53   # DNS
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./README.md
FILE_CONTENT_START
# DogfyDiet Platform

A cloud-native full-stack application deployed on Google Cloud Platform, demonstrating microservices architecture, Infrastructure as Code, and modern DevOps practices.

## 🏗️ Architecture Overview

This solution implements a microservices-based architecture with:
- **Frontend**: Vue.js 3 SPA hosted on Google Cloud Storage with CDN
- **Backend**: Two Node.js microservices deployed on Google Kubernetes Engine
- **Messaging**: Event-driven communication via Google Pub/Sub
- **Database**: Google Firestore for NoSQL data storage
- **Infrastructure**: Managed via Terraform with comprehensive monitoring

## 🚀 Technology Stack

### Infrastructure & Cloud
- **Google Cloud Platform** - Cloud provider
- **Terraform** - Infrastructure as Code
- **Google Kubernetes Engine (GKE)** - Container orchestration
- **Google Cloud Storage** - Static website hosting with CDN
- **Google Cloud Load Balancer** - Traffic distribution and SSL termination
- **Google Pub/Sub** - Event messaging system
- **Google Firestore** - NoSQL document database
- **Google Cloud Monitoring** - Observability and alerting

### Applications  
- **Vue.js 3** - Frontend framework with Composition API
- **Node.js + Express.js** - Backend microservices
- **Docker** - Multi-stage containerization
- **Helm** - Kubernetes package management

### DevOps & Security
- **GitHub Actions** - CI/CD pipeline
- **Google Artifact Registry** - Container registry
- **Google Secret Manager** - Secret management
- **Workload Identity** - Secure GKE-to-GCP authentication
- **Network Policies** - Kubernetes microsegmentation

## 📋 Prerequisites

- Google Cloud Platform account with billing enabled
- `gcloud` CLI installed and configured
- `terraform` >= 1.5.0
- `kubectl` configured for GKE
- `helm` >= 3.12.0
- Node.js >= 18.0.0 (for local development)
- Docker (for building images)

## 🔧 Quick Start

### 1. Infrastructure Deployment

```bash
# Clone the repository
git clone https://github.com/your-username/dogfydiet-platform.git
cd dogfydiet-platform

# Set up Terraform backend (create GCS bucket first)
gsutil mb gs://your-project-terraform-state

# Initialize and deploy infrastructure
cd terraform/environments/dev
terraform init
terraform plan
terraform apply

# Get GKE credentials
gcloud container clusters get-credentials dogfydiet-dev-gke-cluster --region us-central1
```

### 2. Application Deployment

```bash
# Build and push Docker images
docker build -t us-central1-docker.pkg.dev/your-project/dogfydiet-dev-docker-repo/microservice-1:latest applications/microservice-1/
docker push us-central1-docker.pkg.dev/your-project/dogfydiet-dev-docker-repo/microservice-1:latest

docker build -t us-central1-docker.pkg.dev/your-project/dogfydiet-dev-docker-repo/microservice-2:latest applications/microservice-2/
docker push us-central1-docker.pkg.dev/your-project/dogfydiet-dev-docker-repo/microservice-2:latest

# Deploy microservices using Helm
cd k8s/helm-charts/microservice-1
helm install microservice-1 . --set image.tag=latest

cd ../microservice-2
helm install microservice-2 . --set image.tag=latest

# Deploy frontend to Cloud Storage
cd applications/frontend
npm install
npm run build
gsutil -m rsync -r -d dist/ gs://your-frontend-bucket/
```

### 3. Configure CI/CD

Set up GitHub repository secrets:
- `GCP_SA_KEY`: Base64 encoded service account key
- `NOTIFICATION_EMAIL`: Email for monitoring alerts
- `FRONTEND_BUCKET_NAME`: Cloud Storage bucket name
- `API_URL`: Backend API URL

## 🏛️ Project Structure

```
dogfydiet-platform/
├── README.md                     # This file
├── .github/workflows/           # GitHub Actions CI/CD pipelines
├── terraform/                   # Infrastructure as Code
│   ├── environments/dev/        # Development environment
│   └── modules/                 # Reusable Terraform modules
├── applications/                # Application source code
│   ├── frontend/               # Vue.js frontend application
│   ├── microservice-1/         # API Gateway & Publisher
│   └── microservice-2/         # Subscriber & Data Processor
├── k8s/                        # Kubernetes manifests and Helm charts
│   └── helm-charts/            # Helm charts for microservices
├── docs/                       # Architecture and technical documentation
└── scripts/                    # Utility scripts
```

## 🔄 Application Flow

1. **User Interaction**: User adds items through Vue.js frontend
2. **API Request**: Frontend sends HTTP POST to Microservice 1
3. **Validation**: Microservice 1 validates input and processes request
4. **Event Publishing**: Microservice 1 publishes event to Pub/Sub topic
5. **Event Processing**: Microservice 2 subscribes and processes the event
6. **Data Persistence**: Microservice 2 stores data in Firestore
7. **Real-time Updates**: Frontend displays updated item list

## 🛡️ Security Features

- **Workload Identity**: Secure service-to-service authentication
- **Network Policies**: Kubernetes microsegmentation
- **IAM Roles**: Least privilege access control
- **Secret Management**: Google Secret Manager integration
- **Container Security**: Non-root users, read-only filesystems
- **Input Validation**: Comprehensive request validation and sanitization

## 📊 Monitoring & Observability

- **Health Checks**: Liveness and readiness probes for all services
- **Metrics**: Custom application and business metrics
- **Logging**: Structured logging with correlation IDs
- **Alerting**: Multi-tier alerting (infrastructure, SRE, business)
- **Dashboards**: GCP Monitoring dashboards for operational visibility
- **Distributed Tracing**: Request tracing across microservices

## 🎯 Key Features Implemented

### Infrastructure
- ✅ VPC with private/public subnets and NAT gateway
- ✅ GKE cluster with autoscaling and security hardening
- ✅ Cloud Storage + Load Balancer for cost-effective frontend hosting
- ✅ Pub/Sub for event-driven architecture
- ✅ Firestore for scalable NoSQL data storage
- ✅ Comprehensive IAM with service accounts and workload identity

### Applications
- ✅ Vue.js 3 frontend with modern UI/UX and PWA capabilities
- ✅ Node.js microservices with comprehensive error handling
- ✅ RESTful APIs with validation and rate limiting
- ✅ Event-driven communication between services
- ✅ Production-ready Docker containers with multi-stage builds

### DevOps
- ✅ Terraform modules for reusable infrastructure components
- ✅ GitHub Actions CI/CD with automated testing and deployment
- ✅ Helm charts for Kubernetes application management
- ✅ Automated Docker image building and registry management
- ✅ Environment-specific configuration management

### Monitoring
- ✅ Application health endpoints and metrics
- ✅ Infrastructure monitoring with custom dashboards
- ✅ Log aggregation and structured logging
- ✅ Multi-tier alerting strategy
- ✅ Performance monitoring and SLA tracking

## 🎮 Local Development

### Frontend Development
```bash
cd applications/frontend
npm install
npm run serve  # Development server on http://localhost:8080
```

### Microservice Development  
```bash
cd applications/microservice-1
npm install
npm run dev    # Development server with hot reload

cd applications/microservice-2  
npm install
npm run dev    # Development server with hot reload
```

### Testing
```bash
# Run frontend tests
cd applications/frontend
npm run test:unit

# Run microservice tests
cd applications/microservice-1
npm test

cd applications/microservice-2
npm test
```

## 🚀 Deployment

### Automated Deployment (Recommended)
Push to `main` branch triggers automatic deployment via GitHub Actions:
1. Terraform infrastructure updates
2. Docker image building and pushing
3. Kubernetes application deployment
4. Frontend deployment to Cloud Storage

### Manual Deployment
```bash
# Infrastructure
cd terraform/environments/dev
terraform apply

# Applications
# (See Quick Start section above)
```

## 📈 Scaling and Performance

- **Horizontal Pod Autoscaler**: Automatic scaling based on CPU/memory
- **Cluster Autoscaler**: Node pool scaling based on resource demands
- **CDN Caching**: Global content delivery with Cloud CDN
- **Connection Pooling**: Efficient database connection management
- **Async Processing**: Non-blocking operations with event-driven design

## 💰 Cost Optimization

- **Cloud Storage**: 90% cost reduction vs. compute instances for frontend
- **Preemptible Nodes**: Cost-effective compute for non-critical workloads
- **Auto-scaling**: Scale to zero during low usage periods
- **Resource Right-sizing**: Proper CPU/memory allocation to avoid waste

## 🔍 Troubleshooting

### Check Application Health
```bash
# Check pod status
kubectl get pods

# Check service endpoints
kubectl get services

# View application logs
kubectl logs -l app=microservice-1
kubectl logs -l app=microservice-2

# Check ingress status
kubectl describe ingress
```

### Common Issues
- **Pod CrashLoopBackOff**: Check resource limits and application logs
- **ImagePullBackOff**: Verify image names and registry permissions
- **Service Connection Issues**: Check network policies and service discovery
- **Pub/Sub Issues**: Verify IAM permissions and topic/subscription configuration

## 📚 Documentation

- [Architecture Documentation](docs/architecture.md) - Detailed system architecture
- [Production Recommendations](docs/production-recommendations.md) - Production readiness guide
- [Technical Decisions](docs/technical-decisions.md) - ADRs and design rationale

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🎊 Acknowledgments

- Google Cloud Platform for comprehensive cloud services
- Kubernetes community for container orchestration
- Vue.js team for excellent frontend framework
- Terraform community for infrastructure as code tooling

---

**DogfyDiet Platform** - Demonstrating cloud-native architecture excellence 🐕❤️
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./CONTRIBUTING.md
FILE_CONTENT_START
# Contributing to DogfyDiet Platform

Thank you for your interest in contributing to the DogfyDiet Platform! This document provides guidelines and instructions for contributing to this project.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Process](#development-process)
- [Pull Request Process](#pull-request-process)
- [Infrastructure Changes](#infrastructure-changes)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)
- [Security](#security)

## 📜 Code of Conduct

We are committed to providing a welcoming and inspiring community for all. Please read and follow our Code of Conduct:

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on what is best for the community
- Show empathy towards other community members

## 🚀 Getting Started

### Prerequisites

1. **Fork the Repository**
   ```bash
   # Fork via GitHub UI, then clone your fork
   git clone https://github.com/YOUR_USERNAME/dogfydiet-platform.git
   cd dogfydiet-platform
   ```

2. **Set Up Development Environment**
   ```bash
   # Install required tools
   - terraform >= 1.5.0
   - gcloud CLI
   - kubectl
   - helm >= 3.12.0
   - node.js >= 18.0.0
   - docker
   ```

3. **Configure Git**
   ```bash
   git config user.name "Your Name"
   git config user.email "your.email@example.com"
   ```

## 💻 Development Process

### 1. Branch Naming Convention

Create branches following this pattern:
- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring
- `test/description` - Test additions/updates
- `chore/description` - Maintenance tasks

Example:
```bash
git checkout -b feature/add-redis-cache
```

### 2. Commit Message Format

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Test additions/modifications
- `chore`: Maintenance tasks
- `perf`: Performance improvements
- `ci`: CI/CD changes

Examples:
```bash
feat(api): add rate limiting to microservice-1

- Implement rate limiting middleware
- Add configuration for rate limits
- Update documentation

Closes #123
```

### 3. Development Workflow

1. **Create a Feature Branch**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/your-feature
   ```

2. **Make Changes**
   - Write clean, documented code
   - Follow existing patterns and conventions
   - Add tests for new functionality

3. **Test Locally**
   ```bash
   # Run application tests
   cd applications/microservice-1
   npm test
   
   # Validate Terraform
   cd terraform/environments/dev
   terraform fmt -recursive
   terraform validate
   ```

4. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat(scope): description"
   ```

5. **Push and Create PR**
   ```bash
   git push origin feature/your-feature
   ```

## 🔄 Pull Request Process

### 1. PR Requirements

Before submitting a PR, ensure:

- [ ] Code follows project coding standards
- [ ] All tests pass
- [ ] Documentation is updated
- [ ] Terraform is formatted (`terraform fmt`)
- [ ] No sensitive data is committed
- [ ] PR has a clear description
- [ ] Related issues are linked

### 2. PR Template

When creating a PR, use this template:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Infrastructure change

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] My code follows the project style guidelines
- [ ] I have performed a self-review
- [ ] I have commented my code where necessary
- [ ] I have updated the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix/feature works
- [ ] New and existing unit tests pass locally

## Related Issues
Closes #(issue number)

## Screenshots (if applicable)
```

### 3. Review Process

1. **Automated Checks**
   - GitHub Actions will run automatically
   - All checks must pass before review

2. **Code Review**
   - At least one maintainer approval required
   - Address all feedback constructively
   - Re-request review after changes

3. **Merge Requirements**
   - All CI checks pass
   - Approved by maintainer
   - No merge conflicts
   - Up to date with main branch

## 🏗️ Infrastructure Changes

### Special Requirements for Terraform

1. **Planning Phase**
   - All Terraform changes trigger a plan in PR
   - Review the plan output carefully
   - Check for unintended changes

2. **Approval Process**
   - Infrastructure changes require senior engineer approval
   - Cost estimates should be reviewed
   - Security scan must pass

3. **Testing**
   ```bash
   # Format check
   terraform fmt -check -recursive
   
   # Validate
   terraform validate
   
   # Plan
   terraform plan
   ```

4. **Documentation**
   - Update module documentation
   - Document any new variables
   - Update architecture diagrams if needed

## 📏 Coding Standards

### JavaScript/Node.js

- Use ESLint configuration
- Follow Airbnb style guide
- Use async/await over callbacks
- Proper error handling

### Terraform

- Use meaningful resource names
- Group related resources
- Comment complex logic
- Use consistent formatting

### Vue.js

- Use Composition API
- Follow Vue style guide
- Component names in PascalCase
- Props validation required

## 🧪 Testing Requirements

### Unit Tests
- Minimum 80% code coverage
- Test edge cases
- Mock external dependencies

### Integration Tests
- Test API endpoints
- Verify database operations
- Test message queue interactions

### Infrastructure Tests
- Validate Terraform plans
- Test module inputs/outputs
- Verify security policies

## 📚 Documentation

### Code Documentation
- JSDoc for JavaScript functions
- Comments for complex logic
- README for each module

### API Documentation
- Update OpenAPI/Swagger specs
- Document all endpoints
- Include request/response examples

### Architecture Documentation
- Update diagrams for significant changes
- Document design decisions
- Keep ADRs up to date

## 🔐 Security

### Security Guidelines

1. **Never Commit Secrets**
   - No API keys, passwords, or tokens
   - Use environment variables
   - Utilize secret management

2. **Dependency Management**
   - Keep dependencies updated
   - Run `npm audit` regularly
   - Address vulnerabilities promptly

3. **Code Security**
   - Validate all inputs
   - Sanitize user data
   - Follow OWASP guidelines

### Reporting Security Issues

For security vulnerabilities, please email security@dogfydiet.com instead of creating a public issue.

## 🎯 Areas for Contribution

We welcome contributions in these areas:

1. **Features**
   - Performance optimizations
   - New API endpoints
   - UI/UX improvements

2. **Infrastructure**
   - Cost optimization
   - Security hardening
   - Monitoring improvements

3. **Documentation**
   - API documentation
   - Deployment guides
   - Architecture diagrams

4. **Testing**
   - Increase test coverage
   - Add integration tests
   - Performance testing

## 🤝 Getting Help

- Create an issue for bugs/features
- Join our Slack channel: [#dogfydiet-dev]
- Email: contributors@dogfydiet.com

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to DogfyDiet Platform! 🐕❤️
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./scripts/bootstrap.sh
FILE_CONTENT_START
#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-nahuelgabe-test}"
REGION="${GCP_REGION:-us-central1}"
TERRAFORM_STATE_BUCKET="${TERRAFORM_STATE_BUCKET:-${PROJECT_ID}-terraform-state}"

echo -e "${GREEN}🚀 DogfyDiet Platform - Bootstrap Setup${NC}"
echo "================================================"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI is not installed. Please install it first.${NC}"
    echo "Visit: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform is not installed. Please install it first.${NC}"
    echo "Visit: https://learn.hashicorp.com/tutorials/terraform/install-cli"
    exit 1
fi

# Check gcloud authentication
echo -e "\n${YELLOW}Checking GCP authentication...${NC}"
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo -e "${RED}❌ Not authenticated with GCP. Running 'gcloud auth login'...${NC}"
    gcloud auth login
fi

# Set project
echo -e "\n${YELLOW}Setting GCP project to: ${PROJECT_ID}${NC}"
gcloud config set project ${PROJECT_ID}

# Create terraform state bucket if it doesn't exist
echo -e "\n${YELLOW}Creating Terraform state bucket...${NC}"
if ! gsutil ls -b gs://${TERRAFORM_STATE_BUCKET} &> /dev/null; then
    echo "Creating bucket: gs://${TERRAFORM_STATE_BUCKET}"
    gsutil mb -p ${PROJECT_ID} -l ${REGION} gs://${TERRAFORM_STATE_BUCKET}
    
    # Enable versioning
    gsutil versioning set on gs://${TERRAFORM_STATE_BUCKET}
    
    # Set lifecycle rule to delete old versions after 30 days
    cat > /tmp/lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 30,
          "isLive": false
        }
      }
    ]
  }
}
EOF
    gsutil lifecycle set /tmp/lifecycle.json gs://${TERRAFORM_STATE_BUCKET}
    rm /tmp/lifecycle.json
    
    echo -e "${GREEN}✅ Terraform state bucket created successfully${NC}"
else
    echo -e "${GREEN}✅ Terraform state bucket already exists${NC}"
fi

# Create a service account for GitHub Actions CI/CD
echo -e "\n${YELLOW}Creating CI/CD service account...${NC}"
SA_NAME="dogfydiet-github-actions"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if ! gcloud iam service-accounts describe ${SA_EMAIL} --project=${PROJECT_ID} &> /dev/null; then
    echo "Creating service account: ${SA_NAME}"
    gcloud iam service-accounts create ${SA_NAME} \
        --display-name="DogfyDiet GitHub Actions CI/CD" \
        --description="Service account for GitHub Actions CI/CD pipeline" \
        --project=${PROJECT_ID}
    
    # Grant necessary roles
    echo "Granting IAM roles..."
    roles=(
        "roles/compute.admin"
        "roles/container.admin"
        "roles/storage.admin"
        "roles/iam.serviceAccountUser"
        "roles/artifactregistry.admin"
        "roles/secretmanager.admin"
        "roles/pubsub.admin"
        "roles/datastore.owner"
        "roles/monitoring.admin"
        "roles/logging.admin"
    )
    
    for role in "${roles[@]}"; do
        echo "  - ${role}"
        gcloud projects add-iam-policy-binding ${PROJECT_ID} \
            --member="serviceAccount:${SA_EMAIL}" \
            --role="${role}" \
            --quiet
    done
    
    echo -e "${GREEN}✅ Service account created and configured${NC}"
else
    echo -e "${GREEN}✅ Service account already exists${NC}"
fi

# Create and download service account key
echo -e "\n${YELLOW}Creating service account key...${NC}"
KEY_FILE="./sa-key.json"
if [ ! -f "${KEY_FILE}" ]; then
    gcloud iam service-accounts keys create ${KEY_FILE} \
        --iam-account=${SA_EMAIL} \
        --project=${PROJECT_ID}
    
    echo -e "${GREEN}✅ Service account key created: ${KEY_FILE}${NC}"
    echo -e "${YELLOW}⚠️  IMPORTANT: This key will be used for GitHub Actions. Keep it secure!${NC}"
else
    echo -e "${YELLOW}⚠️  Service account key already exists: ${KEY_FILE}${NC}"
fi

# Update terraform backend configuration
echo -e "\n${YELLOW}Updating Terraform backend configuration...${NC}"
BACKEND_FILE="terraform/environments/dev/backend.tf"
if [ ! -f "${BACKEND_FILE}" ]; then
    cat > ${BACKEND_FILE} <<EOF
terraform {
  backend "gcs" {
    bucket = "${TERRAFORM_STATE_BUCKET}"
    prefix = "dogfydiet-platform/dev"
  }
}
EOF
    echo -e "${GREEN}✅ Created backend configuration: ${BACKEND_FILE}${NC}"
else
    echo -e "${YELLOW}⚠️  Backend configuration already exists. Please verify bucket name is correct.${NC}"
fi

# Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Bootstrap setup completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nNext steps:"
echo -e "1. Configure GitHub secrets (see docs/github-secrets-setup.md)"
echo -e "2. Base64 encode the service account key:"
echo -e "   ${YELLOW}cat ${KEY_FILE} | base64 -w 0${NC}"
echo -e "3. Add the encoded key as GitHub secret: GCP_SA_KEY"
echo -e "4. Initialize Terraform:"
echo -e "   ${YELLOW}cd terraform/environments/dev && terraform init${NC}"
echo -e "5. Review and apply Terraform:"
echo -e "   ${YELLOW}terraform plan && terraform apply${NC}"
echo -e "\n${RED}⚠️  Remember to keep ${KEY_FILE} secure and delete it after adding to GitHub secrets!${NC}"
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/frontend/public/index.html
FILE_CONTENT_START
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <link rel="icon" href="<%= BASE_URL %>favicon.ico">
  <title>DogfyDiet - Item Management</title>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
</head>
<body>
  <noscript>
    <strong>We're sorry but this application doesn't work properly without JavaScript enabled. Please enable it to continue.</strong>
  </noscript>
  <div id="app"></div>
  </body>
</html>
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/frontend/package.json
FILE_CONTENT_START
{
  "name": "dogfydiet-frontend-simple",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "serve": "vue-cli-service serve",
    "build": "vue-cli-service build",
    "lint": "vue-cli-service lint"
  },
  "dependencies": {
    "axios": "^1.5.0",
    "vue": "^3.3.4"
  },
  "devDependencies": {
    "@vue/cli-plugin-eslint": "~5.0.8",
    "@vue/cli-plugin-typescript": "~5.0.8",
    "@vue/cli-service": "~5.0.8",
    "@vue/eslint-config-typescript": "^11.0.3",
    "eslint": "^8.49.0",
    "eslint-plugin-vue": "^9.17.0",
    "typescript": "~4.5.5"
  },
  "eslintConfig": {
    "root": true,
    "env": {
      "node": true
    },
    "extends": [
      "plugin:vue/vue3-essential",
      "eslint:recommended",
      "@vue/typescript"
    ],
    "parserOptions": {
      "parser": "@typescript-eslint/parser"
    },
    "rules": {}
  },
  "browserslist": [
    "> 1%",
    "last 2 versions",
    "not dead",
    "not ie 11"
  ]
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/frontend/tsconfig.json
FILE_CONTENT_START
{
  "compilerOptions": {
    "target": "esnext",
    "module": "esnext",
    "strict": true,
    "jsx": "preserve",
    "importHelpers": true,
    "moduleResolution": "node",
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "sourceMap": true,
    "baseUrl": ".",
    "types": [
      "webpack-env",
      "jest" // If you plan to use Jest for unit tests
    ],
    "paths": {
      "@/*": [
        "src/*"
      ]
    },
    "lib": [
      "esnext",
      "dom",
      "dom.iterable",
      "scripthost"
    ]
  },
  "include": [
    "src/**/*.ts",
    "src/**/*.tsx",
    "src/**/*.vue",
    "tests/**/*.ts",
    "tests/**/*.tsx"
  ],
  "exclude": [
    "node_modules"
  ]
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/frontend/src/App.vue
FILE_CONTENT_START
<template>
  <div id="app-container">
    <h1>My DogfyDiet Items</h1>

    <form @submit.prevent="addItem" class="form-container">
      <input
        type="text"
        v-model="newItemName"
        placeholder="Enter item name (e.g., Favorite Toy)"
        class="input-field"
        required
      />
      <select v-model="newItemCategory" class="input-field" required>
        <option value="food">Food</option>
        <option value="treats">Treats</option>
        <option value="supplements">Supplements</option>
        <option value="toys">Toys</option>
      </select>
      <input
        type="text"
        v-model="newItemDescription"
        placeholder="Optional description"
        class="input-field"
      />
      <button type="submit" class="btn-primary" :disabled="isLoading">
        {{ isLoading ? 'Adding...' : 'Add Item' }}
      </button>
    </form>
    </div>
</template>

<script lang="ts">
import { defineComponent, ref, onMounted } from 'vue';
import axios, { AxiosError } from 'axios'; // <--- AÑADIR AxiosError AQUÍ

// Interfaz para la estructura de un detalle de error de validación
interface ValidationErrorDetail {
  type: string;
  value: any;
  msg: string;
  path: string;
  location: string;
}

// Interfaz para la estructura de error.response.data
interface ErrorResponseData {
  error: string;
  details?: ValidationErrorDetail[];
  requestId?: string;
}

// ... resto de tus interfaces (Item, MessageType) ...
interface Item {
  id?: string | number;
  name: string;
  category?: string;
  description?: string;
  status?: 'pending' | 'confirmed';
}

type MessageType = 'success' | 'error' | 'loading' | '';

export default defineComponent({
  name: 'App',
  setup() {
    // ... (tus refs: newItemName, newItemCategory, etc. se mantienen como en la solución anterior)
    const newItemName = ref('');
    const newItemCategory = ref('food');
    const newItemDescription = ref('');
    const items = ref<Item[]>([]);
    const isLoading = ref(false);
    const message = ref('');
    const messageType = ref<MessageType>('');
    const initialLoadError = ref(false);

    const apiUrl = process.env.VUE_APP_API_URL || '/api/microservice1';

    const clearMessage = () => { /* ... se mantiene igual ... */
      message.value = '';
      messageType.value = '';
    };

    const showMessage = (text: string, type: MessageType, duration: number = 3000) => { /* ... se mantiene igual ... */
      message.value = text;
      messageType.value = type;
      if (type !== 'loading') {
        setTimeout(clearMessage, duration);
      }
    };

    const addItem = async () => {
      if (!newItemName.value.trim() || !newItemCategory.value) {
        showMessage('Item name and category are required.', 'error');
        return;
      }

      isLoading.value = true;
      showMessage('Adding item...', 'loading');

      const itemPayload = {
        name: newItemName.value,
        category: newItemCategory.value,
        description: newItemDescription.value
      };

      const itemForUI: Item = {
        name: newItemName.value,
        category: newItemCategory.value,
        status: 'pending'
      };

      items.value.push(itemForUI);
      const currentItemIndex = items.value.length - 1;

      try {
        const response = await axios.post<{ data: Item, messageId: string, success: boolean, requestId: string }>(`${apiUrl}/items`, itemPayload);
        
        if (response.data && response.data.data && items.value[currentItemIndex]) {
          items.value[currentItemIndex] = { ...items.value[currentItemIndex], ...response.data.data, status: 'confirmed' };
        } else if (items.value[currentItemIndex]) {
          items.value[currentItemIndex].status = 'confirmed';
        }
        
        showMessage(`Item "${newItemName.value}" added successfully!`, 'success');
        newItemName.value = '';
        newItemCategory.value = 'food';
        newItemDescription.value = '';
      } catch (err) { // <--- Cambiar 'error' a 'err' o mantener 'error' y usarlo abajo
        console.error('Error adding item:', err);
        let errorMessage = `Failed to add item "${itemForUI.name}". Please try again.`;
        
        // Verificación de tipo para AxiosError y su estructura
        if (axios.isAxiosError(err)) { // Usar type guard de Axios
          const axiosError = err as AxiosError<ErrorResponseData>; // Hacer type assertion
          if (axiosError.response && axiosError.response.data && axiosError.response.data.details) {
            const errorDetails = axiosError.response.data.details.map(
              (d: ValidationErrorDetail) => `${d.path}: ${d.msg}` // <--- Especificar tipo para 'd'
            ).join('; ');
            errorMessage = `Validation failed: ${errorDetails}`;
          } else if (axiosError.response && axiosError.response.data && axiosError.response.data.error) {
            errorMessage = `Error: ${axiosError.response.data.error}`;
          } else if (axiosError.message) {
            errorMessage = axiosError.message;
          }
        } else if (err instanceof Error) { // Manejar otros errores estándar
            errorMessage = err.message;
        }
        
        showMessage(errorMessage, 'error', 5000);
        items.value.splice(currentItemIndex, 1);
      } finally {
        isLoading.value = false;
        if (messageType.value === 'loading') {
            clearMessage();
        }
      }
    };

    onMounted(() => {
      console.log("VUE_APP_API_URL used by App.vue:", process.env.VUE_APP_API_URL);
      console.log("Effective API base URL for App.vue:", apiUrl);
    });

    return {
      newItemName,
      newItemCategory,
      newItemDescription,
      items,
      isLoading,
      addItem,
      message,
      messageType,
      initialLoadError
    };
  },
});
</script>
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/frontend/src/main.ts
FILE_CONTENT_START
import { createApp } from 'vue'
import App from './App.vue'
import './style.css'

const app = createApp(App)

// Optional: Global error handler (from your original main.ts)
app.config.errorHandler = (err, instance, info) => {
  console.error('Global error:', err, info)
  // In production, you might want to send this to a logging service
  if (process.env.NODE_ENV === 'production') {
    // Example: sendToLoggingService(err, instance, info);
  }
}

app.mount('#app')
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/frontend/src/style.css
FILE_CONTENT_START
/* Global Resets and Base Styles */
body {
  font-family: 'Inter', system-ui, sans-serif;
  margin: 0;
  padding: 0;
  background-color: #f4f7f9; /* Light gray background */
  color: #333;
  line-height: 1.6;
  display: flex;
  justify-content: center;
  align-items: flex-start; /* Align to top for longer lists */
  min-height: 100vh;
  padding-top: 20px; /* Add some padding at the top */
}

#app {
  width: 100%;
  max-width: 600px; /* Max width for the content */
  margin: 20px;
  padding: 20px;
  background-color: #fff; /* White card background */
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08); /* Softer shadow */
}

/* Header */
h1 {
  color: #2c3e50; /* Darker shade for heading */
  text-align: center;
  margin-bottom: 25px;
  font-weight: 600;
}

/* Form Elements */
.form-container {
  display: flex;
  gap: 10px; /* Space between input and button */
  margin-bottom: 25px;
}

.input-field {
  flex-grow: 1; /* Input takes available space */
  padding: 12px 15px;
  border: 1px solid #ccc; /* Lighter border */
  border-radius: 6px;
  font-size: 1rem;
  transition: border-color 0.2s ease-in-out, box-shadow 0.2s ease-in-out;
}

.input-field:focus {
  outline: none;
  border-color: #ec4899; /* Pink focus color, from your original theme */
  box-shadow: 0 0 0 2px rgba(236, 72, 153, 0.2);
}

.btn-primary {
  padding: 12px 20px;
  background-color: #ec4899; /* Pink brand color */
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 1rem;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s ease-in-out;
}

.btn-primary:hover {
  background-color: #d93682; /* Darker pink on hover */
}

.btn-primary:disabled {
  background-color: #f3a0c8; /* Lighter pink when disabled */
  cursor: not-allowed;
}


/* Item List */
.item-list {
  list-style-type: none;
  padding: 0;
  margin: 0;
}

.item-list li {
  background-color: #f9fafb; /* Very light gray for list items */
  padding: 10px 15px;
  border: 1px solid #e5e7eb; /* Light border for items */
  border-radius: 6px;
  margin-bottom: 10px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.95rem;
}

.item-list li:last-child {
  margin-bottom: 0;
}

/* Message Styling */
.message {
  padding: 10px;
  margin-bottom: 15px;
  border-radius: 4px;
  text-align: center;
  font-size: 0.9rem;
}
.message.success {
  background-color: #e6fffa;
  color: #00796b;
  border: 1px solid #b2f5ea;
}
.message.error {
  background-color: #ffebee;
  color: #c62828;
  border: 1px solid #ffcdd2;
}
.message.loading {
  background-color: #e3f2fd;
  color: #1565c0;
  border: 1px solid #bbdefb;
}

/* Responsive adjustments */
@media (max-width: 600px) {
  body {
    padding-top: 10px;
  }
  #app {
    margin: 10px;
    padding: 15px;
  }
  .form-container {
    flex-direction: column; /* Stack input and button on small screens */
  }
  .btn-primary {
    width: 100%; /* Full width button on small screens */
  }
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/microservice-2/Dockerfile
FILE_CONTENT_START
FROM node:18-alpine AS base

WORKDIR /app

RUN apk add --no-cache dumb-init

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 -G nodejs

FROM base AS deps

COPY package*.json ./

RUN npm ci --only=production && \
    npm cache clean --force

FROM base AS builder

COPY package*.json ./

RUN npm ci --silent

COPY . .

RUN npm run lint

FROM base AS production

ENV NODE_ENV=production
ENV PORT=3001

COPY --from=deps --chown=nextjs:nodejs /app/node_modules ./node_modules

COPY --chown=nextjs:nodejs . .

RUN rm -rf tests/ *.test.js *.spec.js .eslintrc.js

LABEL maintainer="DogfyDiet Platform Team"
LABEL version="1.0.0"
LABEL description="DogfyDiet Microservice 2 - Subscriber and Data Processor"

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js || exit 1

RUN echo 'const http = require("http"); \
const options = { hostname: "localhost", port: 3001, path: "/health", timeout: 2000 }; \
const req = http.request(options, (res) => { \
  process.exit(res.statusCode === 200 ? 0 : 1); \
}); \
req.on("error", () => process.exit(1)); \
req.end();' > healthcheck.js

USER nextjs

EXPOSE 3001

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/index.js"]
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/microservice-2/package.json
FILE_CONTENT_START
{
  "name": "dogfydiet-microservice-2",
  "version": "1.0.0",
  "description": "DogfyDiet Microservice 2 - Subscriber and Data Processor",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest --coverage",
    "test:watch": "jest --watch",
    "lint": "eslint src/",
    "lint:fix": "eslint src/ --fix"
  },
  "dependencies": {
    "@google-cloud/pubsub": "^4.0.0",
    "@google-cloud/secret-manager": "^5.0.0",
    "@google-cloud/trace-agent": "^8.0.0",
    "compression": "^1.7.4",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "express-rate-limit": "^7.1.0",
    "helmet": "^7.1.0",
    "mongodb": "^6.3.0",
    "morgan": "^1.10.0",
    "winston": "^3.11.0"
  },
  "devDependencies": {
    "eslint": "^8.54.0",
    "jest": "^29.7.0",
    "nodemon": "^3.0.1",
    "supertest": "^6.3.3"
  },
  "engines": {
    "node": ">=18.0.0"
  },
  "keywords": [
    "microservice",
    "pubsub",
    "mongodb",
    "dogfydiet"
  ],
  "author": "DogfyDiet Platform Team",
  "license": "MIT"
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/microservice-2/src/index.js
FILE_CONTENT_START
const express = require('express')
const cors = require('cors')
const helmet = require('helmet')
const compression = require('compression')
const morgan = require('morgan')
const rateLimit = require('express-rate-limit')
const { PubSub } = require('@google-cloud/pubsub')
const { Firestore } = require('@google-cloud/firestore')
const winston = require('winston')
require('dotenv').config()

// Initialize Google Cloud Tracing (must be before other imports)
if (process.env.GOOGLE_CLOUD_PROJECT) {
  require('@google-cloud/trace-agent').start()
}

// Configure Winston logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { 
    service: 'microservice-2',
    version: process.env.npm_package_version || '1.0.0'
  },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
})

// Initialize Express app
const app = express()
const PORT = process.env.PORT || 3001

// Initialize Google Cloud clients
const pubsub = new PubSub({
  projectId: process.env.GOOGLE_CLOUD_PROJECT || 'nahuelgabe-test'
})

const firestore = new Firestore({
  projectId: process.env.GOOGLE_CLOUD_PROJECT || 'nahuelgabe-test'
})

const SUBSCRIPTION_NAME = process.env.PUBSUB_SUBSCRIPTION || 'dogfydiet-dev-items-subscription'
const COLLECTION_NAME = process.env.FIRESTORE_COLLECTION || 'items'

// Statistics tracking
let stats = {
  messagesProcessed: 0,
  itemsStored: 0,
  errors: 0,
  startTime: new Date(),
  lastProcessed: null
}

// Middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"]
    }
  }
}))

app.use(compression())
app.use(express.json({ limit: '10mb' }))
app.use(express.urlencoded({ extended: true, limit: '10mb' }))

// CORS configuration
app.use(cors({
  origin: process.env.CORS_ORIGIN || ['http://localhost:8080', 'https://*.googleapis.com'],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  credentials: true
}))

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: process.env.RATE_LIMIT || 100,
  message: {
    error: 'Too many requests from this IP, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false
})

app.use('/api/', limiter)

// Logging middleware
app.use(morgan('combined', {
  stream: {
    write: (message) => logger.info(message.trim())
  }
}))

// Request ID middleware
app.use((req, res, next) => {
  req.id = require('crypto').randomUUID()
  res.setHeader('X-Request-ID', req.id)
  next()
})

// Health check endpoint
app.get('/health', (req, res) => {
  const healthStatus = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'microservice-2',
    version: process.env.npm_package_version || '1.0.0',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    environment: process.env.NODE_ENV || 'development',
    stats: stats
  }
  
  res.status(200).json(healthStatus)
})

// Readiness check endpoint
app.get('/ready', async (req, res) => {
  try {
    // Check Pub/Sub connectivity
    const subscription = pubsub.subscription(SUBSCRIPTION_NAME)
    await subscription.exists()
    
    // Check Firestore connectivity
    await firestore.collection(COLLECTION_NAME).limit(1).get()
    
    res.status(200).json({
      status: 'ready',
      timestamp: new Date().toISOString(),
      checks: {
        pubsub: 'connected',
        firestore: 'connected'
      }
    })
  } catch (error) {
    logger.error('Readiness check failed:', error)
    res.status(503).json({
      status: 'not ready',
      timestamp: new Date().toISOString(),
      error: error.message
    })
  }
})

// Metrics endpoint for monitoring
app.get('/metrics', (req, res) => {
  const metrics = {
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    cpu: process.cpuUsage(),
    environment: process.env.NODE_ENV || 'development',
    nodejs_version: process.version,
    stats: stats,
    processing_rate: stats.messagesProcessed / (process.uptime() / 60) // messages per minute
  }
  
  res.status(200).json(metrics)
})

// API Routes

// Get items from Firestore
app.get('/api/items', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50
    const offset = parseInt(req.query.offset) || 0
    
    const snapshot = await firestore
      .collection(COLLECTION_NAME)
      .orderBy('timestamp', 'desc')
      .limit(limit)
      .offset(offset)
      .get()
    
    const items = []
    snapshot.forEach(doc => {
      items.push({
        id: doc.id,
        ...doc.data()
      })
    })
    
    logger.info(`Retrieved ${items.length} items from Firestore`, {
      requestId: req.id,
      count: items.length,
      limit,
      offset
    })
    
    res.status(200).json({
      items: items,
      count: items.length,
      limit,
      offset,
      requestId: req.id
    })
    
  } catch (error) {
    logger.error('Error retrieving items from Firestore:', {
      requestId: req.id,
      error: error.message,
      stack: error.stack
    })
    
    res.status(500).json({
      error: 'Failed to retrieve items',
      requestId: req.id
    })
  }
})

// Get statistics
app.get('/api/stats', (req, res) => {
  const uptime = process.uptime()
  const processingRate = stats.messagesProcessed / (uptime / 60) // per minute
  
  res.status(200).json({
    ...stats,
    uptime: uptime,
    processingRate: Math.round(processingRate * 100) / 100,
    requestId: req.id
  })
})

// Function to process Pub/Sub messages
const processMessage = async (message) => {
  const startTime = Date.now()
  
  try {
    // Parse message data
    const messageData = JSON.parse(message.data.toString())
    const attributes = message.attributes || {}
    
    logger.info('Processing message:', {
      messageId: message.id,
      eventType: attributes.eventType,
      source: attributes.source,
      itemId: messageData.id
    })
    
    // Validate message data
    if (!messageData.id || !messageData.name || !messageData.category) {
      throw new Error('Invalid message data: missing required fields')
    }
    
    // Prepare document for Firestore
    const document = {
      ...messageData,
      processedAt: new Date().toISOString(),
      processedBy: 'microservice-2',
      messageId: message.id,
      messageAttributes: attributes
    }
    
    // Store in Firestore
    const docRef = firestore.collection(COLLECTION_NAME).doc(messageData.id)
    await docRef.set(document, { merge: true })
    
    // Update statistics
    stats.messagesProcessed++
    stats.itemsStored++
    stats.lastProcessed = new Date().toISOString()
    
    const processingTime = Date.now() - startTime
    
    logger.info('Message processed successfully:', {
      messageId: message.id,
      itemId: messageData.id,
      processingTime: `${processingTime}ms`,
      category: messageData.category
    })
    
    // Acknowledge the message
    message.ack()
    
  } catch (error) {
    stats.errors++
    
    logger.error('Error processing message:', {
      messageId: message.id,
      error: error.message,
      stack: error.stack,
      processingTime: `${Date.now() - startTime}ms`
    })
    
    // Nack the message to retry later
    message.nack()
  }
}

// Initialize Pub/Sub subscription
const initializeSubscription = () => {
  const subscription = pubsub.subscription(SUBSCRIPTION_NAME)
  
  // Configure subscription options
  subscription.options = {
    ackDeadlineSeconds: 60,
    maxMessages: 10,
    allowExcessMessages: false,
    maxExtension: 600
  }
  
  // Set up message handler
  subscription.on('message', processMessage)
  
  // Handle subscription errors
  subscription.on('error', (error) => {
    logger.error('Subscription error:', {
      error: error.message,
      stack: error.stack
    })
    stats.errors++
  })
  
  // Handle subscription close
  subscription.on('close', () => {
    logger.info('Subscription closed')
  })
  
  logger.info('Pub/Sub subscription initialized:', {
    subscriptionName: SUBSCRIPTION_NAME,
    options: subscription.options
  })
  
  return subscription
}

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', {
    requestId: req.id,
    error: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method
  })

  res.status(500).json({
    error: 'Internal server error',
    requestId: req.id
  })
})

// 404 handler
app.use('*', (req, res) => {
  logger.warn('Route not found:', {
    requestId: req.id,
    url: req.url,
    method: req.method
  })
  
  res.status(404).json({
    error: 'Route not found',
    requestId: req.id
  })
})

// Graceful shutdown
let subscription
const gracefulShutdown = (signal) => {
  logger.info(`Received ${signal}. Starting graceful shutdown...`)
  
  // Close subscription
  if (subscription) {
    subscription.close()
  }
  
  server.close(() => {
    logger.info('HTTP server closed.')
    
    // Close Google Cloud connections
    Promise.all([
      pubsub.close(),
      firestore.terminate()
    ]).then(() => {
      logger.info('Google Cloud connections closed.')
      process.exit(0)
    }).catch((error) => {
      logger.error('Error closing Google Cloud connections:', error)
      process.exit(1)
    })
  })
}

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
  logger.info(`Microservice 2 started on port ${PORT}`, {
    port: PORT,
    environment: process.env.NODE_ENV || 'development',
    nodeVersion: process.version,
    subscriptionName: SUBSCRIPTION_NAME,
    collectionName: COLLECTION_NAME
  })
  
  // Initialize Pub/Sub subscription
  subscription = initializeSubscription()
})

// Handle graceful shutdown
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'))
process.on('SIGINT', () => gracefulShutdown('SIGINT'))

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', {
    error: error.message,
    stack: error.stack
  })
  process.exit(1)
})

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection:', {
    reason: reason,
    promise: promise
  })
  process.exit(1)
})

module.exports = app
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/microservice-1/Dockerfile
FILE_CONTENT_START
FROM node:18-alpine AS base

WORKDIR /app

RUN apk add --no-cache dumb-init

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 -G nodejs

FROM base AS deps

COPY package*.json ./

RUN npm ci --only=production && \
    npm cache clean --force

FROM base AS builder

COPY package*.json ./

RUN npm ci --silent

COPY . .

RUN npm run lint

FROM base AS production

ENV NODE_ENV=production
ENV PORT=3000

COPY --from=deps --chown=nextjs:nodejs /app/node_modules ./node_modules

COPY --chown=nextjs:nodejs . .

RUN rm -rf tests/ *.test.js *.spec.js .eslintrc.js

LABEL maintainer="DogfyDiet Platform Team"
LABEL version="1.0.0"
LABEL description="DogfyDiet Microservice 1 - API Gateway and Publisher"

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js || exit 1

RUN echo 'const http = require("http"); \
const options = { hostname: "localhost", port: 3000, path: "/health", timeout: 2000 }; \
const req = http.request(options, (res) => { \
  process.exit(res.statusCode === 200 ? 0 : 1); \
}); \
req.on("error", () => process.exit(1)); \
req.end();' > healthcheck.js

USER nextjs

EXPOSE 3000

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/index.js"]
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/microservice-1/package.json
FILE_CONTENT_START
{
  "name": "dogfydiet-microservice-1",
  "version": "1.0.0",
  "description": "DogfyDiet Microservice 1 - API Gateway and Publisher",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "lint": "eslint src/",
    "lint:fix": "eslint src/ --fix",
    "docker:build": "docker build -t microservice-1 .",
    "docker:run": "docker run -p 3000:3000 microservice-1"
  },
  "dependencies": {
    "@google-cloud/logging": "^10.5.0",
    "@google-cloud/monitoring": "^4.0.0",
    "@google-cloud/pubsub": "^4.0.7",
    "@google-cloud/trace-agent": "^7.1.0",
    "compression": "^1.7.4",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "express-rate-limit": "^6.10.0",
    "express-validator": "^7.0.1",
    "helmet": "^7.0.0",
    "joi": "^17.10.1",
    "morgan": "^1.10.0",
    "uuid": "^9.0.0",
    "winston": "^3.10.0"
  },
  "devDependencies": {
    "eslint": "^8.49.0",
    "eslint-config-standard": "^17.1.0",
    "eslint-plugin-import": "^2.28.1",
    "eslint-plugin-node": "^11.1.0",
    "eslint-plugin-promise": "^6.1.1",
    "jest": "^29.7.0",
    "nodemon": "^3.0.1",
    "supertest": "^6.3.3"
  },
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=8.0.0"
  },
  "keywords": [
    "microservice",
    "api",
    "pubsub",
    "google-cloud",
    "express"
  ],
  "author": "DogfyDiet Platform Team",
  "license": "UNLICENSED"
}
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---
FILE_PATH_START
./applications/microservice-1/src/index.js
FILE_CONTENT_START
const express = require('express')
const cors = require('cors')
const helmet = require('helmet')
const compression = require('compression')
const morgan = require('morgan')
const rateLimit = require('express-rate-limit')
const { body, validationResult } = require('express-validator')
const { PubSub } = require('@google-cloud/pubsub')
const winston = require('winston')
require('dotenv').config()

// Initialize Google Cloud Tracing (must be before other imports)
if (process.env.GOOGLE_CLOUD_PROJECT) {
  require('@google-cloud/trace-agent').start()
}

// Configure Winston logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { 
    service: 'microservice-1',
    version: process.env.npm_package_version || '1.0.0'
  },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
})

// Initialize Express app
const app = express()
const PORT = process.env.PORT || 3000

// Initialize Pub/Sub client
const pubsub = new PubSub({
  projectId: process.env.GOOGLE_CLOUD_PROJECT || 'nahuelgabe-test'
})

const TOPIC_NAME = process.env.PUBSUB_TOPIC || 'dogfydiet-dev-items-topic'

// Middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"]
    }
  }
}))

app.use(compression())
app.use(express.json({ limit: '10mb' }))
app.use(express.urlencoded({ extended: true, limit: '10mb' }))

// CORS configuration
app.use(cors({
  origin: process.env.CORS_ORIGIN || ['http://localhost:8080', 'https://*.googleapis.com'],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  credentials: true
}))

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: process.env.RATE_LIMIT || 100, // limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests from this IP, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false
})

app.use('/api/', limiter)

// Logging middleware
app.use(morgan('combined', {
  stream: {
    write: (message) => logger.info(message.trim())
  }
}))

// Request ID middleware
app.use((req, res, next) => {
  req.id = require('crypto').randomUUID()
  res.setHeader('X-Request-ID', req.id)
  next()
})

// Health check endpoint
app.get('/health', (req, res) => {
  const healthStatus = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'microservice-1',
    version: process.env.npm_package_version || '1.0.0',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    environment: process.env.NODE_ENV || 'development'
  }
  
  res.status(200).json(healthStatus)
})

// Readiness check endpoint
app.get('/ready', async (req, res) => {
  try {
    // Check Pub/Sub connectivity
    const topic = pubsub.topic(TOPIC_NAME)
    await topic.exists()
    
    res.status(200).json({
      status: 'ready',
      timestamp: new Date().toISOString(),
      checks: {
        pubsub: 'connected'
      }
    })
  } catch (error) {
    logger.error('Readiness check failed:', error)
    res.status(503).json({
      status: 'not ready',
      timestamp: new Date().toISOString(),
      error: error.message
    })
  }
})

// Metrics endpoint for monitoring
app.get('/metrics', (req, res) => {
  const metrics = {
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    cpu: process.cpuUsage(),
    environment: process.env.NODE_ENV || 'development',
    nodejs_version: process.version
  }
  
  res.status(200).json(metrics)
})

// Validation middleware for items
const validateItem = [
  body('name')
    .isLength({ min: 1, max: 100 })
    .trim()
    .escape()
    .withMessage('Name must be between 1 and 100 characters'),
  body('category')
    .isIn(['treats', 'food', 'supplements', 'toys'])
    .withMessage('Category must be one of: treats, food, supplements, toys'),
  body('description')
    .optional()
    .isLength({ max: 500 })
    .trim()
    .escape()
    .withMessage('Description must be less than 500 characters')
]

// API Routes

// Get items endpoint (for frontend compatibility)
app.get('/api/items', async (req, res) => {
  try {
    // This is a simple in-memory store for demo purposes
    // In production, this would typically come from a database or cache
    const items = req.app.locals.items || []
    
    logger.info(`Retrieved ${items.length} items`, {
      requestId: req.id,
      count: items.length
    })
    
    res.status(200).json(items)
  } catch (error) {
    logger.error('Error retrieving items:', {
      requestId: req.id,
      error: error.message,
      stack: error.stack
    })
    
    res.status(500).json({
      error: 'Internal server error',
      requestId: req.id
    })
  }
})

// Create item endpoint
app.post('/api/items', validateItem, async (req, res) => {
  try {
    // Check validation results
    const errors = validationResult(req)
    if (!errors.isEmpty()) {
      logger.warn('Validation failed:', {
        requestId: req.id,
        errors: errors.array()
      })
      
      return res.status(400).json({
        error: 'Validation failed',
        details: errors.array(),
        requestId: req.id
      })
    }

    const itemData = {
      id: require('crypto').randomUUID(),
      name: req.body.name,
      category: req.body.category,
      description: req.body.description || '',
      timestamp: new Date().toISOString(),
      source: 'microservice-1',
      requestId: req.id
    }

    // Store item locally for GET requests (demo purposes)
    if (!req.app.locals.items) {
      req.app.locals.items = []
    }
    req.app.locals.items.unshift(itemData)

    // Publish message to Pub/Sub
    const topic = pubsub.topic(TOPIC_NAME)
    const messageData = Buffer.from(JSON.stringify(itemData))
    
    const messageId = await topic.publishMessage({
      data: messageData,
      attributes: {
        eventType: 'item.created',
        source: 'microservice-1',
        version: '1.0',
        timestamp: itemData.timestamp,
        requestId: req.id
      }
    })

    logger.info('Item created and published:', {
      requestId: req.id,
      itemId: itemData.id,
      messageId: messageId,
      category: itemData.category
    })

    res.status(201).json({
      success: true,
      data: itemData,
      messageId: messageId,
      requestId: req.id
    })

  } catch (error) {
    logger.error('Error creating item:', {
      requestId: req.id,
      error: error.message,
      stack: error.stack
    })

    res.status(500).json({
      error: 'Failed to create item',
      requestId: req.id
    })
  }
})

// API documentation endpoint
app.get('/api/docs', (req, res) => {
  const apiDocs = {
    name: 'DogfyDiet Microservice 1 API',
    version: '1.0.0',
    description: 'API Gateway and Publisher service for DogfyDiet platform',
    endpoints: {
      'GET /health': 'Health check endpoint',
      'GET /ready': 'Readiness check endpoint', 
      'GET /metrics': 'Metrics endpoint for monitoring',
      'GET /api/items': 'Retrieve all items',
      'POST /api/items': 'Create a new item and publish to Pub/Sub',
      'GET /api/docs': 'This documentation'
    },
    schemas: {
      item: {
        id: 'string (UUID)',
        name: 'string (1-100 chars)',
        category: 'string (treats|food|supplements|toys)',
        description: 'string (optional, max 500 chars)',
        timestamp: 'string (ISO 8601)',
        source: 'string',
        requestId: 'string (UUID)'
      }
    }
  }
  
  res.status(200).json(apiDocs)
})

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', {
    requestId: req.id,
    error: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method
  })

  res.status(500).json({
    error: 'Internal server error',
    requestId: req.id
  })
})

// 404 handler
app.use('*', (req, res) => {
  logger.warn('Route not found:', {
    requestId: req.id,
    url: req.url,
    method: req.method
  })
  
  res.status(404).json({
    error: 'Route not found',
    requestId: req.id
  })
})

// Graceful shutdown
const gracefulShutdown = (signal) => {
  logger.info(`Received ${signal}. Starting graceful shutdown...`)
  
  server.close(() => {
    logger.info('HTTP server closed.')
    
    // Close Pub/Sub connections
    pubsub.close().then(() => {
      logger.info('Pub/Sub connections closed.')
      process.exit(0)
    }).catch((error) => {
      logger.error('Error closing Pub/Sub connections:', error)
      process.exit(1)
    })
  })
}

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
  logger.info(`Microservice 1 started on port ${PORT}`, {
    port: PORT,
    environment: process.env.NODE_ENV || 'development',
    nodeVersion: process.version,
    pubsubTopic: TOPIC_NAME
  })
})

// Handle graceful shutdown
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'))
process.on('SIGINT', () => gracefulShutdown('SIGINT'))

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', {
    error: error.message,
    stack: error.stack
  })
  process.exit(1)
})

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection:', {
    reason: reason,
    promise: promise
  })
  process.exit(1)
})

module.exports = app
FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---

FILE_CONTENT_END
---DIVIDER_BETWEEN_FILES---

