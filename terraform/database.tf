resource "aws_db_subnet_group" "main" {
  name       = "${local.prefix}-db"
  subnet_ids = [for subnet in aws_subnet.private : subnet.id]

  tags = merge(local.default_tags, { Name = "${local.prefix}-db-subnets" })
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.name}/${var.environment}/database/password"
  type  = "SecureString"
  value = var.db_password

  tags = local.default_tags
}

resource "aws_ssm_parameter" "db_url" {
  name  = "/${var.name}/${var.environment}/database/url"
  type  = "SecureString"
  value = "postgresql://${var.db_username}:${urlencode(var.db_password)}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}"

  tags = local.default_tags
}

resource "aws_db_instance" "postgres" {
  identifier              = "${local.prefix}-postgres"
  engine                  = "postgres"
  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  storage_type            = "gp3"
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  skip_final_snapshot     = true
  deletion_protection     = false
  publicly_accessible     = false
  backup_retention_period = 0
  multi_az                = false

  tags = merge(local.default_tags, { Name = "${local.prefix}-postgres" })
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${local.prefix}-cache"
  subnet_ids = [for subnet in aws_subnet.private : subnet.id]
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${local.prefix}-cache"
  engine               = "redis"
  node_type            = var.cache_node_type
  num_cache_nodes      = 1
  port                 = 6379
  parameter_group_name = "default.redis7"
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.cache.id]

  tags = local.default_tags
}
