// =============================================================================
// Order Message Handler
// =============================================================================

import {
  createLogger,
  type Message,
  type OrderEvent,
  orderEventSchema,
  updateItem,
  config,
  publishNotification,
} from '@multiregion/shared';

const logger = createLogger('order-handler');

// DynamoDB table name
const ORDERS_TABLE = `${config.OTEL_SERVICE_NAME.replace('-app', '')}-${config.NODE_ENV}-orders`;

export async function processOrderMessage(message: Message): Promise<void> {
  if (!message.Body) {
    logger.warn({ messageId: message.MessageId }, 'Empty message body');
    return;
  }

  // Parse SNS wrapper if present
  let eventData: unknown;
  try {
    const body = JSON.parse(message.Body);
    // SNS wraps the message
    if (body.Message) {
      eventData = JSON.parse(body.Message);
    } else {
      eventData = body;
    }
  } catch (error) {
    logger.error({ error, body: message.Body }, 'Failed to parse message body');
    throw error;
  }

  // Validate event
  const parseResult = orderEventSchema.safeParse(eventData);
  if (!parseResult.success) {
    logger.error(
      { errors: parseResult.error.errors, event: eventData },
      'Invalid order event'
    );
    throw new Error('Invalid order event format');
  }

  const event = parseResult.data;

  logger.info(
    {
      eventId: event.id,
      eventType: event.type,
      orderId: event.data.orderId,
      customerId: event.data.customerId,
    },
    'Processing order event'
  );

  // Handle different event types
  switch (event.type) {
    case 'order.created':
      await handleOrderCreated(event);
      break;

    case 'order.confirmed':
      await handleOrderConfirmed(event);
      break;

    case 'order.processing':
      await handleOrderProcessing(event);
      break;

    case 'order.shipped':
      await handleOrderShipped(event);
      break;

    case 'order.delivered':
      await handleOrderDelivered(event);
      break;

    case 'order.cancelled':
      await handleOrderCancelled(event);
      break;

    default:
      logger.warn({ eventType: event.type }, 'Unknown event type');
  }
}

// Handle order.created event
async function handleOrderCreated(event: OrderEvent): Promise<void> {
  const { orderId, customerId } = event.data;

  logger.info({ orderId, customerId }, 'Processing order.created');

  // Example: Send confirmation notification
  try {
    await publishNotification(
      'notification.email',
      customerId,
      `Your order ${orderId} has been received and is being processed.`,
      {
        subject: 'Order Confirmation',
        templateId: 'order-confirmation',
        templateData: { orderId },
      }
    );
  } catch (error) {
    logger.error({ error, orderId }, 'Failed to send order confirmation notification');
    // Don't fail the handler - notification is non-critical
  }
}

// Handle order.confirmed event
async function handleOrderConfirmed(event: OrderEvent): Promise<void> {
  const { orderId, customerId } = event.data;

  logger.info({ orderId, customerId }, 'Processing order.confirmed');

  // Example: Update inventory, start fulfillment process, etc.
  // In a real app, you'd integrate with inventory and fulfillment systems
}

// Handle order.processing event
async function handleOrderProcessing(event: OrderEvent): Promise<void> {
  const { orderId, customerId } = event.data;

  logger.info({ orderId, customerId }, 'Processing order.processing');

  // Example: Notify customer that order is being prepared
  try {
    await publishNotification(
      'notification.email',
      customerId,
      `Your order ${orderId} is now being prepared for shipment.`,
      {
        subject: 'Order Update - Processing',
        templateId: 'order-processing',
        templateData: { orderId },
      }
    );
  } catch (error) {
    logger.error({ error, orderId }, 'Failed to send processing notification');
  }
}

// Handle order.shipped event
async function handleOrderShipped(event: OrderEvent): Promise<void> {
  const { orderId, customerId } = event.data;

  logger.info({ orderId, customerId }, 'Processing order.shipped');

  // Example: Send shipping notification with tracking info
  try {
    await publishNotification(
      'notification.email',
      customerId,
      `Your order ${orderId} has been shipped! You can track your package using the link below.`,
      {
        subject: 'Order Shipped',
        templateId: 'order-shipped',
        templateData: {
          orderId,
          // In real app, you'd include tracking number and carrier
          trackingUrl: `https://example.com/track/${orderId}`,
        },
      }
    );
  } catch (error) {
    logger.error({ error, orderId }, 'Failed to send shipping notification');
  }
}

// Handle order.delivered event
async function handleOrderDelivered(event: OrderEvent): Promise<void> {
  const { orderId, customerId } = event.data;

  logger.info({ orderId, customerId }, 'Processing order.delivered');

  // Example: Send delivery confirmation and request feedback
  try {
    await publishNotification(
      'notification.email',
      customerId,
      `Your order ${orderId} has been delivered! We hope you enjoy your purchase.`,
      {
        subject: 'Order Delivered',
        templateId: 'order-delivered',
        templateData: {
          orderId,
          feedbackUrl: `https://example.com/feedback/${orderId}`,
        },
      }
    );
  } catch (error) {
    logger.error({ error, orderId }, 'Failed to send delivery notification');
  }
}

// Handle order.cancelled event
async function handleOrderCancelled(event: OrderEvent): Promise<void> {
  const { orderId, customerId } = event.data;

  logger.info({ orderId, customerId }, 'Processing order.cancelled');

  // Example: Refund processing, inventory restoration, etc.
  // In a real app, you'd integrate with payment and inventory systems

  try {
    await publishNotification(
      'notification.email',
      customerId,
      `Your order ${orderId} has been cancelled. If you were charged, a refund will be processed within 5-7 business days.`,
      {
        subject: 'Order Cancelled',
        templateId: 'order-cancelled',
        templateData: { orderId },
      }
    );
  } catch (error) {
    logger.error({ error, orderId }, 'Failed to send cancellation notification');
  }
}
