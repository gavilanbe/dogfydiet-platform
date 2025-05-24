# Enable required APIs
resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = "${var.name_prefix}-gke-cluster"
  location = var.region
  
  description = "GKE cluster for ${var.environment} environment"
  
  # Network configuration
  network    = var.network_name
  subnetwork = var.subnet_name
  
  # Configure private cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false  # Allow public access to API server for CI/CD
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
    
    master_global_access_config {
      enabled = true
    }
  }
  
  # IP allocation policy for secondary ranges
  ip_allocation_policy {
    cluster_secondary_range_name  = "${var.name_prefix}-pods"
    services_secondary_range_name = "${var.name_prefix}-services"
  }
  
  # Master authorized networks - Allow CI/CD and management access
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"  # Restrict this in production
      display_name = "All networks"
    }
  }
  
  # Network policy
  network_policy {
    enabled  = true
    provider = "CALICO"
  }
  
  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  
  # Addons configuration
  addons_config {
    http_load_balancing {
      disabled = false
    }
    
    horizontal_pod_autoscaling {
      disabled = false
    }
    
    network_policy_config {
      disabled = false
    }
    
    dns_cache_config {
      enabled = true
    }
    
    gcp_filestore_csi_driver_config {
      enabled = false
    }
    
    gcs_fuse_csi_driver_config {
      enabled = false
    }
  }
  
  # Release channel for automatic upgrades
  release_channel {
    channel = var.release_channel
  }
  
  # Binary authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }
  
  # Database encryption
  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.gke.id
  }
  
  # Monitoring and logging
  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "APISERVER",
      "CONTROLLER_MANAGER",
      "SCHEDULER"
    ]
    
    managed_prometheus {
      enabled = true
    }
  }
  
  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "APISERVER",
      "CONTROLLER_MANAGER",
      "SCHEDULER"
    ]
  }
  
  # Security configuration
  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }
  
  # Maintenance policy
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }
  
  # Resource labels
  resource_labels = var.labels
  
  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1
  
  depends_on = [
    google_project_service.container,
    google_project_service.compute,
    google_kms_crypto_key_iam_binding.gke
  ]
}

# Primary Node Pool
resource "google_container_node_pool" "primary" {
  name       = "${var.name_prefix}-primary-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  
  # Autoscaling configuration
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }
  
  # Management configuration
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  
  # Node configuration
  node_config {
    preemptible  = var.preemptible_nodes
    machine_type = var.node_machine_type
    disk_size_gb = var.node_disk_size_gb
    disk_type    = var.node_disk_type
    image_type   = "COS_CONTAINERD"
    
    # Service account with minimal permissions
    service_account = google_service_account.gke_nodes.email
    
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    
    # Security configuration
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
    
    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    
    # Resource labels
    labels = merge(var.labels, {
      node_pool = "primary"
    })
    
    # Node taints for workload separation
    dynamic "taint" {
      for_each = var.node_taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
    
    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }
    
    tags = ["gke-node", "${var.name_prefix}-gke-node"]
  }
  
  # Upgrade settings
  upgrade_settings {
    strategy         = "SURGE"
    max_surge        = 1
    max_unavailable  = 0
  }
}

# KMS Key for GKE encryption
resource "google_kms_key_ring" "gke" {
  name     = "${var.name_prefix}-gke-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "gke" {
  name     = "${var.name_prefix}-gke-key"
  key_ring = google_kms_key_ring.gke.id
  
  lifecycle {
    prevent_destroy = true
  }
}

# Service Account for GKE nodes
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.name_prefix}-gke-nodes"
  display_name = "GKE Nodes Service Account"
  description  = "Service account for GKE nodes in ${var.environment} environment"
}

# IAM bindings for GKE nodes service account
resource "google_project_iam_member" "gke_nodes_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_registry" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# KMS IAM binding for GKE service account
data "google_project" "current" {}

resource "google_kms_crypto_key_iam_binding" "gke" {
  crypto_key_id = google_kms_crypto_key.gke.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  
  members = [
    "serviceAccount:service-${data.google_project.current.number}@container-engine-robot.iam.gserviceaccount.com",
  ]
}