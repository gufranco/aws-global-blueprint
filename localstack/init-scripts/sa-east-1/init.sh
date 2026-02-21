#!/bin/bash
# =============================================================================
# LocalStack Init Script - SA East 1 (Sao Paulo)
# =============================================================================

set -euo pipefail

REGION="sa-east-1"
PROJECT="multiregion"
ENV="dev"

echo "=== Initializing LocalStack for $REGION ==="

# S3 Buckets
awslocal s3 mb s3://${PROJECT}-${ENV}-uploads-${REGION} --region $REGION || true
awslocal s3 mb s3://${PROJECT}-${ENV}-logs-${REGION} --region $REGION || true

# SQS Queues
awslocal sqs create-queue --queue-name ${PROJECT}-${ENV}-${REGION}-dlq --region $REGION || true
awslocal sqs create-queue --queue-name ${PROJECT}-${ENV}-${REGION}-order-processing --region $REGION || true
awslocal sqs create-queue --queue-name ${PROJECT}-${ENV}-${REGION}-notification --region $REGION || true

# SNS Topics
awslocal sns create-topic --name ${PROJECT}-${ENV}-${REGION}-order-events --region $REGION || true
awslocal sns create-topic --name ${PROJECT}-${ENV}-${REGION}-notifications --region $REGION || true
awslocal sns create-topic --name ${PROJECT}-${ENV}-${REGION}-alerts --region $REGION || true

# CloudWatch Log Groups
awslocal logs create-log-group --log-group-name /aws/ecs/${PROJECT}-${ENV}-${REGION}/api --region $REGION || true
awslocal logs create-log-group --log-group-name /aws/ecs/${PROJECT}-${ENV}-${REGION}/worker --region $REGION || true

echo "=== LocalStack $REGION initialized ==="
