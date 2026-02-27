#!/bin/bash
# =============================================================================
# LocalStack Init Script - US East 1 (Primary Region)
# =============================================================================
# This script initializes AWS resources for the primary region.
# It runs automatically when the LocalStack container starts.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
PROJECT="blueprint"
ENV="dev"

echo "=== Initializing LocalStack for $REGION ==="

# -----------------------------------------------------------------------------
# S3 Buckets
# -----------------------------------------------------------------------------

echo "Creating S3 buckets..."
awslocal s3 mb s3://${PROJECT}-${ENV}-uploads-${REGION} --region $REGION || true
awslocal s3 mb s3://${PROJECT}-${ENV}-logs-${REGION} --region $REGION || true
awslocal s3 mb s3://${PROJECT}-${ENV}-assets-${REGION} --region $REGION || true

# -----------------------------------------------------------------------------
# DynamoDB Tables
# -----------------------------------------------------------------------------

echo "Creating DynamoDB tables..."

# Sessions table
awslocal dynamodb create-table \
  --table-name ${PROJECT}-${ENV}-sessions \
  --attribute-definitions \
    AttributeName=pk,AttributeType=S \
    AttributeName=sk,AttributeType=S \
    AttributeName=gsi1pk,AttributeType=S \
    AttributeName=gsi1sk,AttributeType=S \
  --key-schema \
    AttributeName=pk,KeyType=HASH \
    AttributeName=sk,KeyType=RANGE \
  --global-secondary-indexes \
    '[{"IndexName":"GSI1","KeySchema":[{"AttributeName":"gsi1pk","KeyType":"HASH"},{"AttributeName":"gsi1sk","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]' \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION || true

# Orders table
awslocal dynamodb create-table \
  --table-name ${PROJECT}-${ENV}-orders \
  --attribute-definitions \
    AttributeName=pk,AttributeType=S \
    AttributeName=sk,AttributeType=S \
    AttributeName=customerId,AttributeType=S \
    AttributeName=status,AttributeType=S \
    AttributeName=createdAt,AttributeType=S \
  --key-schema \
    AttributeName=pk,KeyType=HASH \
    AttributeName=sk,KeyType=RANGE \
  --global-secondary-indexes \
    '[{"IndexName":"CustomerOrders","KeySchema":[{"AttributeName":"customerId","KeyType":"HASH"},{"AttributeName":"createdAt","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}},{"IndexName":"StatusIndex","KeySchema":[{"AttributeName":"status","KeyType":"HASH"},{"AttributeName":"createdAt","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]' \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION || true

# Events table
awslocal dynamodb create-table \
  --table-name ${PROJECT}-${ENV}-events \
  --attribute-definitions \
    AttributeName=pk,AttributeType=S \
    AttributeName=sk,AttributeType=S \
    AttributeName=eventType,AttributeType=S \
  --key-schema \
    AttributeName=pk,KeyType=HASH \
    AttributeName=sk,KeyType=RANGE \
  --global-secondary-indexes \
    '[{"IndexName":"EventTypeIndex","KeySchema":[{"AttributeName":"eventType","KeyType":"HASH"},{"AttributeName":"sk","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]' \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION || true

# -----------------------------------------------------------------------------
# SQS Queues
# -----------------------------------------------------------------------------

echo "Creating SQS queues..."

# Dead Letter Queue
awslocal sqs create-queue \
  --queue-name ${PROJECT}-${ENV}-${REGION}-dlq \
  --region $REGION || true

DLQ_ARN=$(awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/${PROJECT}-${ENV}-${REGION}-dlq \
  --attribute-names QueueArn \
  --region $REGION \
  --query 'Attributes.QueueArn' \
  --output text)

# Order Processing Queue
awslocal sqs create-queue \
  --queue-name ${PROJECT}-${ENV}-${REGION}-order-processing \
  --attributes "{\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"$DLQ_ARN\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\"}" \
  --region $REGION || true

# Notification Queue
awslocal sqs create-queue \
  --queue-name ${PROJECT}-${ENV}-${REGION}-notification \
  --attributes "{\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"$DLQ_ARN\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\"}" \
  --region $REGION || true

