output "topic_name" {
  description = "The name of the Pub/Sub topic"
  value       = google_pubsub_topic.main.name
}

output "topic_id" {
  description = "The ID of the Pub/Sub topic"
  value       = google_pubsub_topic.main.id
}

output "subscription_name" {
  description = "The name of the Pub/Sub subscription"
  value       = google_pubsub_subscription.microservice_2.name
}

output "subscription_id" {
  description = "The ID of the Pub/Sub subscription"
  value       = google_pubsub_subscription.microservice_2.id
}

output "dead_letter_topic_name" {
  description = "The name of the dead letter topic (if enabled)"
  value       = var.enable_dead_letter_queue ? google_pubsub_topic.dead_letter[0].name : ""
}

output "dead_letter_subscription_name" {
  description = "The name of the dead letter subscription (if enabled)"
  value       = var.enable_dead_letter_queue ? google_pubsub_subscription.dead_letter[0].name : ""
}

output "schema_name" {
  description = "The name of the Pub/Sub schema (if created)"
  value       = var.create_schema ? google_pubsub_schema.main[0].name : ""
}

# Connection strings for applications
output "topic_connection_string" {
  description = "Connection string for publishing to the topic"
  value       = "projects/${var.project_id}/topics/${google_pubsub_topic.main.name}"
}

output "subscription_connection_string" {
  description = "Connection string for subscribing to the subscription"
  value       = "projects/${var.project_id}/subscriptions/${google_pubsub_subscription.microservice_2.name}"
}