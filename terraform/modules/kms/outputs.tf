output "key_arn" {
  description = "ARN of the customer-managed KMS key."
  value       = aws_kms_key.main.arn
}

output "key_id" {
  description = "ID of the customer-managed KMS key."
  value       = aws_kms_key.main.key_id
}

output "alias_name" {
  description = "KMS key alias name."
  value       = aws_kms_alias.main.name
}
