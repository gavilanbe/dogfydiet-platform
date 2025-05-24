# terraform/environments/dev/terraform.tfvars

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

# GKE Cluster Configuration
gke_node_count        = 2
gke_node_machine_type = "e2-standard-2"
gke_node_disk_size    = 50
gke_max_node_count    = 5
gke_min_node_count    = 1

# Monitoring Configuration
notification_email = "nahuelgavilanbe@gmail.com"