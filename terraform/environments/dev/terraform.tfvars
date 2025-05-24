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