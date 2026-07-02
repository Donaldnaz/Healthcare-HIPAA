# ------------------------------------------------------------------------------
# SNS Module — Encrypted topic for security violation and remediation alerts.
#
# Slack delivery is handled directly by the Lambda (incoming webhooks cannot
# confirm SNS HTTPS subscriptions). SNS remains available for email, SMS, or
# additional Lambda subscribers.
# ------------------------------------------------------------------------------

resource "aws_sns_topic" "security_alerts" {
  name              = "${var.prefix}-s3-security-alerts"
  display_name      = "S3 Security Auto-Remediation Alerts"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.tags, {
    Name        = "${var.prefix}-s3-security-alerts"
    Description = "Publishes S3 public access violation and remediation events"
  })
}
