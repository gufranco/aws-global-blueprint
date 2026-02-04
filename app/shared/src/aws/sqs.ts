// =============================================================================
// SQS Client
// =============================================================================

import {
  SQSClient,
  SendMessageCommand,
  ReceiveMessageCommand,
  DeleteMessageCommand,
  GetQueueAttributesCommand,
  type SendMessageCommandInput,
  type ReceiveMessageCommandInput,
  type Message,
} from '@aws-sdk/client-sqs';

// Re-export Message type for consumers
export type { Message };
import { config, getAwsEndpoint } from '../config/index.js';
import { createLogger } from '../logger.js';

const logger = createLogger('sqs');

// Create SQS client
const endpoint = getAwsEndpoint();
export const sqsClient = new SQSClient({
  region: config.AWS_REGION,
  ...(endpoint && { endpoint }),
  ...(config.USE_LOCALSTACK && {
    credentials: {
      accessKeyId: 'test',
      secretAccessKey: 'test',
    },
  }),
});

// Send message to queue
export async function sendMessage(
  queueUrl: string,
  body: Record<string, unknown>,
  options?: {
    delaySeconds?: number;
    messageGroupId?: string;
    deduplicationId?: string;
    messageAttributes?: Record<string, { DataType: string; StringValue: string }>;
  }
): Promise<string> {
  const input: SendMessageCommandInput = {
    QueueUrl: queueUrl,
    MessageBody: JSON.stringify(body),
    DelaySeconds: options?.delaySeconds,
    MessageGroupId: options?.messageGroupId,
    MessageDeduplicationId: options?.deduplicationId,
    MessageAttributes: options?.messageAttributes,
  };

  logger.debug({ queueUrl, body }, 'Sending SQS message');

  const command = new SendMessageCommand(input);
  const response = await sqsClient.send(command);

  logger.info({ queueUrl, messageId: response.MessageId }, 'SQS message sent');

  return response.MessageId!;
}

// Receive messages from queue
export async function receiveMessages(
  queueUrl: string,
  options?: {
    maxMessages?: number;
    waitTimeSeconds?: number;
    visibilityTimeout?: number;
  }
): Promise<Message[]> {
  const input: ReceiveMessageCommandInput = {
    QueueUrl: queueUrl,
    MaxNumberOfMessages: options?.maxMessages ?? 10,
    WaitTimeSeconds: options?.waitTimeSeconds ?? 20,
    VisibilityTimeout: options?.visibilityTimeout ?? 60,
    MessageAttributeNames: ['All'],
    AttributeNames: ['All'],
  };

  const command = new ReceiveMessageCommand(input);
  const response = await sqsClient.send(command);

  return response.Messages ?? [];
}

// Delete message from queue
export async function deleteMessage(queueUrl: string, receiptHandle: string): Promise<void> {
  const command = new DeleteMessageCommand({
    QueueUrl: queueUrl,
    ReceiptHandle: receiptHandle,
  });

  await sqsClient.send(command);
  logger.debug({ queueUrl }, 'SQS message deleted');
}

// Get queue attributes
export async function getQueueAttributes(queueUrl: string): Promise<Record<string, string>> {
  const command = new GetQueueAttributesCommand({
    QueueUrl: queueUrl,
    AttributeNames: ['All'],
  });

  const response = await sqsClient.send(command);
  return response.Attributes ?? {};
}

// Check if SQS is healthy
export async function checkSqsHealth(queueUrl?: string): Promise<boolean> {
  try {
    const url = queueUrl ?? config.SQS_ORDER_QUEUE_URL;
    if (!url) return true; // No queue configured, skip check

    await getQueueAttributes(url);
    return true;
  } catch (error) {
    logger.error({ error }, 'SQS health check failed');
    return false;
  }
}
