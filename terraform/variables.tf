variable "aws_region" {
  description = "AWS region for this stack."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Short name used as the prefix for AWS resources."
  type        = string
}

variable "environment" {
  description = "Environment name such as dev, staging, or prod."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the application VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDR blocks for the ECS EC2 instances."
  type        = list(string)
  default     = ["10.42.0.0/24", "10.42.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Two private subnet CIDR blocks for RDS and ElastiCache."
  type        = list(string)
  default     = ["10.42.10.0/24", "10.42.11.0/24"]
}

variable "web_instance_type" {
  description = "EC2 instance type for the ECS web host."
  type        = string
  default     = "t3.small"
}

variable "worker_instance_type" {
  description = "EC2 instance type for the ECS worker host."
  type        = string
  default     = "t3.medium"
}

variable "web_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the web origin over HTTP/HTTPS. Lock this down to Cloudflare egress ranges if you want origin protection."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "web_hostname" {
  description = "Public hostname that Cloudflare will proxy to the web origin."
  type        = string
}

variable "cdn_hostname" {
  description = "Public hostname for static/media/frontend assets when serving S3 through Cloudflare. If unset, defaults to the bucket regional domain."
  type        = string
  default     = ""
}

variable "cloudflare_ipv4_cidrs" {
  description = "Cloudflare IPv4 ranges allowed to fetch public assets from the S3 website endpoint."
  type        = list(string)
  default = [
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "162.158.0.0/15",
    "104.16.0.0/13",
    "104.24.0.0/14",
    "172.64.0.0/13",
    "131.0.72.0/22",
  ]
}

variable "web_image" {
  description = "Container image URI for the web service."
  type        = string
}

variable "worker_image" {
  description = "Container image URI for the worker service."
  type        = string
}

variable "web_container_port" {
  description = "Container port exposed by the Django web container."
  type        = number
  default     = 8000
}

variable "web_host_port" {
  description = "Private host port used by the ECS web task behind the host-level reverse proxy."
  type        = number
  default     = 8080
}

variable "cloudflare_origin_cert_parameter_name" {
  description = "SSM SecureString parameter name containing the Cloudflare Origin CA certificate PEM."
  type        = string
}

variable "cloudflare_origin_key_parameter_name" {
  description = "SSM SecureString parameter name containing the Cloudflare Origin CA private key PEM."
  type        = string
}

variable "caddy_version" {
  description = "Caddy version installed on the web EC2 instance."
  type        = string
  default     = "2.10.2"
}

variable "caddy_access_log_path" {
  description = "Path on the web EC2 instance where Caddy writes access logs."
  type        = string
  default     = "/var/log/caddy/access.log"
}

variable "web_task_cpu" {
  description = "CPU units reserved for the web task definition."
  type        = number
  default     = 512
}

variable "web_task_memory" {
  description = "Hard memory limit in MiB for the web task definition."
  type        = number
  default     = 1024
}

variable "worker_task_cpu" {
  description = "CPU units reserved for the worker task definition."
  type        = number
  default     = 512
}

variable "worker_task_memory" {
  description = "Hard memory limit in MiB for the worker task definition."
  type        = number
  default     = 1024
}

variable "web_desired_count" {
  description = "Desired ECS task count for the web service."
  type        = number
  default     = 1
}

variable "worker_desired_count" {
  description = "Desired ECS task count for the worker service."
  type        = number
  default     = 1
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
  default     = "appdata"
}

variable "db_username" {
  description = "PostgreSQL master username."
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "PostgreSQL master password."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class. Default is a low-cost burstable option."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GiB for the PostgreSQL instance."
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL engine version to deploy."
  type        = string
  default     = "16.13"
}

variable "cache_node_type" {
  description = "ElastiCache node type. Default is a low-cost burstable option."
  type        = string
  default     = "cache.t4g.micro"
}

variable "common_environment" {
  description = "Non-secret environment variables shared by the ECS services."
  type        = map(string)
  default     = {}
}

variable "web_environment" {
  description = "Additional non-secret environment variables for the web service."
  type        = map(string)
  default     = {}
}

variable "worker_environment" {
  description = "Additional non-secret environment variables for the worker service."
  type        = map(string)
  default     = {}
}

variable "common_secrets" {
  description = "Map of environment variable name to Secrets Manager or SSM parameter ARN shared by all ECS services."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "web_secrets" {
  description = "Map of environment variable name to Secrets Manager or SSM parameter ARN for the web service."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "worker_secrets" {
  description = "Map of environment variable name to Secrets Manager or SSM parameter ARN for the worker service."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "frontend_bucket_index_document" {
  description = "Index document for the S3 website endpoint."
  type        = string
  default     = "index.html"
}

variable "frontend_bucket_error_document" {
  description = "Error document for the S3 website endpoint."
  type        = string
  default     = "index.html"
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
