output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "availability_zones" {
  description = "Availability zones used"
  value       = aws_subnet.public[*].availability_zone
}

output "security_group_id" {
  description = "ID of the Jitsi security group"
  value       = aws_security_group.jitsi.id
}

# ECS Express Mode handles load balancing automatically

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.jitsi.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.jitsi.name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for recordings"
  value       = aws_s3_bucket.jitsi_recordings.bucket
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.jitsi.arn
}

output "domain_name" {
  description = "Domain name for the Jitsi platform"
  value       = var.domain_name
}

output "platform_url" {
  description = "Full HTTPS URL for the Jitsi platform"
  value       = "https://${var.domain_name}"
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "project_name" {
  description = "Project name used for resource naming"
  value       = var.project_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name for ECS logs"
  value       = aws_cloudwatch_log_group.jitsi.name
}

# Production Optimization Outputs
output "ssm_parameter_prefix" {
  description = "SSM Parameter Store prefix for Jitsi authentication secrets"
  value       = "/${var.project_name}/"
  sensitive   = false
}





output "task_cpu" {
  description = "CPU units allocated to the ECS task"
  value       = var.task_cpu
}

output "task_memory" {
  description = "Memory (MB) allocated to the ECS task"
  value       = var.task_memory
}

output "recording_enabled" {
  description = "Whether video recording is enabled"
  value       = var.enable_recording
}

output "max_participants" {
  description = "Maximum number of participants per meeting"
  value       = var.max_participants
}



output "jitsi_metrics_namespace" {
  description = "CloudWatch namespace for Jitsi-specific metrics"
  value       = "Jitsi/JVB"
}

# Operational Information
output "deployment_summary" {
  description = "Summary of the production-optimized Jitsi deployment"
  value = {
    platform_url        = "https://${var.domain_name}"
    recording_enabled   = var.enable_recording
    auto_scaling        = "Manual scaling via scripts"
    monitoring          = "CloudWatch logs and metrics"
    secret_management   = "AWS SSM Parameter Store"
    resource_allocation = "${var.task_cpu} CPU / ${var.task_memory}MB RAM"
    s3_bucket           = aws_s3_bucket.jitsi_recordings.bucket
  }
}

# JVB NLB Outputs (conditional)
output "jvb_nlb_dns_name" {
  description = "DNS name of the JVB Network Load Balancer (when enabled)"
  value       = var.nlb_enabled ? module.jvb_nlb[0].nlb_dns_name : null
}

output "jvb_nlb_target_group_udp_arn" {
  description = "ARN of the JVB UDP target group (when NLB enabled)"
  value       = var.nlb_enabled ? module.jvb_nlb[0].target_group_udp_arn : null
  sensitive   = false
}

output "jvb_nlb_target_group_tcp_arn" {
  description = "ARN of the JVB TCP target group (when NLB enabled)"
  value       = var.nlb_enabled ? module.jvb_nlb[0].target_group_tcp_arn : null
  sensitive   = false
}