# FIFO Queue
awslocal sqs create-queue \
  --queue-name ${PROJECT}-${ENV}-${REGION}-order.fifo \
  --attributes '{"FifoQueue":"true","ContentBasedDeduplication":"true"}' \
  --region $REGION || true

# -----------------------------------------------------------------------------
# SNS Topics
# -----------------------------------------------------------------------------

echo "Creating SNS topics..."

# Order Events Topic
ORDER_TOPIC_ARN=$(awslocal sns create-topic \
  --name ${PROJECT}-${ENV}-${REGION}-order-events \
  --region $REGION \
  --query 'TopicArn' \
  --output text)

# Notifications Topic
NOTIFICATION_TOPIC_ARN=$(awslocal sns create-topic \
  --name ${PROJECT}-${ENV}-${REGION}-notifications \
  --region $REGION \
  --query 'TopicArn' \
  --output text)

# Alerts Topic
awslocal sns create-topic \
  --name ${PROJECT}-${ENV}-${REGION}-alerts \
  --region $REGION || true

# -----------------------------------------------------------------------------
# SNS -> SQS Subscriptions
# -----------------------------------------------------------------------------

echo "Creating SNS subscriptions..."

ORDER_QUEUE_URL="http://localhost:4566/000000000000/${PROJECT}-${ENV}-${REGION}-order-processing"
ORDER_QUEUE_ARN="arn:aws:sqs:${REGION}:000000000000:${PROJECT}-${ENV}-${REGION}-order-processing"

awslocal sns subscribe \
  --topic-arn $ORDER_TOPIC_ARN \
  --protocol sqs \
  --notification-endpoint $ORDER_QUEUE_ARN \
  --region $REGION || true

NOTIFICATION_QUEUE_URL="http://localhost:4566/000000000000/${PROJECT}-${ENV}-${REGION}-notification"
NOTIFICATION_QUEUE_ARN="arn:aws:sqs:${REGION}:000000000000:${PROJECT}-${ENV}-${REGION}-notification"

awslocal sns subscribe \
  --topic-arn $NOTIFICATION_TOPIC_ARN \
  --protocol sqs \
  --notification-endpoint $NOTIFICATION_QUEUE_ARN \
  --region $REGION || true

# -----------------------------------------------------------------------------
# Secrets Manager
# -----------------------------------------------------------------------------

echo "Creating secrets..."

awslocal secretsmanager create-secret \
  --name ${PROJECT}/${ENV}/database \
  --secret-string '{"username":"postgres","password":"postgres","host":"postgres","port":"5432","dbname":"app"}' \
  --region $REGION || true

awslocal secretsmanager create-secret \
  --name ${PROJECT}/${ENV}/redis \
  --secret-string '{"host":"redis","port":"6379"}' \
  --region $REGION || true

# -----------------------------------------------------------------------------
# CloudWatch Log Groups
# -----------------------------------------------------------------------------

echo "Creating CloudWatch log groups..."

awslocal logs create-log-group \
  --log-group-name /aws/ecs/${PROJECT}-${ENV}-${REGION}/api \
  --region $REGION || true

awslocal logs create-log-group \
  --log-group-name /aws/ecs/${PROJECT}-${ENV}-${REGION}/worker \
  --region $REGION || true

awslocal logs create-log-group \
  --log-group-name /aws/lambda/${PROJECT}-${ENV}-${REGION}-order-processor \
  --region $REGION || true

awslocal logs create-log-group \
  --log-group-name /aws/lambda/${PROJECT}-${ENV}-${REGION}-notification-handler \
  --region $REGION || true

awslocal logs create-log-group \
  --log-group-name /aws/lambda/${PROJECT}-${ENV}-${REGION}-dlq-handler \
  --region $REGION || true

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

echo ""
echo "=== LocalStack $REGION initialized successfully ==="
echo ""
echo "S3 Buckets:"
awslocal s3 ls --region $REGION
echo ""
echo "DynamoDB Tables:"
awslocal dynamodb list-tables --region $REGION
echo ""
echo "SQS Queues:"
awslocal sqs list-queues --region $REGION
echo ""
echo "SNS Topics:"
awslocal sns list-topics --region $REGION
echo ""
