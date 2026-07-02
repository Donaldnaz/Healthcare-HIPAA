output "kms_key_arn" {
  description = "ARN of the customer-managed KMS key."
  value       = module.kms.key_arn
}

output "sns_topic_arn" {
  description = "ARN of the security alerts SNS topic."
  value       = module.sns.topic_arn
}

output "lambda_function_arn" {
  description = "ARN of the S3 remediation Lambda function."
  value       = module.lambda.function_arn
}

output "lambda_function_name" {
  description = "Name of the S3 remediation Lambda function."
  value       = module.lambda.function_name
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule monitoring S3 API calls."
  value       = module.eventbridge.rule_name
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group for Lambda execution logs."
  value       = module.lambda.log_group_name
}

output "lambda_role_arn" {
  description = "IAM execution role ARN for the remediation Lambda."
  value       = module.iam.lambda_role_arn
}
