# SNS module variables for security alert notifications.

variable "prefix" {
  description = "Resource naming prefix (project_name-environment)."
  type        = string
}

variable "tags" {
  description = "Standard tags applied to all SNS resources."
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt the SNS topic at rest."
  type        = string
}
