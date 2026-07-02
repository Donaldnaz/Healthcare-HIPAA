# KMS module variables for HIPAA-compliant encryption of SNS and Lambda resources.

variable "prefix" {
  description = "Resource naming prefix (project_name-environment)."
  type        = string
}

variable "tags" {
  description = "Standard tags applied to all KMS resources."
  type        = map(string)
  default     = {}
}

variable "account_id" {
  description = "AWS account ID for KMS key policy principals."
  type        = string
}

variable "region" {
  description = "AWS region for KMS key policy ARNs."
  type        = string
}
