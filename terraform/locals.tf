data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  prefix = "${var.name}-${var.environment}"

  default_tags = merge(
    {
      Project     = var.name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  bucket_name          = trimspace(var.cdn_hostname) != "" ? lower(var.cdn_hostname) : lower("${local.prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}")
  asset_public_domain  = trimspace(var.cdn_hostname) != "" ? lower(var.cdn_hostname) : aws_s3_bucket.app.bucket_regional_domain_name

  cloudflare_origin_cert_parameter_arn = "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${trimprefix(var.cloudflare_origin_cert_parameter_name, "/")}"
  cloudflare_origin_key_parameter_arn  = "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${trimprefix(var.cloudflare_origin_key_parameter_name, "/")}"

  caddyfile = templatefile("${path.module}/templates/Caddyfile.tftpl", {
    web_hostname  = var.web_hostname
    web_host_port = var.web_host_port
    caddy_access_log_path = var.caddy_access_log_path
  })

  cloudwatch_agent_config = templatefile("${path.module}/templates/amazon-cloudwatch-agent.json.tftpl", {
    aws_region            = var.aws_region
    caddy_log_group_name  = "/ecs/${local.prefix}/caddy"
    caddy_access_log_path = var.caddy_access_log_path
  })

  configured_web_allowed_hosts = distinct(compact(concat(
    [var.web_hostname],
    split(",", lookup(var.common_environment, "ALLOWED_HOSTS", "")),
    split(",", lookup(var.web_environment, "ALLOWED_HOSTS", "")),
  )))

  web_environment = merge(
    var.common_environment,
    var.web_environment,
    {
      PORT                     = tostring(var.web_container_port)
      DJANGO_STATIC_BUCKET     = local.bucket_name
      DJANGO_STATIC_LOCATION   = "static"
      DJANGO_MEDIA_BUCKET      = local.bucket_name
      DJANGO_MEDIA_LOCATION    = "media"
      DJANGO_FRONTEND_BUCKET   = local.bucket_name
      DJANGO_FRONTEND_LOCATION = ""
      DATABASE_HOST            = aws_db_instance.postgres.address
      DATABASE_PORT            = tostring(aws_db_instance.postgres.port)
      DATABASE_NAME            = aws_db_instance.postgres.db_name
      DATABASE_USER            = aws_db_instance.postgres.username
      REDIS_HOST               = aws_elasticache_cluster.redis.cache_nodes[0].address
      REDIS_PORT               = tostring(aws_elasticache_cluster.redis.port)
      REDIS_URL                = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:${aws_elasticache_cluster.redis.port}/0"
      AWS_STORAGE_BUCKET_NAME  = local.bucket_name
      AWS_S3_CUSTOM_DOMAIN     = local.asset_public_domain
      ALLOWED_HOSTS            = join(",", local.configured_web_allowed_hosts)
    },
  )

  worker_environment = merge(
    var.common_environment,
    var.worker_environment,
    {
      DATABASE_HOST           = aws_db_instance.postgres.address
      DATABASE_PORT           = tostring(aws_db_instance.postgres.port)
      DATABASE_NAME           = aws_db_instance.postgres.db_name
      DATABASE_USER           = aws_db_instance.postgres.username
      REDIS_HOST              = aws_elasticache_cluster.redis.cache_nodes[0].address
      REDIS_PORT              = tostring(aws_elasticache_cluster.redis.port)
      REDIS_URL               = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:${aws_elasticache_cluster.redis.port}/0"
      AWS_STORAGE_BUCKET_NAME = local.bucket_name
      AWS_S3_CUSTOM_DOMAIN    = local.asset_public_domain
    },
  )

  web_secrets = merge(
    var.common_secrets,
    var.web_secrets,
    {
      DATABASE_URL      = aws_ssm_parameter.db_url.arn
      DATABASE_PASSWORD = aws_ssm_parameter.db_password.arn
    },
  )

  worker_secrets = merge(
    var.common_secrets,
    var.worker_secrets,
    {
      DATABASE_URL      = aws_ssm_parameter.db_url.arn
      DATABASE_PASSWORD = aws_ssm_parameter.db_password.arn
    },
  )
}
