variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in resource naming and tags."
  type        = string
  default     = "hcp-compliance"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "slack_webhook_url" {
  description = "Optional Slack incoming webhook URL for SNS HTTPS subscription."
  type        = string
  default     = ""
  sensitive   = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days for HIPAA audit trail."
  type        = number
  default     = 90
}

variable "reserved_concurrent_executions" {
  description = "Maximum concurrent Lambda executions. Leave null for account defaults."
  type        = number
  default     = null
  nullable    = true
}
