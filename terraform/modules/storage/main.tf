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