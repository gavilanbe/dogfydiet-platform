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
  gke_neg_zone = "us-central1-a"
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