data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

locals {
  prefix = "${var.name}-${var.environment}"

  default_tags = merge(
    {
      Project     = var.name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  asset_public_domain = trimspace(var.cdn_hostname) != "" ? lower(var.cdn_hostname) : module.foundation.bucket_regional_domain_name
  ecs_app_image       = trimspace(var.app_image) != "" ? trimspace(var.app_image) : trimspace(var.web_image) != "" ? trimspace(var.web_image) : trimspace(var.worker_image)
  cloudflare_zone_name = trimspace(var.cloudflare_zone_name) != "" ? trimspace(var.cloudflare_zone_name) : join(
    ".",
    slice(
      split(".", var.web_hostname),
      max(length(split(".", var.web_hostname)) - 2, 0),
      length(split(".", var.web_hostname)),
    ),
  )

  cloudflare_origin_cert_parameter_arn = "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${trimprefix(var.cloudflare_origin_cert_parameter_name, "/")}"
  cloudflare_origin_key_parameter_arn  = "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${trimprefix(var.cloudflare_origin_key_parameter_name, "/")}"

  caddyfile = templatefile("${path.module}/templates/Caddyfile.tftpl", {
    web_hostname          = var.web_hostname
    web_host_port         = var.web_host_port
    caddy_access_log_path = var.caddy_access_log_path
  })

  cloudwatch_agent_config = templatefile("${path.module}/templates/amazon-cloudwatch-agent.json.tftpl", {
    aws_region            = var.aws_region
    caddy_log_group_name  = "/ecs/${local.prefix}/caddy"
    caddy_access_log_path = var.caddy_access_log_path
  })

  web_environment = {
    PORT                     = tostring(var.web_container_port)
    DJANGO_STATIC_BUCKET     = module.foundation.bucket_name
    DJANGO_STATIC_LOCATION   = "static"
    DJANGO_MEDIA_BUCKET      = module.foundation.bucket_name
    DJANGO_MEDIA_LOCATION    = "media"
    DJANGO_FRONTEND_BUCKET   = module.foundation.bucket_name
    DJANGO_FRONTEND_LOCATION = ""
    DATABASE_HOST            = module.foundation.database_endpoint
    DATABASE_PORT            = tostring(module.foundation.database_port)
    DATABASE_NAME            = module.foundation.database_name
    DATABASE_USER            = module.foundation.database_username
    REDIS_HOST               = module.foundation.redis_endpoint
    REDIS_PORT               = tostring(module.foundation.redis_port)
    REDIS_URL                = "redis://${module.foundation.redis_endpoint}:${module.foundation.redis_port}/0"
    AWS_STORAGE_BUCKET_NAME  = module.foundation.bucket_name
    AWS_S3_CUSTOM_DOMAIN     = local.asset_public_domain
    ALLOWED_HOSTS            = var.web_hostname
  }

  worker_environment = {
    DATABASE_HOST           = module.foundation.database_endpoint
    DATABASE_PORT           = tostring(module.foundation.database_port)
    DATABASE_NAME           = module.foundation.database_name
    DATABASE_USER           = module.foundation.database_username
    REDIS_HOST              = module.foundation.redis_endpoint
    REDIS_PORT              = tostring(module.foundation.redis_port)
    REDIS_URL               = "redis://${module.foundation.redis_endpoint}:${module.foundation.redis_port}/0"
    AWS_STORAGE_BUCKET_NAME = module.foundation.bucket_name
    AWS_S3_CUSTOM_DOMAIN    = local.asset_public_domain
  }

  ecs_secrets = merge(
    var.common_secrets,
    {
      DATABASE_URL      = module.foundation.db_url_parameter_arn
      DATABASE_PASSWORD = module.foundation.db_password_parameter_arn
    },
  )
}
