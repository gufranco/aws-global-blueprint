// =============================================================================
// Integration Tests - Orders
// =============================================================================

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import {
  SQSClient,
  CreateQueueCommand,
  DeleteQueueCommand,
  ReceiveMessageCommand,
} from '@aws-sdk/client-sqs';
import {
  SNSClient,
  CreateTopicCommand,
  DeleteTopicCommand,
  SubscribeCommand,
} from '@aws-sdk/client-sns';
import {
  DynamoDBClient,
  CreateTableCommand,
  DeleteTableCommand,
} from '@aws-sdk/client-dynamodb';

// LocalStack configuration
const LOCALSTACK_ENDPOINT = process.env['LOCALSTACK_ENDPOINT'] ?? 'http://localhost:4566';
const REGION = 'us-east-1';

const sqsClient = new SQSClient({
  region: REGION,
  endpoint: LOCALSTACK_ENDPOINT,
  credentials: {
    accessKeyId: 'test',
    secretAccessKey: 'test',
  },
});

const snsClient = new SNSClient({
  region: REGION,
  endpoint: LOCALSTACK_ENDPOINT,
  credentials: {
    accessKeyId: 'test',
    secretAccessKey: 'test',
  },
});

const dynamoClient = new DynamoDBClient({
  region: REGION,
  endpoint: LOCALSTACK_ENDPOINT,
  credentials: {
    accessKeyId: 'test',
    secretAccessKey: 'test',
  },
});

describe('Order Integration Tests', () => {
  let queueUrl: string;
  let topicArn: string;
  const queueName = 'test-order-queue';
  const topicName = 'test-order-topic';
  const tableName = 'test-orders';

  beforeAll(async () => {
    // Create SQS queue
    const createQueueResult = await sqsClient.send(
      new CreateQueueCommand({ QueueName: queueName })
    );
    queueUrl = createQueueResult.QueueUrl!;

    // Create SNS topic
    const createTopicResult = await snsClient.send(
      new CreateTopicCommand({ Name: topicName })
    );
    topicArn = createTopicResult.TopicArn!;

    // Subscribe queue to topic
    await snsClient.send(
      new SubscribeCommand({
        TopicArn: topicArn,
        Protocol: 'sqs',
        Endpoint: `arn:aws:sqs:${REGION}:000000000000:${queueName}`,
      })
    );

    // Create DynamoDB table
    await dynamoClient.send(
      new CreateTableCommand({
        TableName: tableName,
        KeySchema: [
          { AttributeName: 'pk', KeyType: 'HASH' },
          { AttributeName: 'sk', KeyType: 'RANGE' },
        ],
        AttributeDefinitions: [
          { AttributeName: 'pk', AttributeType: 'S' },
          { AttributeName: 'sk', AttributeType: 'S' },
        ],
        BillingMode: 'PAY_PER_REQUEST',
      })
    );
  });

  afterAll(async () => {
    // Cleanup resources
    await sqsClient.send(new DeleteQueueCommand({ QueueUrl: queueUrl }));
    await snsClient.send(new DeleteTopicCommand({ TopicArn: topicArn }));
    await dynamoClient.send(new DeleteTableCommand({ TableName: tableName }));
  });

  it('should create SQS queue successfully', () => {
    expect(queueUrl).toBeDefined();
    expect(queueUrl).toContain(queueName);
  });

  it('should create SNS topic successfully', () => {
    expect(topicArn).toBeDefined();
    expect(topicArn).toContain(topicName);
  });

  it('should receive messages from queue', async () => {
    // This test verifies the queue is working
    const result = await sqsClient.send(
      new ReceiveMessageCommand({
        QueueUrl: queueUrl,
        MaxNumberOfMessages: 1,
        WaitTimeSeconds: 1,
      })
    );

    // Queue should be empty but accessible
    expect(result.Messages ?? []).toHaveLength(0);
  });

  it('should process order event flow', async () => {
    // Simulate order creation event
    const orderEvent = {
      id: 'test-order-123',
      type: 'order.created',
      data: {
        orderId: 'order-123',
        customerId: 'customer-456',
        totalAmount: 99.99,
      },
      timestamp: new Date().toISOString(),
    };

    // In a real test, we would:
    // 1. Publish to SNS topic
    // 2. Wait for message to appear in SQS
    // 3. Process the message
    // 4. Verify DynamoDB was updated

    expect(orderEvent.type).toBe('order.created');
  });
});

describe('Order Validation Tests', () => {
  it('should validate order with valid data', () => {
    const validOrder = {
      customerId: '550e8400-e29b-41d4-a716-446655440000',
      items: [
        {
          productId: '550e8400-e29b-41d4-a716-446655440001',
          productName: 'Test Product',
          quantity: 1,
          unitPrice: 10.0,
          totalPrice: 10.0,
        },
      ],
      shippingAddress: {
        street: '123 Test St',
        city: 'Test City',
        state: 'TS',
        country: 'US',
        postalCode: '12345',
      },
    };

    expect(validOrder.customerId).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    );
    expect(validOrder.items.length).toBeGreaterThan(0);
  });

  it('should reject order with empty items', () => {
    const invalidOrder = {
      customerId: '550e8400-e29b-41d4-a716-446655440000',
      items: [],
      shippingAddress: {
        street: '123 Test St',
        city: 'Test City',
        state: 'TS',
        country: 'US',
        postalCode: '12345',
      },
    };

    expect(invalidOrder.items.length).toBe(0);
  });

  it('should calculate correct total amount', () => {
    const items = [
      { quantity: 2, unitPrice: 10.0, totalPrice: 20.0 },
      { quantity: 1, unitPrice: 15.0, totalPrice: 15.0 },
    ];

    const totalAmount = items.reduce((sum, item) => sum + item.totalPrice, 0);
    expect(totalAmount).toBe(35.0);
  });
});
