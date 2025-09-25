provider "aws" {
  region = "us-east-1" # Replace with your desired AWS region
}

# Data source to get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Data source to get public subnets of the default VPC
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

# Data source to get the internet gateway of the default VPC (optional, usually attached)
data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Data source to get the default route table of the default VPC
data "aws_route_table" "default" {
  vpc_id = data.aws_vpc.default.id

  filter {
    name   = "association.main"
    values = ["true"]
  }
}

# Removed aws_vpc.main
# Removed aws_subnet.public
# Removed aws_internet_gateway.main
# Removed aws_route_table.public
# Removed aws_route_table_association.public

resource "aws_security_group" "ecs_service" {
  vpc_id = data.aws_vpc.default.id
  name   = "koronet-ecs-service-sg"
  description = "Allow HTTP and SSH access to ECS service"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    self        = true
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    self        = true
  }

  ingress {
    from_port   = 9100 # Node Exporter (web server sidecar)
    to_port     = 9100
    protocol    = "tcp"
    self        = true
  }

  ingress {
    from_port   = 9187 # PostgreSQL Exporter sidecar
    to_port     = 9187
    protocol    = "tcp"
    self        = true
  }

  ingress {
    from_port   = 9121 # Redis Exporter sidecar
    to_port     = 9121
    protocol    = "tcp"
    self        = true
  }

  ingress {
    from_port   = 9090 # Prometheus Server port
    to_port     = 9090
    protocol    = "tcp"
    self        = true
  }

  ingress {
    from_port   = 3000 # Grafana Web UI port
    to_port     = 3000
    protocol    = "tcp"
    self        = true
  }

  ingress {
    from_port   = 9090 # Allow Grafana to access Prometheus
    to_port     = 9090
    protocol    = "tcp"
    security_groups = [aws_security_group.grafana.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "koronet-ecs-service-sg"
  }
}

