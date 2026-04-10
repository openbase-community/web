module "foundation" {
  source = "../../infra/terraform/modules/aws-app-foundation"

  aws_region                     = var.aws_region
  name                           = var.name
  environment                    = var.environment
  web_hostname                   = var.web_hostname
  vpc_cidr                       = var.vpc_cidr
  public_subnet_cidrs            = var.public_subnet_cidrs
  private_subnet_cidrs           = var.private_subnet_cidrs
  web_ingress_cidrs              = var.web_ingress_cidrs
  cloudflare_ipv4_cidrs          = var.cloudflare_ipv4_cidrs
  cdn_hostname                   = var.cdn_hostname
  frontend_cors_allowed_origins  = var.frontend_cors_allowed_origins
  db_name                        = var.db_name
  db_username                    = var.db_username
  db_password                    = var.db_password
  db_instance_class              = var.db_instance_class
  db_allocated_storage           = var.db_allocated_storage
  db_engine_version              = var.db_engine_version
  cache_node_type                = var.cache_node_type
  frontend_bucket_index_document = var.frontend_bucket_index_document
  frontend_bucket_error_document = var.frontend_bucket_error_document
  tags                           = var.tags
}
