# ------------------------------------------------------------------------------
# EventBridge Module — Near real-time S3 API event routing via CloudTrail.
#
# Unlike scheduled compliance scanners that run hourly or daily, this rule
# reacts within seconds of CreateBucket or PutBucketAcl API calls. That
# shrinks the exposure window for public S3 misconfigurations — a critical
# HIPAA Technical Safeguard against unauthorized PHI storage exposure.
#
# Prerequisite: CloudTrail management events must be delivered to EventBridge.
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "s3_security_events" {
  name        = "${var.prefix}-s3-security-events"
  description = "Detects S3 CreateBucket and PutBucketAcl API calls via CloudTrail for HIPAA drift remediation"

  event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["s3.amazonaws.com"]
      eventName   = ["CreateBucket", "PutBucketAcl"]
    }
  })

  tags = merge(var.tags, {
    Name = "${var.prefix}-s3-security-events"
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.s3_security_events.name
  target_id = "S3RemediationLambda"
  arn       = var.lambda_function_arn
}

# Grant EventBridge permission to invoke the remediation Lambda.
resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_security_events.arn
}