resource "aws_ecs_cluster" "main" {
  name = "koronet-ecs-cluster"

  tags = {
    Name = "koronet-ecs-cluster"
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "koronet-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs_execute_command_policy" {
  name        = "koronet-ecs-execute-command-policy"
  description = "IAM policy for ECS Execute Command permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ecs:ExecuteCommand"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/ecs/koronet-*:log-stream:ecs/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetEncryptionConfiguration"
        ]
        Resource = "arn:aws:s3:::ecs-exec-command-logs-*" # You might want to refine this to a specific bucket
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execute_command_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_execute_command_policy.arn
}

resource "aws_ecs_task_definition" "web_server" {
  family                   = "koronet-web-server-task"
  cpu                      = "512" # Increased CPU
  memory                   = "1024" # Increased memory to 1GB (1024MB)
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name        = "web-server"
      image       = "${var.docker_username}/koronet-web-server:latest"
      cpu         = 256
      memory      = 512
      essential   = true
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
        }
      ]
      environment = [
        { name = "DB_HOST", value = "koronet-postgresql-service.koronet.local" },
        { name = "DB_NAME", value = "${var.db_name}" },
        { name = "DB_USER", value = "${var.db_user}" },
        { name = "DB_PASSWORD", value = "${var.db_password}" },
        { name = "REDIS_HOST", value = "koronet-redis-service.koronet.local" },
        { name = "REDIS_PORT", value = tostring(var.redis_port) }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/koronet-web-server"
          awslogs-region        = "us-east-1" # Replace with your desired AWS region
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name        = "prometheus-exporter-sidecar"
      image       = "prom/node-exporter:latest" # Example: a generic exporter, replace with specific app exporter if available
      cpu         = 64
      memory      = 128
      essential   = false
      portMappings = [
        {
          containerPort = 9100 # Default port for node-exporter, adjust if using a different exporter
          hostPort      = 9100
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/koronet-prometheus-exporter"
          awslogs-region        = "us-east-1" # Replace with your desired AWS region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "web_server" {
  name            = "koronet-web-server-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web_server.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.web_server.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
    aws_cloudwatch_log_group.web_server,
    aws_ecs_service.postgresql,
    aws_ecs_service.redis,
  ]

  tags = {
    Name = "koronet-web-server-service"
  }
}

resource "aws_service_discovery_service" "web_server" {
  name        = "koronet-web-server-service"
  namespace_id = aws_service_discovery_private_dns_namespace.main.id

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "postgresql" {
  family                   = "koronet-postgresql-task"
  cpu                      = "512"
  memory                   = "1024"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name        = "postgresql"
      image       = "postgres:13"
      cpu         = 256
      memory      = 512
      essential   = true
      portMappings = [
        {
          containerPort = 5432
          hostPort      = 5432
        }
      ]
      environment = [
        { name = "POSTGRES_DB", value = "${var.db_name}" },
        { name = "POSTGRES_USER", value = "${var.db_user}" },
        { name = "POSTGRES_PASSWORD", value = "${var.db_password}" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/koronet-postgresql"
          awslogs-region        = "us-east-1" # Replace with your desired AWS region
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name        = "postgres-exporter-sidecar"
      image       = "wrouesnel/postgres_exporter:latest"
      cpu         = 64
      memory      = 128
      essential   = false
      portMappings = [
        {
          containerPort = 9187 # Default port for postgres_exporter
          hostPort      = 9187
        }
      ]
      environment = [
        { name = "DATA_SOURCE_NAME", value = "postgresql://${var.db_user}:${var.db_password}@localhost:5432/${var.db_name}?sslmode=disable" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/koronet-prometheus-exporter"
          awslogs-region        = "us-east-1" # Replace with your desired AWS region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "postgresql" {
  name            = "koronet-postgresql-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.postgresql.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.postgresql.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
    aws_cloudwatch_log_group.postgresql,
  ]

  tags = {
    Name = "koronet-postgresql-service"
  }
}

resource "aws_service_discovery_service" "postgresql" {
  name        = "koronet-postgresql-service"
  namespace_id = aws_service_discovery_private_dns_namespace.main.id

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "redis" {
  family                   = "koronet-redis-task"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name        = "redis"
      image       = "redis:6-alpine"
      cpu         = 128
      memory      = 256
      essential   = true
      portMappings = [
        {
          containerPort = 6379
          hostPort      = 6379
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/koronet-redis"
          awslogs-region        = "us-east-1" # Replace with your desired AWS region
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name        = "redis-exporter-sidecar"
      image       = "oliver006/redis_exporter:latest"
      cpu         = 64
      memory      = 128
      essential   = false
      portMappings = [
        {
          containerPort = 9121 # Default port for redis_exporter
          hostPort      = 9121
        }
      ]
      command = ["--redis.addr=redis://localhost:6379"]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/koronet-prometheus-exporter"
          awslogs-region        = "us-east-1" # Replace with your desired AWS region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "redis" {
  name            = "koronet-redis-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.redis.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.redis.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
    aws_cloudwatch_log_group.redis,
  ]

  tags = {
    Name = "koronet-redis-service"
  }
}

resource "aws_service_discovery_service" "redis" {
  name        = "koronet-redis-service"
  namespace_id = aws_service_discovery_private_dns_namespace.main.id

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "koronet-prometheus-task"
  cpu                      = "1024"
  memory                   = "2048"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name        = "prometheus"
      image       = "${var.docker_username}/koronet-prometheus:latest"
      cpu         = 1024
      memory      = 2048
      essential   = true
      portMappings = [
        {
          containerPort = 9090
          hostPort      = 9090
        }
      ]
      command = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus",
        "--web.enable-remote-write-receiver",
        "--web.enable-lifecycle",
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/koronet-prometheus"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "prometheus_new" {
  family                   = "koronet-prometheus-task-new"
  cpu                      = "1024"
  memory                   = "2048"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn # Added task_role_arn

  container_definitions = jsonencode([
    {
      name        = "prometheus"
      image       = "${var.docker_username}/koronet-prometheus:latest"
      cpu         = 1024
      memory      = 2048
      essential   = true
      portMappings = [
        {
          containerPort = 9090
          hostPort      = 9090
        }
      ]
      command = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus",
        "--web.enable-remote-write-receiver",
        "--web.enable-lifecycle",
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/koronet-prometheus"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
          "awslogs-multiline-pattern" = "^\\S"
        }
      }
    }
  ])
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_cloudwatch_log_group" "web_server" {
  name              = "/ecs/koronet-web-server"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "postgresql" {
  name              = "/ecs/koronet-postgresql"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "prometheus_exporter" {
  name              = "/ecs/koronet-prometheus-exporter"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "redis" {
  name              = "/ecs/koronet-redis"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/ecs/koronet-prometheus"
  retention_in_days = 7
}

resource "aws_ecs_service" "prometheus" {
  name            = "koronet-prometheus-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.prometheus_new.arn # Use the new task definition
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"
  enable_execute_command  = true

  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.prometheus.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
    aws_cloudwatch_log_group.prometheus,
  ]

  tags = {
    Name = "koronet-prometheus-service"
  }
}

resource "aws_service_discovery_service" "prometheus" {
  name        = "koronet-prometheus-service"
  namespace_id = aws_service_discovery_private_dns_namespace.main.id

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "grafana" {
  family                   = "koronet-grafana-task"
  cpu                      = "512"
  memory                   = "1024"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn # Added task_role_arn

  container_definitions = jsonencode([
    {
      name        = "grafana"
      image       = "grafana/grafana:latest"
      cpu         = 512
      memory      = 1024
      essential   = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
      environment = [
        { name = "GF_SECURITY_ADMIN_USER", value = "${var.grafana_admin_user}" },
        { name = "GF_SECURITY_ADMIN_PASSWORD", value = "${var.grafana_admin_password}" },
        { name = "GF_SERVER_DOMAIN", value = "grafana.koronet.local" },
        { name = "GF_SERVER_ROOT_URL", value = "http://grafana.koronet-grafana-service.koronet.local:3000" },
        { name = "GF_PATHS_DATA", value = "/var/lib/grafana" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/koronet-grafana"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/koronet-grafana"
  retention_in_days = 7
}

resource "aws_ecs_service" "grafana" {
  name            = "koronet-grafana-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"
  enable_execute_command  = true

  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.grafana.id] # Use the new Grafana-specific security group
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.grafana.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
    aws_cloudwatch_log_group.grafana,
  ]

  tags = {
    Name = "koronet-grafana-service"
  }
}

resource "aws_service_discovery_service" "grafana" {
  name        = "koronet-grafana-service"
  namespace_id = aws_service_discovery_private_dns_namespace.main.id

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_security_group" "grafana" {
  vpc_id = data.aws_vpc.default.id
  name   = "koronet-grafana-sg"
  description = "Allow web access to Grafana"

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "koronet-grafana-sg"
  }
}

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "koronet.local"
  description = "Private DNS Namespace for Koronet services"
  vpc         = data.aws_vpc.default.id
}
