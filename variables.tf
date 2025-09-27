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
  description = "Domain name for the Jitsi platform"
  type        = string
  default     = "meet.awsaerospace.org"
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