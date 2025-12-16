terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-${count.index + 1}"
    Project     = var.project_name
    Environment = var.environment
    Type        = "Public"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Security Group for Jitsi
resource "aws_security_group" "jitsi" {
  name        = "${var.project_name}-jitsi-sg"
  description = "Security group for Jitsi Meet application"
  vpc_id      = aws_vpc.main.id

  # HTTPS traffic
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jitsi Video Bridge (JVB) - UDP
  ingress {
    from_port   = 10000
    to_port     = 10000
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # JVB TCP fallback port
  ingress {
    from_port   = 4443
    to_port     = 4443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP for health checks
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-jitsi-sg"
    Project     = var.project_name
    Environment = var.environment
  }
}

# JVB Network Load Balancer (On-Demand)
module "jvb_nlb" {
  source = "./modules/jvb-nlb"
  count  = var.nlb_enabled ? 1 : 0

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = aws_vpc.main.id
  subnet_ids        = aws_subnet.public[*].id
  security_group_id = aws_security_group.jitsi.id
}

# Service Discovery Namespace for ECS Service Connect
resource "aws_service_discovery_private_dns_namespace" "jitsi" {
  name = "${var.project_name}.local"
  vpc  = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-service-discovery"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ECS Express Mode handles load balancing automatically


# ECS Cluster
resource "aws_ecs_cluster" "jitsi" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-cluster"
    Project     = var.project_name
    Environment = var.environment
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ecs-task-execution-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ecs-task-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Policy for ECS Task Execution (SSM Parameter Store access)
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "${var.project_name}-ecs-task-execution-secrets-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/*"
      }
    ]
  })
}

# IAM Policy for ECS Task (S3 access for video storage and SSM Parameter Store)
resource "aws_iam_role_policy" "ecs_task_s3" {
  name = "${var.project_name}-ecs-task-s3-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.jitsi_recordings.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.jitsi_recordings.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/*"
      }
    ]
  })
}

