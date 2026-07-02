provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  prefix = "${var.project_name}-${var.environment}"
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Compliance  = "HIPAA"
  }
  log_group_name = "/aws/lambda/${local.prefix}-s3-remediation-lambda"
}

# ------------------------------------------------------------------------------
# KMS — Encrypt SNS alerts and Lambda environment variables at rest.
# ------------------------------------------------------------------------------
module "kms" {
  source = "../../modules/kms"

  prefix     = local.prefix
  tags       = local.tags
  account_id = data.aws_caller_identity.current.account_id
  region     = var.aws_region
}

# ------------------------------------------------------------------------------
# SNS — Encrypted security alert topic (extensible for email/SMS/Lambda subs).
# Slack alerts are delivered directly from the remediation Lambda.
# ------------------------------------------------------------------------------
module "sns" {
  source = "../../modules/sns"

  prefix      = local.prefix
  tags        = local.tags
  kms_key_arn = module.kms.key_arn
}

# ------------------------------------------------------------------------------
# IAM — Least-privilege Lambda execution role.
# Created before Lambda; log group name is deterministic from prefix.
# ------------------------------------------------------------------------------
module "iam" {
  source = "../../modules/iam"

  prefix         = local.prefix
  tags           = local.tags
  sns_topic_arn  = module.sns.topic_arn
  kms_key_arn    = module.kms.key_arn
  log_group_name = local.log_group_name
}

# ------------------------------------------------------------------------------
# Lambda — S3 auto-remediation function (TypeScript, event-driven).
# ------------------------------------------------------------------------------
module "lambda" {
  source = "../../modules/lambda"

  prefix                         = local.prefix
  tags                           = local.tags
  lambda_role_arn                = module.iam.lambda_role_arn
  sns_topic_arn                  = module.sns.topic_arn
  kms_key_arn                    = module.kms.key_arn
  slack_webhook_url              = var.slack_webhook_url
  log_retention_days             = var.log_retention_days
  reserved_concurrent_executions = var.reserved_concurrent_executions
}

# ------------------------------------------------------------------------------
# EventBridge — Routes CloudTrail S3 API events to the remediation Lambda.
#
# This event-driven pattern catches compliance drift in near real-time.
# Scheduled scanners (Config, Security Hub) typically run on hourly/daily
# cadences, leaving a window where public S3 buckets could expose PHI.
# EventBridge + CloudTrail closes that gap to seconds.
# ------------------------------------------------------------------------------
module "eventbridge" {
  source = "../../modules/eventbridge"

  prefix               = local.prefix
  tags                 = local.tags
  lambda_function_arn  = module.lambda.function_arn
  lambda_function_name = module.lambda.function_name
}
