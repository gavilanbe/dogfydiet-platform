output "frontend_bucket_name" {
  description = "The name of the frontend storage bucket"
  value       = google_storage_bucket.frontend.name
}

output "frontend_bucket_url" {
  description = "The URL of the frontend storage bucket"
  value       = google_storage_bucket.frontend.url
}

output "frontend_bucket_self_link" {
  description = "The self-link of the frontend storage bucket"
  value       = google_storage_bucket.frontend.self_link
}

output "frontend_bucket_website_url" {
  description = "The website URL of the frontend storage bucket"
  value       = "https://storage.googleapis.com/${google_storage_bucket.frontend.name}/index.html"
}

output "backend_bucket_id" {
  description = "The ID of the backend bucket resource"
  value       = google_compute_backend_bucket.frontend.id
}

output "backend_bucket_self_link" {
  description = "The self-link of the backend bucket"
  value       = google_compute_backend_bucket.frontend.self_link
}