# S3 Bucket for video recordings
resource "aws_s3_bucket" "jitsi_recordings" {
  bucket = "${var.project_name}-recordings-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.project_name}-recordings"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Random ID for S3 bucket suffix
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Random passwords for Jitsi components
resource "random_password" "jicofo_component_secret" {
  length  = 32
  special = true
}

resource "random_password" "jicofo_auth_password" {
  length  = 32
  special = true
}

resource "random_password" "jvb_component_secret" {
  length  = 32
  special = true
}

resource "random_password" "jvb_auth_password" {
  length  = 32
  special = true
}

resource "random_password" "jigasi_auth_password" {
  length  = 32
  special = true
}

# SSM Parameter Store for Jitsi authentication secrets
resource "aws_ssm_parameter" "jicofo_component_secret" {
  name  = "/${var.project_name}/jicofo_component_secret"
  type  = "SecureString"
  value = random_password.jicofo_component_secret.result

  tags = {
    Name        = "${var.project_name}-jicofo-component-secret"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "jicofo_auth_password" {
  name  = "/${var.project_name}/jicofo_auth_password"
  type  = "SecureString"
  value = random_password.jicofo_auth_password.result

  tags = {
    Name        = "${var.project_name}-jicofo-auth-password"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "jvb_component_secret" {
  name  = "/${var.project_name}/jvb_component_secret"
  type  = "SecureString"
  value = random_password.jvb_component_secret.result

  tags = {
    Name        = "${var.project_name}-jvb-component-secret"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "jvb_auth_password" {
  name  = "/${var.project_name}/jvb_auth_password"
  type  = "SecureString"
  value = random_password.jvb_auth_password.result

  tags = {
    Name        = "${var.project_name}-jvb-auth-password"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "jigasi_auth_password" {
  name  = "/${var.project_name}/jigasi_auth_password"
  type  = "SecureString"
  value = random_password.jigasi_auth_password.result

  tags = {
    Name        = "${var.project_name}-jigasi-auth-password"
    Project     = var.project_name
    Environment = var.environment
  }
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "jitsi_recordings" {
  bucket = aws_s3_bucket.jitsi_recordings.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "jitsi_recordings" {
  bucket = aws_s3_bucket.jitsi_recordings.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "jitsi_recordings" {
  bucket = aws_s3_bucket.jitsi_recordings.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ECS Task Definition
resource "aws_ecs_task_definition" "jitsi" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "jitsi-web"
      image     = "jitsi/web:stable"
      essential = true
      portMappings = [
        {
          name          = "web"
          containerPort = 80
          protocol      = "tcp"
        },
        {
          containerPort = 443
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "ENABLE_LETSENCRYPT"
          value = "0"
        },
        {
          name  = "DISABLE_HTTPS"
          value = "1"
        },
        {
          name  = "XMPP_DOMAIN"
          value = "meet.jitsi"
        },
        {
          name  = "XMPP_AUTH_DOMAIN"
          value = "auth.meet.jitsi"
        },
        {
          name  = "XMPP_BOSH_URL_BASE"
          value = "http://localhost:5280"
        },
        {
          name  = "XMPP_MUC_DOMAIN"
          value = "muc.meet.jitsi"
        },
        {
          name  = "XMPP_INTERNAL_MUC_DOMAIN"
          value = "internal-muc.meet.jitsi"
        },
        {
          name  = "XMPP_RECORDER_DOMAIN"
          value = "recorder.meet.jitsi"
        },
        {
          name  = "TZ"
          value = "UTC"
        },
        {
          name  = "PUBLIC_URL"
          value = "https://${var.domain_name}"
        },
        {
          name  = "ENABLE_RECORDING"
          value = "0"
        },
        {
          name  = "ENABLE_COLIBRI_WEBSOCKET"
          value = "1"
        }
      ]
      secrets = [
        {
          name      = "JICOFO_COMPONENT_SECRET"
          valueFrom = aws_ssm_parameter.jicofo_component_secret.arn
        },
        {
          name      = "JICOFO_AUTH_PASSWORD"
          valueFrom = aws_ssm_parameter.jicofo_auth_password.arn
        },
        {
          name      = "JVB_COMPONENT_SECRET"
          valueFrom = aws_ssm_parameter.jvb_component_secret.arn
        },
        {
          name      = "JVB_AUTH_PASSWORD"
          valueFrom = aws_ssm_parameter.jvb_auth_password.arn
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:80/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.jitsi.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "jitsi-web"
        }
      }
    },
    {
      name      = "prosody"
      image     = "jitsi/prosody:stable"
      essential = true
      environment = [
        {
          name  = "AUTH_TYPE"
          value = "internal"
        },
        {
          name  = "ENABLE_GUESTS"
          value = "1"
        },
        {
          name  = "XMPP_DOMAIN"
          value = "meet.jitsi"
        },
        {
          name  = "XMPP_AUTH_DOMAIN"
          value = "auth.meet.jitsi"
        },
        {
          name  = "XMPP_MUC_DOMAIN"
          value = "muc.meet.jitsi"
        },
        {
          name  = "XMPP_INTERNAL_MUC_DOMAIN"
          value = "internal-muc.meet.jitsi"
        },
        {
          name  = "XMPP_RECORDER_DOMAIN"
          value = "recorder.meet.jitsi"
        },
        {
          name  = "JICOFO_AUTH_USER"
          value = "focus"
        },
        {
          name  = "JVB_AUTH_USER"
          value = "jvb"
        },
        {
          name  = "JIGASI_XMPP_USER"
          value = "jigasi"
        },
        {
          name  = "JIBRI_RECORDER_USER"
          value = "recorder"
        },
        {
          name  = "JIBRI_XMPP_USER"
          value = "jibri"
        },
        {
          name  = "TZ"
          value = "UTC"
        },
        {
          name  = "LOG_LEVEL"
          value = "info"
        }
      ]
      secrets = [
        {
          name      = "JICOFO_COMPONENT_SECRET"
          valueFrom = aws_ssm_parameter.jicofo_component_secret.arn
        },
        {
          name      = "JICOFO_AUTH_PASSWORD"
          valueFrom = aws_ssm_parameter.jicofo_auth_password.arn
        },
        {
          name      = "JVB_AUTH_PASSWORD"
          valueFrom = aws_ssm_parameter.jvb_auth_password.arn
        },
        {
          name      = "JVB_COMPONENT_SECRET"
          valueFrom = aws_ssm_parameter.jvb_component_secret.arn
        },
        {
          name      = "JIGASI_XMPP_PASSWORD"
          valueFrom = aws_ssm_parameter.jigasi_auth_password.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.jitsi.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "prosody"
        }
      }
    },
    {
      name      = "jicofo"
      image     = "jitsi/jicofo:stable"
      essential = true
      environment = [
        {
          name  = "XMPP_DOMAIN"
          value = "meet.jitsi"
        },
        {
          name  = "XMPP_AUTH_DOMAIN"
          value = "auth.meet.jitsi"
        },
        {
          name  = "XMPP_INTERNAL_MUC_DOMAIN"
          value = "internal-muc.meet.jitsi"
        },
        {
          name  = "XMPP_MUC_DOMAIN"
          value = "muc.meet.jitsi"
        },
        {
          name  = "XMPP_SERVER"
          value = "localhost"
        },
        {
          name  = "JICOFO_AUTH_USER"
          value = "focus"
        },
        {
          name  = "TZ"
          value = "UTC"
        },
        {
          name  = "JICOFO_ENABLE_BRIDGE_HEALTH_CHECKS"
          value = "true"
        },
        {
          name  = "JICOFO_CONF_INITIAL_PARTICIPANT_WAIT_TIMEOUT"
          value = "15000"
        },
        {
          name  = "JICOFO_CONF_SINGLE_PARTICIPANT_TIMEOUT"
          value = "20000"
        }
      ]
      secrets = [
        {
          name      = "JICOFO_COMPONENT_SECRET"
          valueFrom = aws_ssm_parameter.jicofo_component_secret.arn
        },
        {
          name      = "JICOFO_AUTH_PASSWORD"
          valueFrom = aws_ssm_parameter.jicofo_auth_password.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.jitsi.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "jicofo"
        }
      }
    },
    {
      name      = "jvb"
      image     = "jitsi/jvb:stable"
      essential = true
      portMappings = [
        {
          name          = "jvb-udp"
          containerPort = 10000
          protocol      = "udp"
        },
        {
          name          = "jvb-tcp"
          containerPort = 4443
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "XMPP_AUTH_DOMAIN"
          value = "auth.meet.jitsi"
        },
        {
          name  = "XMPP_INTERNAL_MUC_DOMAIN"
          value = "internal-muc.meet.jitsi"
        },
        {
          name  = "XMPP_SERVER"
          value = "localhost"
        },
        {
          name  = "JVB_AUTH_USER"
          value = "jvb"
        },
        {
          name  = "JVB_PORT"
          value = "10000"
        },
        {
          name  = "JVB_TCP_PORT"
          value = "4443"
        },
        {
          name  = "JVB_TCP_HARVESTER_DISABLED"
          value = "false"
        },
        {
          name  = "DOCKER_HOST_ADDRESS"
          value = "AUTO"
        },
        {
          name  = "JVB_ADVERTISE_IPS"
          value = "AUTO"
        },
        {
          name  = "JVB_ADVERTISE_PRIVATE_CANDIDATES"
          value = "false"
        },
        {
          name  = "JVB_ENABLE_APIS"
          value = "rest,colibri"
        },
        {
          name  = "JVB_STUN_SERVERS"
          value = "stun.l.google.com:19302,stun1.l.google.com:19302"
        },
        {
          name  = "TZ"
          value = "UTC"
        },
        {
          name  = "JVB_TCP_HARVESTER_DISABLED"
          value = "false"
        },
        {
          name  = "JVB_TCP_PORT"
          value = "4443"
        },
        {
          name  = "JVB_TCP_MAPPED_PORT"
          value = "4443"
        },
        {
          name  = "JVB_WS_DOMAIN"
          value = var.domain_name
        },
        {
          name  = "JVB_WS_SERVER_ID"
          value = "jvb1"
        },
        {
          name  = "COLIBRI_REST_ENABLED"
          value = "true"
        },
        {
          name  = "SHUTDOWN_REST_ENABLED"
          value = "true"
        },
        {
          name  = "JVB_WS_ENABLED"
          value = "true"
        },
        {
          name  = "JVB_WS_TLS"
          value = "true"
        }
      ]
      secrets = [
        {
          name      = "JVB_AUTH_PASSWORD"
          valueFrom = aws_ssm_parameter.jvb_auth_password.arn
        },
        {
          name      = "JVB_COMPONENT_SECRET"
          valueFrom = aws_ssm_parameter.jvb_component_secret.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.jitsi.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "jvb"
        }
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-task"
    Project     = var.project_name
    Environment = var.environment
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "jitsi" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-logs"
    Project     = var.project_name
    Environment = var.environment
  }
}

# CloudWatch Metric Filters for Jitsi-specific metrics
resource "aws_cloudwatch_log_metric_filter" "jvb_participants" {
  name           = "${var.project_name}-jvb-participants"
  log_group_name = aws_cloudwatch_log_group.jitsi.name
  pattern        = "[timestamp, level, thread, logger, message=\"Participant count:\", count]"

  metric_transformation {
    name      = "JVBParticipantCount"
    namespace = "Jitsi/JVB"
    value     = "$count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "jvb_conferences" {
  name           = "${var.project_name}-jvb-conferences"
  log_group_name = aws_cloudwatch_log_group.jitsi.name
  pattern        = "[timestamp, level, thread, logger, message=\"Conference count:\", count]"

  metric_transformation {
    name      = "JVBConferenceCount"
    namespace = "Jitsi/JVB"
    value     = "$count"
  }
}





# ECS Service with scale-to-zero capability
resource "aws_ecs_service" "jitsi" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.jitsi.id
  task_definition = aws_ecs_task_definition.jitsi.arn
  desired_count   = 0 # Scale-to-zero requirement
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.jitsi.id]
    assign_public_ip = true
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.jitsi.arn

    service {
      client_alias {
        port     = 80
        dns_name = "jitsi-web"
      }
      port_name      = "web"
      discovery_name = "jitsi-web"
    }

    log_configuration {
      log_driver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.jitsi.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "service-connect"
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-service"
    Project     = var.project_name
    Environment = var.environment
  }
}