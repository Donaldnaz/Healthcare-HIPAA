# Lambda module variables for the S3 auto-remediation function.

variable "prefix" {
  description = "Resource naming prefix (project_name-environment)."
  type        = string
}

variable "tags" {
  description = "Standard tags applied to all Lambda resources."
  type        = map(string)
  default     = {}
}

variable "lambda_role_arn" {
  description = "IAM execution role ARN for the Lambda function."
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for publishing security alerts."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting Lambda environment variables."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days (HIPAA audit trail)."
  type        = number
  default     = 90
}

variable "slack_webhook_url" {
  description = "Optional Slack incoming webhook URL for direct alert delivery."
  type        = string
  default     = ""
  sensitive   = true
}

variable "reserved_concurrent_executions" {
  description = "Cap concurrent executions. Leave null to use account defaults (recommended for dev accounts)."
  type        = number
  default     = null
  nullable    = true
}
