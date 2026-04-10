output "web_origin_ip" {
  description = "Elastic IP for the web origin. Point Cloudflare DNS here."
  value       = aws_eip.web.public_ip
}

output "web_origin_url" {
  description = "Expected public HTTPS URL after you create the proxied Cloudflare DNS record."
  value       = "https://${var.web_hostname}"
}

output "web_hostname" {
  description = "Hostname that should be configured in Cloudflare."
  value       = var.web_hostname
}

output "cdn_hostname" {
  description = "Hostname that should be configured in Cloudflare for static/media/frontend assets."
  value       = var.cdn_hostname
}

output "web_instance_id" {
  description = "EC2 instance ID for the web origin host."
  value       = aws_instance.web.id
}

output "cloudflare_origin_cert_parameter_name" {
  description = "SSM parameter name storing the Cloudflare Origin CA certificate PEM."
  value       = var.cloudflare_origin_cert_parameter_name
}

output "cloudflare_origin_key_parameter_name" {
  description = "SSM parameter name storing the Cloudflare Origin CA private key PEM."
  value       = var.cloudflare_origin_key_parameter_name
}

output "bucket_name" {
  description = "S3 bucket used for the frontend, Django media, and Django static files."
  value       = module.foundation.bucket_name
}

output "bucket_website_endpoint" {
  description = "Website endpoint for the S3 bucket."
  value       = module.foundation.bucket_website_endpoint
}

output "database_endpoint" {
  description = "RDS PostgreSQL endpoint."
  value       = module.foundation.database_endpoint
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint."
  value       = module.foundation.redis_endpoint
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.main.name
}

output "web_service_name" {
  description = "ECS web service name."
  value       = aws_ecs_service.web.name
}

output "worker_service_name" {
  description = "ECS worker service name."
  value       = aws_ecs_service.worker.name
}
