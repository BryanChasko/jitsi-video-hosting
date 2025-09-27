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
  profile = "jitsi-dev"
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
  name = "${var.project_name}-jitsi-sg"
  description      = "Security group for Jitsi Meet application"
  vpc_id          = aws_vpc.main.id

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

# Network Load Balancer
resource "aws_lb" "jitsi" {
  name               = "${var.project_name}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name        = "${var.project_name}-nlb"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Target Group for HTTPS
resource "aws_lb_target_group" "jitsi_https" {
  name     = "${var.project_name}-https-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    protocol            = "HTTP"
    path                = "/"
    port                = "80"
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name        = "${var.project_name}-https-tg"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Target Group for JVB UDP
resource "aws_lb_target_group" "jitsi_jvb" {
  name     = "${var.project_name}-jvb-tg"
  port     = 10000
  protocol = "UDP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    protocol            = "TCP"
    port                = "443"
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.project_name}-jvb-tg"
    Project     = var.project_name
    Environment = var.environment
  }
}

# NLB Listener for JVB UDP
resource "aws_lb_listener" "jitsi_jvb" {
  load_balancer_arn = aws_lb.jitsi.arn
  port              = "10000"
  protocol          = "UDP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jitsi_jvb.arn
  }
}

# HTTPS Listener for NLB (TLS with certificate)
resource "aws_lb_listener" "jitsi_https_tls" {
  load_balancer_arn = aws_lb.jitsi.arn
  port              = "443"
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = "arn:aws:acm:us-west-2:668383289911:certificate/ca18accd-3d2a-4ca5-9510-c2dec36fa355"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jitsi_https.arn
  }
}


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

# IAM Policy for ECS Task (S3 access for video storage)
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
  cpu                      = "2048"
  memory                   = "4096"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "jitsi-web"
      image = "jitsi/web:stable"
      essential = true
      portMappings = [
        {
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
          name  = "JICOFO_COMPONENT_SECRET"
          value = "jicofo-secret"
        },
        {
          name  = "JICOFO_AUTH_USER"
          value = "focus"
        },
        {
          name  = "JICOFO_AUTH_PASSWORD"
          value = "jicofo-password"
        },
        {
          name  = "JVB_COMPONENT_SECRET"
          value = "jvb-secret"
        },
        {
          name  = "JVB_AUTH_USER"
          value = "jvb"
        },
        {
          name  = "JVB_AUTH_PASSWORD"
          value = "jvb-password"
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
          value = "http://prosody:5280"
        },
        {
          name  = "XMPP_MUC_DOMAIN"
          value = "muc.meet.jitsi"
        },
        {
          name  = "TZ"
          value = "UTC"
        },
        {
          name  = "PUBLIC_URL"
          value = "https://${var.domain_name}"
        }
      ]
      healthCheck = {
        command = ["CMD-SHELL", "curl -f http://localhost:80/ || exit 1"]
        interval = 30
        timeout = 5
        retries = 3
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
      name  = "prosody"
      image = "jitsi/prosody:stable"
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
          name  = "JICOFO_COMPONENT_SECRET"
          value = "jicofo-secret"
        },
        {
          name  = "JICOFO_AUTH_USER"
          value = "focus"
        },
        {
          name  = "JICOFO_AUTH_PASSWORD"
          value = "jicofo-password"
        },
        {
          name  = "JVB_AUTH_USER"
          value = "jvb"
        },
        {
          name  = "JVB_AUTH_PASSWORD"
          value = "jvb-password"
        },
        {
          name  = "JVB_COMPONENT_SECRET"
          value = "jvb-secret"
        },
        {
          name  = "JIGASI_XMPP_USER"
          value = "jigasi"
        },
        {
          name  = "JIGASI_XMPP_PASSWORD"
          value = "jigasi-password"
        },
        {
          name  = "TZ"
          value = "UTC"
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
      name  = "jicofo"
      image = "jitsi/jicofo:stable"
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
          value = "prosody"
        },
        {
          name  = "JICOFO_COMPONENT_SECRET"
          value = "jicofo-secret"
        },
        {
          name  = "JICOFO_AUTH_USER"
          value = "focus"
        },
        {
          name  = "JICOFO_AUTH_PASSWORD"
          value = "jicofo-password"
        },
        {
          name  = "TZ"
          value = "UTC"
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
      name  = "jvb"
      image = "jitsi/jvb:stable"
      essential = true
      portMappings = [
        {
          containerPort = 10000
          protocol      = "udp"
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
          value = "prosody"
        },
        {
          name  = "JVB_AUTH_USER"
          value = "jvb"
        },
        {
          name  = "JVB_AUTH_PASSWORD"
          value = "jvb-password"
        },
        {
          name  = "JVB_COMPONENT_SECRET"
          value = "jvb-secret"
        },
        {
          name  = "JVB_PORT"
          value = "10000"
        },
        {
          name  = "JVB_ADVERTISE_IPS"
          value = "AUTO"
        },
        {
          name  = "TZ"
          value = "UTC"
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
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-logs"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ECS Service with scale-to-zero capability
resource "aws_ecs_service" "jitsi" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.jitsi.id
  task_definition = aws_ecs_task_definition.jitsi.arn
  desired_count   = 0  # Scale-to-zero requirement
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.jitsi.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.jitsi_https.arn
    container_name   = "jitsi-web"
    container_port   = 80
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.jitsi_jvb.arn
    container_name   = "jvb"
    container_port   = 10000
  }

  tags = {
    Name        = "${var.project_name}-service"
    Project     = var.project_name
    Environment = var.environment
  }
}