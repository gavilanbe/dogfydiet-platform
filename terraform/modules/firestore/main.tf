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
  project       = var.project_id
  location_id   = var.firestore_location
  database_type = "CLOUD_FIRESTORE"

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

# Firestore Indexes (if any custom indexes are needed)
resource "google_firestore_index" "items_by_timestamp" {
  count = var.create_indexes ? 1 : 0

  project    = var.project_id
  database   = google_firestore_database.main.name
  collection = "items"

  fields {
    field_path = "timestamp"
    order      = "DESCENDING"
  }

  fields {
    field_path = "__name__"
    order      = "DESCENDING"
  }
}

resource "google_firestore_index" "items_by_user_and_timestamp" {
  count = var.create_indexes ? 1 : 0

  project    = var.project_id
  database   = google_firestore_database.main.name
  collection = "items"

  fields {
    field_path = "userId"
    order      = "ASCENDING"
  }

  fields {
    field_path = "timestamp"
    order      = "DESCENDING"
  }

  fields {
    field_path = "__name__"
    order      = "DESCENDING"
  }
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
      filter          = "resource.type=\"gce_instance\" AND metric.type=\"firestore.googleapis.com/api/request_count\""
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
      filter          = "resource.type=\"gce_instance\" AND metric.type=\"firestore.googleapis.com/api/request_count\""
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