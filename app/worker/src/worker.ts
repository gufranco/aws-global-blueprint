// =============================================================================
// Worker Manager
// =============================================================================

import {
  config,
  createLogger,
  receiveMessages,
  deleteMessage,
  type Message,
} from '@multiregion/shared';
import { processOrderMessage } from './handlers/orders.js';
import { processNotificationMessage } from './handlers/notifications.js';

const logger = createLogger('worker-manager');

interface QueueConfig {
  name: string;
  url: string | undefined;
  handler: (message: Message) => Promise<void>;
  enabled: boolean;
}

export class WorkerManager {
  private isRunning = false;
  private queues: QueueConfig[];

  constructor() {
    this.queues = [
      {
        name: 'order-processing',
        url: config.SQS_ORDER_QUEUE_URL,
        handler: processOrderMessage,
        enabled: !!config.SQS_ORDER_QUEUE_URL,
      },
      {
        name: 'notification',
        url: config.SQS_NOTIFICATION_QUEUE_URL,
        handler: processNotificationMessage,
        enabled: !!config.SQS_NOTIFICATION_QUEUE_URL,
      },
    ];
  }

  async start(): Promise<void> {
    this.isRunning = true;

    const enabledQueues = this.queues.filter((q) => q.enabled);

    if (enabledQueues.length === 0) {
      logger.warn('No queues configured, worker will idle');
      return;
    }

    logger.info(
      { queues: enabledQueues.map((q) => q.name) },
      'Starting queue polling'
    );

    // Start polling each queue
    for (const queue of enabledQueues) {
      this.pollQueue(queue);
    }
  }

  async stop(): Promise<void> {
    this.isRunning = false;
    logger.info('Worker stopping...');
  }

  private async pollQueue(queue: QueueConfig): Promise<void> {
    while (this.isRunning) {
      try {
        await this.processQueueBatch(queue);
      } catch (error) {
        logger.error(
          { error, queue: queue.name },
          'Error polling queue, will retry'
        );
        // Back off on error
        await this.sleep(5000);
      }
    }
  }

  private async processQueueBatch(queue: QueueConfig): Promise<void> {
    if (!queue.url) return;

    // Receive messages with long polling
    const messages = await receiveMessages(queue.url, {
      maxMessages: 10,
      waitTimeSeconds: 20,
      visibilityTimeout: 60,
    });

    if (messages.length === 0) {
      return;
    }

    logger.debug(
      { queue: queue.name, count: messages.length },
      'Received messages'
    );

    // Process messages in parallel
    const results = await Promise.allSettled(
      messages.map((message) => this.processMessage(queue, message))
    );

    // Log results
    const succeeded = results.filter((r) => r.status === 'fulfilled').length;
    const failed = results.filter((r) => r.status === 'rejected').length;

    if (failed > 0) {
      logger.warn(
        { queue: queue.name, succeeded, failed },
        'Some messages failed processing'
      );
    }
  }

  private async processMessage(
    queue: QueueConfig,
    message: Message
  ): Promise<void> {
    const messageId = message.MessageId;
    const startTime = Date.now();

    try {
      logger.debug({ messageId, queue: queue.name }, 'Processing message');

      // Process the message
      await queue.handler(message);

      // Delete the message on success
      if (message.ReceiptHandle && queue.url) {
        await deleteMessage(queue.url, message.ReceiptHandle);
      }

      const duration = Date.now() - startTime;
      logger.info(
        { messageId, queue: queue.name, duration },
        'Message processed successfully'
      );
    } catch (error) {
      const duration = Date.now() - startTime;
      logger.error(
        { error, messageId, queue: queue.name, duration },
        'Failed to process message'
      );

      // Don't delete - let it become visible again for retry
      // After max retries, it will go to DLQ
      throw error;
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
