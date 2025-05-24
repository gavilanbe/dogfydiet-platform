# terraform/environments/dev/main.tf
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

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  }
}

# Local values for consistent naming and tagging
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
  
  project_id   = var.project_id
  region       = var.region
  name_prefix  = local.name_prefix
  environment  = local.environment
  
  labels = local.common_labels
}

# GKE Module
module "gke" {
  source = "../../modules/gke"
  
  project_id     = var.project_id
  region         = var.region
  name_prefix    = local.name_prefix
  environment    = local.environment
  
  network_name    = module.vpc.network_name
  subnet_name     = module.vpc.private_subnet_name
  
  labels = local.common_labels
  
  depends_on = [module.vpc]
}

# Cloud Storage Module for Frontend
module "storage" {
  source = "../../modules/storage"
  
  project_id  = var.project_id
  name_prefix = local.name_prefix
  environment = local.environment
  
  labels = local.common_labels
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
  
  project_id     = var.project_id
  name_prefix    = local.name_prefix
  environment    = local.environment
  
  gke_cluster_name = module.gke.cluster_name
  
  labels = local.common_labels
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"
  
  project_id      = var.project_id
  name_prefix     = local.name_prefix
  environment     = local.environment
  
  gke_cluster_name = module.gke.cluster_name
  
  labels = local.common_labels
  
  depends_on = [module.gke]
}