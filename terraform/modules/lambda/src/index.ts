/**
 * S3 Public Access Auto-Remediation Lambda
 *
 * Triggered by EventBridge on CloudTrail CreateBucket / PutBucketAcl events.
 * Detects public S3 exposure and remediates by enabling block-public-access.
 * Publishes alerts to SNS and directly to Slack via incoming webhook.
 */
import {
  S3Client,
  GetPublicAccessBlockCommand,
  GetBucketAclCommand,
  GetBucketPolicyStatusCommand,
  PutPublicAccessBlockCommand,
  PublicAccessBlockConfiguration,
} from '@aws-sdk/client-s3';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import type { EventBridgeEvent } from 'aws-lambda';

interface CloudTrailDetail {
  eventSource: string;
  eventName: string;
  requestParameters?: {
    bucketName?: string;
    acl?: string;
    'x-amz-acl'?: string;
  };
  responseElements?: {
    bucketName?: string;
  };
}

interface RemediationResult {
  bucketName: string;
  eventName: string;
  violationDetected: boolean;
  remediated: boolean;
  details: string;
  timestamp: string;
}

const s3 = new S3Client({});
const sns = new SNSClient({});

const SNS_TOPIC_ARN = process.env.SNS_TOPIC_ARN ?? '';
const SLACK_WEBHOOK_URL = process.env.SLACK_WEBHOOK_URL ?? '';
const LOG_LEVEL = process.env.LOG_LEVEL ?? 'INFO';

function log(level: string, message: string, data?: unknown): void {
  if (level === 'DEBUG' && LOG_LEVEL !== 'DEBUG') return;
  console.log(JSON.stringify({ level, message, data, timestamp: new Date().toISOString() }));
}

function extractBucketName(detail: CloudTrailDetail): string | null {
  return (
    detail.requestParameters?.bucketName ??
    detail.responseElements?.bucketName ??
    null
  );
}

function isPublicAclGrant(acl: { Grants?: Array<{ Grantee?: { URI?: string } }> }): boolean {
  const publicUris = [
    'http://acs.amazonaws.com/groups/global/AllUsers',
    'http://acs.amazonaws.com/groups/global/AuthenticatedUsers',
  ];
  return (acl.Grants ?? []).some((grant) =>
    publicUris.includes(grant.Grantee?.URI ?? '')
  );
}

async function detectPublicExposure(bucketName: string): Promise<{ violation: boolean; details: string }> {
  const findings: string[] = [];

  // Check block public access configuration.
  try {
    const pab = await s3.send(new GetPublicAccessBlockCommand({ Bucket: bucketName }));
    const config = pab.PublicAccessBlockConfiguration;
    const allBlocked =
      config?.BlockPublicAcls &&
      config?.IgnorePublicAcls &&
      config?.BlockPublicPolicy &&
      config?.RestrictPublicBuckets;

    if (!allBlocked) {
      findings.push('PublicAccessBlock not fully enabled');
    }
  } catch (err: unknown) {
    const error = err as { name?: string };
    if (error.name === 'NoSuchPublicAccessBlockConfiguration') {
      findings.push('No PublicAccessBlock configuration exists');
    } else {
      throw err;
    }
  }

  // Check bucket ACL for public grants.
  try {
    const acl = await s3.send(new GetBucketAclCommand({ Bucket: bucketName }));
    if (isPublicAclGrant(acl)) {
      findings.push('Bucket ACL grants public or authenticated-users access');
    }
  } catch (err) {
    log('WARN', 'Unable to read bucket ACL', { bucketName, err });
  }

  // Check bucket policy public status.
  try {
    const policyStatus = await s3.send(new GetBucketPolicyStatusCommand({ Bucket: bucketName }));
    if (policyStatus.PolicyStatus?.IsPublic) {
      findings.push('Bucket policy allows public access');
    }
  } catch (err: unknown) {
    const error = err as { name?: string };
    if (error.name !== 'NoSuchBucketPolicy') {
      log('WARN', 'Unable to read bucket policy status', { bucketName, err });
    }
  }

  // PutBucketAcl with public-read or public-read-write is always a violation.
  return {
    violation: findings.length > 0,
    details: findings.length > 0 ? findings.join('; ') : 'No public exposure detected',
  };
}

async function remediateBucket(bucketName: string): Promise<void> {
  const config: PublicAccessBlockConfiguration = {
    BlockPublicAcls: true,
    IgnorePublicAcls: true,
    BlockPublicPolicy: true,
    RestrictPublicBuckets: true,
  };

  await s3.send(
    new PutPublicAccessBlockCommand({
      Bucket: bucketName,
      PublicAccessBlockConfiguration: config,
    })
  );
}

async function publishAlert(result: RemediationResult): Promise<void> {
  const message = [
    ':rotating_light: *S3 Security Auto-Remediation*',
    `*Bucket:* ${result.bucketName}`,
    `*Event:* ${result.eventName}`,
    `*Violation:* ${result.violationDetected}`,
    `*Remediated:* ${result.remediated}`,
    `*Details:* ${result.details}`,
    `*Timestamp:* ${result.timestamp}`,
  ].join('\n');

  if (SNS_TOPIC_ARN) {
    await sns.send(
      new PublishCommand({
        TopicArn: SNS_TOPIC_ARN,
        Subject: `S3 Security Alert: ${result.bucketName}`,
        Message: message,
      })
    );
    log('INFO', 'Published alert to SNS', { topicArn: SNS_TOPIC_ARN });
  }

  // Slack incoming webhooks cannot confirm SNS HTTPS subscriptions, so post directly.
  if (SLACK_WEBHOOK_URL) {
    const response = await fetch(SLACK_WEBHOOK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: message }),
    });

    if (!response.ok) {
      const body = await response.text();
      throw new Error(`Slack webhook failed: ${response.status} ${body}`);
    }

    log('INFO', 'Published alert to Slack');
  }

  if (!SNS_TOPIC_ARN && !SLACK_WEBHOOK_URL) {
    log('WARN', 'No SNS topic or Slack webhook configured; skipping alert');
  }
}

export async function handler(
  event: EventBridgeEvent<'AWS API Call via CloudTrail', CloudTrailDetail>
): Promise<RemediationResult> {
  log('INFO', 'Received CloudTrail event', { event });

  const detail = event.detail;
  const bucketName = extractBucketName(detail);

  if (!bucketName) {
    throw new Error(`Unable to extract bucket name from event: ${detail.eventName}`);
  }

  // PutBucketAcl requesting public ACL is an immediate violation.
  const requestedAcl = detail.requestParameters?.acl ?? detail.requestParameters?.['x-amz-acl'];
  const aclViolation =
    detail.eventName === 'PutBucketAcl' &&
    requestedAcl != null &&
    (requestedAcl.includes('public') || requestedAcl === 'public-read' || requestedAcl === 'public-read-write');

  const { violation, details } = await detectPublicExposure(bucketName);
  const violationDetected = violation || aclViolation;

  let remediated = false;
  let resultDetails = details;

  if (violationDetected) {
    await remediateBucket(bucketName);
    remediated = true;
    resultDetails = `${details}${aclViolation ? '; Public ACL requested via PutBucketAcl' : ''} — remediated via PutPublicAccessBlock`;
    log('INFO', 'Bucket remediated', { bucketName, resultDetails });
  } else {
    log('INFO', 'No violation detected', { bucketName });
  }

  const result: RemediationResult = {
    bucketName,
    eventName: detail.eventName,
    violationDetected,
    remediated,
    details: resultDetails,
    timestamp: new Date().toISOString(),
  };

  if (violationDetected) {
    await publishAlert(result);
  }

  return result;
}
