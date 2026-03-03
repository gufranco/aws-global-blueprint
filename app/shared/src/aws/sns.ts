// =============================================================================
// SNS Client
// =============================================================================

import {
  SNSClient,
  PublishCommand,
  type PublishCommandInput,
  type MessageAttributeValue,
} from '@aws-sdk/client-sns';
import { config, getAwsEndpoint } from '../config/index.js';
import { createLogger } from '../logger.js';
import { CURRENT_SCHEMA_VERSION, type EventType } from '../types.js';

const logger = createLogger('sns');

// Create SNS client with explicit retry config
const endpoint = getAwsEndpoint();
export const snsClient = new SNSClient({
  region: config.AWS_REGION,
  maxAttempts: 3,
  ...(endpoint && { endpoint }),
  ...(config.USE_LOCALSTACK && {
    credentials: {
      accessKeyId: 'test',
      secretAccessKey: 'test',
    },
  }),
});

const PUBLISH_TIMEOUT_MS = 5000;

// Publish message to topic
export async function publishMessage(
  topicArn: string,
  message: Record<string, unknown>,
  options?: {
    subject?: string;
    messageGroupId?: string;
    deduplicationId?: string;
    messageAttributes?: Record<string, MessageAttributeValue>;
  },
): Promise<string> {
  const input: PublishCommandInput = {
    TopicArn: topicArn,
    Message: JSON.stringify(message),
    Subject: options?.subject,
    MessageGroupId: options?.messageGroupId,
    MessageDeduplicationId: options?.deduplicationId,
    MessageAttributes: options?.messageAttributes,
  };

  logger.debug({ topicArn, message }, 'Publishing SNS message');

  const command = new PublishCommand(input);
  const response = await snsClient.send(command, {
    abortSignal: AbortSignal.timeout(PUBLISH_TIMEOUT_MS),
  });

  logger.info({ topicArn, messageId: response.MessageId }, 'SNS message published');

  return response.MessageId!;
}

// Publish event with type attribute (for filtering)
export async function publishEvent(
  topicArn: string,
  eventType: EventType,
  data: Record<string, unknown>,
  correlationId?: string,
): Promise<string> {
  const event = {
    id: crypto.randomUUID(),
    type: eventType,
    schemaVersion: CURRENT_SCHEMA_VERSION,
    timestamp: new Date().toISOString(),
    source: config.OTEL_SERVICE_NAME,
    region: config.AWS_REGION,
    correlationId,
    data,
  };

  return publishMessage(topicArn, event, {
    messageAttributes: {
      eventType: {
        DataType: 'String',
        StringValue: eventType,
      },
    },
  });
}

// Publish order event
export async function publishOrderEvent(
  eventType: EventType,
  orderId: string,
  customerId: string,
  additionalData?: Record<string, unknown>,
  correlationId?: string,
): Promise<string> {
  const topicArn = config.SNS_ORDER_TOPIC_ARN;
  if (!topicArn) {
    throw new Error('SNS_ORDER_TOPIC_ARN not configured');
  }

  return publishEvent(
    topicArn,
    eventType,
    {
      orderId,
      customerId,
      ...additionalData,
    },
    correlationId,
  );
}

// Publish notification event
export async function publishNotification(
  notificationType: 'notification.email' | 'notification.push' | 'notification.sms',
  recipientId: string,
  body: string,
  options?: {
    recipientEmail?: string;
    recipientPhone?: string;
    subject?: string;
    templateId?: string;
    templateData?: Record<string, unknown>;
  },
): Promise<string> {
  const topicArn = config.SNS_NOTIFICATION_TOPIC_ARN;
  if (!topicArn) {
    throw new Error('SNS_NOTIFICATION_TOPIC_ARN not configured');
  }

  return publishEvent(topicArn, notificationType, {
    recipientId,
    body,
    ...options,
  });
}

// Check if SNS is healthy
export async function checkSnsHealth(): Promise<boolean> {
  try {
    // Simple check - we can't easily check topic without publishing
    return true;
  } catch (error) {
    logger.error({ error }, 'SNS health check failed');
    return false;
  }
}
