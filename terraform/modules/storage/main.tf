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
  
  # Versioning configuration
  versioning {
    enabled = var.enable_versioning
  }
  
  # Lifecycle management
  lifecycle_rule {
    condition {
      age = var.object_lifecycle_days
    }
    action {
      type = "Delete"
    }
  }
  
  # Public access prevention (we'll use IAM for public access)
  public_access_prevention = "inherited"
  
  # Uniform bucket-level access
  uniform_bucket_level_access = true
  
  labels = var.labels
  
  depends_on = [google_project_service.storage]
}

# Random suffix for unique bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Make bucket publicly readable for static website hosting
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.frontend.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Load balancer backend bucket
resource "google_compute_backend_bucket" "frontend" {
  name        = "${var.name_prefix}-frontend-backend"
  description = "Backend bucket for frontend static files"
  bucket_name = google_storage_bucket.frontend.name
  
  enable_cdn = var.enable_cdn
  
  dynamic "cdn_policy" {
    for_each = var.enable_cdn ? [1] : []
    content {
      cache_mode                   = "CACHE_ALL_STATIC"
      default_ttl                  = var.cdn_default_ttl
      max_ttl                      = var.cdn_max_ttl
      client_ttl                   = var.cdn_client_ttl
      negative_caching             = true
      serve_while_stale            = 86400
      
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

# URL map for load balancer
resource "google_compute_url_map" "frontend" {
  name            = "${var.name_prefix}-frontend-urlmap"
  description     = "URL map for frontend application"
  default_service = google_compute_backend_bucket.frontend.id
  
  # Host rule for custom domain (if provided)
  dynamic "host_rule" {
    for_each = var.custom_domain != "" ? [1] : []
    content {
      hosts        = [var.custom_domain]
      path_matcher = "main"
    }
  }
  
  # Path matcher for SPA routing
  path_matcher {
    name            = "main"
    default_service = google_compute_backend_bucket.frontend.id
    
    # Route API calls to backend (if needed)
    dynamic "path_rule" {
      for_each = var.api_backend_service != "" ? [1] : []
      content {
        paths   = ["/api/*"]
        service = var.api_backend_service
      }
    }
    
    # Catch-all for SPA routing
    path_rule {
      paths   = ["/*"]
      service = google_compute_backend_bucket.frontend.id
    }
  }
}

# HTTP(S) Load Balancer
resource "google_compute_target_https_proxy" "frontend" {
  count = var.enable_https ? 1 : 0
  
  name             = "${var.name_prefix}-frontend-https-proxy"
  description      = "HTTPS proxy for frontend application"
  url_map          = google_compute_url_map.frontend.id
  ssl_certificates = [google_compute_managed_ssl_certificate.frontend[0].id]
}

resource "google_compute_target_http_proxy" "frontend" {
  name        = "${var.name_prefix}-frontend-http-proxy"
  description = "HTTP proxy for frontend application"
  url_map     = google_compute_url_map.frontend.id
}

# SSL Certificate (if HTTPS enabled and custom domain provided)
resource "google_compute_managed_ssl_certificate" "frontend" {
  count = var.enable_https && var.custom_domain != "" ? 1 : 0
  
  name        = "${var.name_prefix}-frontend-ssl-cert"
  description = "Managed SSL certificate for frontend"
  
  managed {
    domains = [var.custom_domain]
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Global forwarding rules
resource "google_compute_global_forwarding_rule" "frontend_https" {
  count = var.enable_https ? 1 : 0
  
  name                  = "${var.name_prefix}-frontend-https-forwarding-rule"
  description           = "HTTPS forwarding rule for frontend"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.frontend[0].id
  ip_address            = google_compute_global_address.frontend.id
}

resource "google_compute_global_forwarding_rule" "frontend_http" {
  name                  = "${var.name_prefix}-frontend-http-forwarding-rule"
  description           = "HTTP forwarding rule for frontend"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.frontend.id
  ip_address            = google_compute_global_address.frontend.id
}

# Global static IP address
resource "google_compute_global_address" "frontend" {
  name         = "${var.name_prefix}-frontend-ip"
  description  = "Static IP address for frontend load balancer"
  address_type = "EXTERNAL"
}