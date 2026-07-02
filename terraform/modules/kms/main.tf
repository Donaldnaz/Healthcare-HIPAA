# ------------------------------------------------------------------------------
# KMS Module — Customer-managed key for encrypting SNS topics, Lambda env vars,
# and CloudWatch Logs.
#
# HIPAA relevance: Encryption at rest for alert channels and runtime secrets
# supports the Technical Safeguards requirement for access control and integrity.
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "key_policy" {
  # Root account retains full key management capability.
  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # SNS service may use this key to encrypt topic messages at rest.
  statement {
    sid    = "AllowSNSService"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:CreateGrant",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [var.account_id]
    }
  }

  # Lambda service may decrypt environment variables encrypted with this key.
  statement {
    sid    = "AllowLambdaService"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [var.account_id]
    }
  }

  # CloudWatch Logs may use this key to encrypt Lambda log groups at rest.
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.region}:${var.account_id}:log-group:*"]
    }
  }
}

resource "aws_kms_key" "main" {
  description             = "${var.prefix} CMK for SNS and Lambda encryption (HIPAA auto-remediation stack)"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.key_policy.json

  tags = merge(var.tags, {
    Name = "${var.prefix}-remediation-kms"
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.prefix}-remediation"
  target_key_id = aws_kms_key.main.key_id
}
