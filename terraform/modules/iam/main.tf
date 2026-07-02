# ------------------------------------------------------------------------------
# IAM Module — Least-privilege execution role for the S3 remediation Lambda.
#
# Permissions are scoped to:
#   - Read S3 bucket configuration (detect public exposure)
#   - Modify S3 public access blocks (remediate)
#   - Write structured logs to CloudWatch
#   - Publish alerts to the encrypted SNS topic
#   - Decrypt KMS-protected env vars and SNS payloads
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "lambda_execution" {
  # Read S3 bucket configuration to detect public access misconfigurations.
  statement {
    sid    = "S3ReadBucketConfiguration"
    effect = "Allow"
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketPolicy",
      "s3:GetBucketPolicyStatus",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketLocation",
    ]
    resources = ["arn:aws:s3:::*"]
  }

  # Remediate by enforcing block-public-access on non-compliant buckets.
  statement {
    sid       = "S3RemediatePublicAccessBlock"
    effect    = "Allow"
    actions   = ["s3:PutBucketPublicAccessBlock"]
    resources = ["arn:aws:s3:::*"]
  }

  # Write execution logs for HIPAA audit trail.
  statement {
    sid    = "CloudWatchLogsWrite"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${var.log_group_name}",
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${var.log_group_name}:*",
    ]
  }

  # Publish security alerts to the encrypted SNS topic (Slack channel).
  statement {
    sid       = "SNSPublishAlerts"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [var.sns_topic_arn]
  }

  # Decrypt KMS-protected environment variables and SNS payloads.
  statement {
    sid    = "KMSDecryptForLambdaAndSNS"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = [var.kms_key_arn]
  }

  # X-Ray tracing for request-level audit visibility.
  statement {
    sid    = "XRayTracing"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "lambda_execution" {
  name               = "${var.prefix}-s3-remediation-lambda-role"
  description        = "Least-privilege execution role for S3 auto-remediation Lambda (HIPAA compliance)"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.prefix}-s3-remediation-lambda-role"
  })
}

resource "aws_iam_role_policy" "lambda_execution" {
  name   = "${var.prefix}-s3-remediation-lambda-policy"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.lambda_execution.json
}
