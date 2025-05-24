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
          audience             = var.oidc_audience
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
  
  message_retention_duration = "604800s"  # 7 days
  
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
  message_retention_duration = "604800s"  # 7 days
  retain_acked_messages      = true
  
  expiration_policy {
    ttl = "2678400s"  # 31 days
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
  role        = "roles/pubsub.subscriber"
  member      = "serviceAccount:${each.value}"
}

# Monitoring: Topic metrics
resource "google_monitoring_alert_policy" "topic_undelivered_messages" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "${var.name_prefix} Pub/Sub Topic Undelivered Messages"
  
  documentation {
    content = "Alert when there are too many undelivered messages in the Pub/Sub topic"
  }
  
  conditions {
    display_name = "Undelivered messages condition"
    
    condition_threshold {
      filter          = "resource.type=\"pubsub_topic\" AND resource.labels.topic_id=\"${google_pubsub_topic.main.name}\""
      duration        = "300s"
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = var.undelivered_messages_threshold
      
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
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

# Monitoring: Subscription age metrics
resource "google_monitoring_alert_policy" "subscription_oldest_unacked_message" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "${var.name_prefix} Pub/Sub Subscription Oldest Unacked Message"
  
  documentation {
    content = "Alert when messages in subscription are too old"
  }
  
  conditions {
    display_name = "Oldest unacked message age condition"
    
    condition_threshold {
      filter          = "resource.type=\"pubsub_subscription\" AND resource.labels.subscription_id=\"${google_pubsub_subscription.microservice_2.name}\""
      duration        = "300s"
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = var.oldest_unacked_message_threshold
      
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MAX"
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