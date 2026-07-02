# EventBridge module variables for S3 CloudTrail event routing.

variable "prefix" {
  description = "Resource naming prefix (project_name-environment)."
  type        = string
}

variable "tags" {
  description = "Standard tags applied to all EventBridge resources."
  type        = map(string)
  default     = {}
}

variable "lambda_function_arn" {
  description = "ARN of the remediation Lambda function target."
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the remediation Lambda function (for invoke permission)."
  type        = string
}
