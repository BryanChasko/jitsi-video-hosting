variable "aws_profile" {
  description = "AWS CLI profile name (set via TF_VAR_aws_profile or JITSI_AWS_PROFILE env var)"
  type        = string
  default     = null

  validation {
    condition     = var.aws_profile != null && var.aws_profile != ""
    error_message = "aws_profile must be provided. Set TF_VAR_aws_profile env var or JITSI_AWS_PROFILE."
  }
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "jitsi-video-platform"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "domain_name" {
  description = "Domain name for the Jitsi platform (set via TF_VAR_domain_name or JITSI_DOMAIN env var)"
  type        = string
  default     = null

  validation {
    condition     = var.domain_name != null && var.domain_name != ""
    error_message = "domain_name must be provided. Set TF_VAR_domain_name env var or JITSI_DOMAIN."
  }
}

variable "task_cpu" {
  description = "CPU units for ECS task (1024 = 1 vCPU)"
  type        = number
  default     = 4096
}

variable "task_memory" {
  description = "Memory for ECS task in MB"
  type        = number
  default     = 8192
}

variable "enable_recording" {
  description = "Enable video recording with Jibri"
  type        = bool
  default     = true
}

variable "max_participants" {
  description = "Maximum number of participants per meeting"
  type        = number
  default     = 50
}