output "function_arn" {
  description = "ARN of the S3 remediation Lambda function."
  value       = aws_lambda_function.remediation.arn
}

output "function_name" {
  description = "Name of the S3 remediation Lambda function."
  value       = aws_lambda_function.remediation.function_name
}

output "log_group_name" {
  description = "CloudWatch log group name for the remediation Lambda."
  value       = aws_cloudwatch_log_group.remediation.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN for the remediation Lambda."
  value       = aws_cloudwatch_log_group.remediation.arn
}
