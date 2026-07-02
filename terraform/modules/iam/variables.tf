# IAM module variables for Lambda execution role and EventBridge invoke permission.

variable "prefix" {
  description = "Resource naming prefix (project_name-environment)."
  type        = string
}

variable "tags" {
  description = "Standard tags applied to all IAM resources."
  type        = map(string)
  default     = {}
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic the Lambda may publish to."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for SNS encryption and Lambda env vars."
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name for the remediation Lambda."
  type        = string
}
