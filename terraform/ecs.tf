data "aws_iam_policy_document" "ecs_instance_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_instance" {
  name               = "${local.prefix}-ecs-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_instance_assume_role.json

  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ssm" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_cloudwatch_agent" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy_document" "web_instance_origin_tls" {
  statement {
    actions = ["ssm:GetParameter"]
    resources = [
      local.cloudflare_origin_cert_parameter_arn,
      local.cloudflare_origin_key_parameter_arn,
    ]
  }
}

resource "aws_iam_role_policy" "web_instance_origin_tls" {
  name   = "${local.prefix}-web-origin-tls"
  role   = aws_iam_role.ecs_instance.id
  policy = data.aws_iam_policy_document.web_instance_origin_tls.json
}

resource "aws_iam_instance_profile" "ecs" {
  name = "${local.prefix}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name
}

data "aws_iam_policy_document" "task_execution_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${local.prefix}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.task_execution_assume_role.json

  tags = local.default_tags
}

resource "aws_iam_role" "task" {
  name               = "${local.prefix}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_execution_assume_role.json

  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "task_execution_ssm" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

data "aws_iam_policy_document" "app_bucket_access" {
  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:PutObjectAcl",
    ]

    resources = [
      aws_s3_bucket.app.arn,
      "${aws_s3_bucket.app.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "task_app_bucket" {
  name   = "${local.prefix}-task-app-bucket"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.app_bucket_access.json
}

data "aws_iam_policy_document" "task_execute_command" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task_execute_command" {
  name   = "${local.prefix}-task-execute-command"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_execute_command.json
}

resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/${local.prefix}/web"
  retention_in_days = 14

  tags = local.default_tags
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${local.prefix}/worker"
  retention_in_days = 14

  tags = local.default_tags
}

resource "aws_cloudwatch_log_group" "caddy" {
  name              = "/ecs/${local.prefix}/caddy"
  retention_in_days = 14

  tags = local.default_tags
}

resource "aws_ecs_cluster" "main" {
  name = local.prefix

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.default_tags
}

resource "aws_instance" "web" {
  ami                    = data.aws_ssm_parameter.ecs_ami.value
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.public["0"].id
  vpc_security_group_ids = [aws_security_group.web_instance.id]
  iam_instance_profile   = aws_iam_instance_profile.ecs.name

  user_data = templatefile("${path.module}/templates/web_user_data.sh.tftpl", {
    ecs_cluster_name                      = aws_ecs_cluster.main.name
    caddy_version                         = var.caddy_version
    caddyfile                             = local.caddyfile
    cloudwatch_agent_config               = local.cloudwatch_agent_config
    cloudflare_origin_cert_parameter_name = var.cloudflare_origin_cert_parameter_name
    cloudflare_origin_key_parameter_name  = var.cloudflare_origin_key_parameter_name
  })

  tags = merge(local.default_tags, {
    Name = "${local.prefix}-web"
    Role = "web"
  })
}

resource "aws_eip" "web" {
  domain   = "vpc"
  instance = aws_instance.web.id

  tags = merge(local.default_tags, { Name = "${local.prefix}-web-eip" })
}

resource "aws_instance" "worker" {
  ami                    = data.aws_ssm_parameter.ecs_ami.value
  instance_type          = var.worker_instance_type
  subnet_id              = aws_subnet.public["1"].id
  vpc_security_group_ids = [aws_security_group.worker_instance.id]
  iam_instance_profile   = aws_iam_instance_profile.ecs.name

  user_data = <<-EOT
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
    echo 'ECS_INSTANCE_ATTRIBUTES={"role":"worker"}' >> /etc/ecs/ecs.config
  EOT

  tags = merge(local.default_tags, {
    Name = "${local.prefix}-worker"
    Role = "worker"
  })
}

resource "aws_ecs_task_definition" "web" {
  family                   = "${local.prefix}-web"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "web"
      image     = var.web_image
      essential = true
      cpu       = var.web_task_cpu
      memory    = var.web_task_memory
      command   = [
        "/app/.venv/bin/gunicorn",
        "config.asgi:application",
        "--log-file",
        "-",
        "-k",
        "uvicorn.workers.UvicornWorker",
        "--bind",
        "0.0.0.0:${var.web_container_port}",
      ]
      portMappings = [
        {
          containerPort = var.web_container_port
          hostPort      = var.web_host_port
          protocol      = "tcp"
        }
      ]
      environment = [
        for key, value in local.web_environment : {
          name  = key
          value = value
        }
      ]
      secrets = [
        for key, value in local.web_secrets : {
          name      = key
          valueFrom = value
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.web.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = local.default_tags
}

resource "aws_ecs_task_definition" "worker" {
  family                   = "${local.prefix}-worker"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = var.worker_image
      essential = true
      cpu       = var.worker_task_cpu
      memory    = var.worker_task_memory
      command   = [
        "/app/.venv/bin/taskiq",
        "worker",
        "--log-level=INFO",
        "--max-threadpool-threads=2",
        "config.taskiq_config:broker",
        "config.taskiq_tasks",
      ]
      environment = [
        for key, value in local.worker_environment : {
          name  = key
          value = value
        }
      ]
      secrets = [
        for key, value in local.worker_secrets : {
          name      = key
          valueFrom = value
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.worker.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = local.default_tags
}

resource "aws_ecs_service" "web" {
  name            = "${local.prefix}-web"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = var.web_desired_count
  launch_type     = "EC2"

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:role == web"
  }

  tags = local.default_tags

  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_ecs_service" "worker" {
  name            = "${local.prefix}-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.worker_desired_count
  launch_type     = "EC2"

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:role == worker"
  }

  tags = local.default_tags

  lifecycle {
    ignore_changes = [task_definition]
  }
}
