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