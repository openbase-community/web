moved {
  from = aws_vpc.main
  to   = module.foundation.aws_vpc.main
}

moved {
  from = aws_internet_gateway.main
  to   = module.foundation.aws_internet_gateway.main
}

moved {
  from = aws_subnet.public
  to   = module.foundation.aws_subnet.public
}

moved {
  from = aws_subnet.private
  to   = module.foundation.aws_subnet.private
}

moved {
  from = aws_route_table.public
  to   = module.foundation.aws_route_table.public
}

moved {
  from = aws_route_table_association.public
  to   = module.foundation.aws_route_table_association.public
}

moved {
  from = aws_route_table.private
  to   = module.foundation.aws_route_table.private
}

moved {
  from = aws_route_table_association.private
  to   = module.foundation.aws_route_table_association.private
}

moved {
  from = aws_security_group.web_instance
  to   = module.foundation.aws_security_group.web_instance
}

moved {
  from = aws_security_group.worker_instance
  to   = module.foundation.aws_security_group.worker_instance
}

moved {
  from = aws_security_group.rds
  to   = module.foundation.aws_security_group.rds
}

moved {
  from = aws_security_group.cache
  to   = module.foundation.aws_security_group.cache
}

moved {
  from = aws_db_subnet_group.main
  to   = module.foundation.aws_db_subnet_group.main
}

moved {
  from = aws_ssm_parameter.db_password
  to   = module.foundation.aws_ssm_parameter.db_password
}

moved {
  from = aws_ssm_parameter.db_url
  to   = module.foundation.aws_ssm_parameter.db_url
}

moved {
  from = aws_db_instance.postgres
  to   = module.foundation.aws_db_instance.postgres
}

moved {
  from = aws_elasticache_subnet_group.main
  to   = module.foundation.aws_elasticache_subnet_group.main
}

moved {
  from = aws_elasticache_cluster.redis
  to   = module.foundation.aws_elasticache_cluster.redis
}

moved {
  from = aws_s3_bucket.app
  to   = module.foundation.aws_s3_bucket.app
}

moved {
  from = aws_s3_bucket_public_access_block.app
  to   = module.foundation.aws_s3_bucket_public_access_block.app
}

moved {
  from = aws_s3_bucket_ownership_controls.app
  to   = module.foundation.aws_s3_bucket_ownership_controls.app
}

moved {
  from = aws_s3_bucket_website_configuration.app
  to   = module.foundation.aws_s3_bucket_website_configuration.app
}

moved {
  from = aws_s3_bucket_cors_configuration.app
  to   = module.foundation.aws_s3_bucket_cors_configuration.app
}

moved {
  from = aws_s3_bucket_policy.app_public_read
  to   = module.foundation.aws_s3_bucket_policy.app_public_read
}
