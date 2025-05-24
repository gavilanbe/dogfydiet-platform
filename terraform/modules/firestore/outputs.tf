output "database_name" {
  description = "The name of the Firestore database"
  value       = google_firestore_database.main.name
}

output "database_id" {
  description = "The ID of the Firestore database"
  value       = google_firestore_database.main.id
}

output "app_engine_application_id" {
  description = "The App Engine application ID"
  value       = google_app_engine_application.default.app_id
}

output "firestore_location" {
  description = "The location of the Firestore database"
  value       = var.firestore_location
}

output "database_connection_string" {
  description = "Connection string for the Firestore database"
  value       = "projects/${var.project_id}/databases/${google_firestore_database.main.name}"
}

output "backup_schedule_name" {
  description = "The name of the backup schedule (if enabled)"
  value       = var.enable_backup ? google_firestore_backup_schedule.main[0].name : ""
}

output "security_rules_deployed" {
  description = "Whether security rules have been deployed"
  value       = var.deploy_security_rules
}