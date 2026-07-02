output "rule_arn" {
  description = "ARN of the EventBridge rule for S3 security events."
  value       = aws_cloudwatch_event_rule.s3_security_events.arn
}

output "rule_name" {
  description = "Name of the EventBridge rule for S3 security events."
  value       = aws_cloudwatch_event_rule.s3_security_events.name
}
