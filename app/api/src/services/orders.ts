// =============================================================================
// Order Service
// =============================================================================

import {
  config,
  createLogger,
  NotFoundError,
  ValidationError,
  putItem,
  getItem,
  queryItems,
  updateItem,
  publishOrderEvent,
  type CreateOrderInput,
  type Order,
  type OrderStatus,
  type PaginationInput,
  type PaginatedResult,
} from '@blueprint/shared';

const logger = createLogger('orders');

// DynamoDB table name
const ORDERS_TABLE = process.env.DYNAMODB_ORDERS_TABLE ?? `${config.PROJECT_NAME}-${config.NODE_ENV}-orders`;

// DynamoDB key prefix for orders
const ORDER_KEY_PREFIX = 'ORDER#';

// Valid status transitions
const STATUS_TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  pending: ['confirmed', 'cancelled'],
  confirmed: ['processing', 'cancelled'],
  processing: ['shipped', 'cancelled'],
  shipped: ['delivered'],
  delivered: [],
  cancelled: [],
};

class OrderService {
  // Create new order
  async createOrder(input: CreateOrderInput): Promise<Order> {
    const orderId = crypto.randomUUID();
    const now = new Date();

    // Calculate total amount
    const totalAmount = input.items.reduce((sum, item) => sum + item.totalPrice, 0);

    const order: Order = {
      id: orderId,
      customerId: input.customerId,
      status: 'pending',
      items: input.items,
      shippingAddress: input.shippingAddress,
      totalAmount,
      currency: 'USD',
      metadata: input.metadata ?? {},
      createdAt: now,
      updatedAt: now,
    };

    // DynamoDB item with composite keys (dates as ISO strings)
    const dynamoItem = {
      pk: `${ORDER_KEY_PREFIX}${orderId}`,
      sk: `${ORDER_KEY_PREFIX}${orderId}`,
      id: order.id,
      customerId: order.customerId,
      status: order.status,
      items: order.items,
      shippingAddress: order.shippingAddress,
      totalAmount: order.totalAmount,
      currency: order.currency,
      metadata: order.metadata,
      createdAt: now.toISOString(),
      updatedAt: now.toISOString(),
    };

    // Save to DynamoDB
    await putItem(ORDERS_TABLE, dynamoItem);

    logger.info({ orderId, customerId: input.customerId }, 'Order created');

    // Publish order.created event (non-blocking, but log failure prominently)
    try {
      await publishOrderEvent('order.created', orderId, input.customerId, {
        totalAmount,
        itemCount: input.items.length,
      });
    } catch (error) {
      logger.warn({ error, orderId }, 'Failed to publish order.created event, downstream processing may be delayed');
    }

    return order;
  }

  // Get order by ID
  async getOrder(orderId: string): Promise<Order> {
    const item = await getItem<Order & { pk: string; sk: string }>(ORDERS_TABLE, {
      pk: `${ORDER_KEY_PREFIX}${orderId}`,
      sk: `${ORDER_KEY_PREFIX}${orderId}`,
    });

    if (!item) {
      throw new NotFoundError('Order', orderId);
    }

    // Remove DynamoDB keys
    const { pk, sk, ...order } = item;
    return order as Order;
  }

  // List orders with pagination
  async listOrders(
    pagination: PaginationInput,
    filters?: { customerId?: string; status?: string }
  ): Promise<PaginatedResult<Order>> {
    const { page, limit } = pagination;
    const offset = (page - 1) * limit;

    let result;

    if (filters?.customerId) {
      // Query by customer using GSI
      result = await queryItems<Order>(
        ORDERS_TABLE,
        'customerId = :customerId',
        { ':customerId': filters.customerId },
        {
          indexName: 'CustomerOrders',
          limit: limit + 1, // Get one extra to check for next page
        }
      );
    } else if (filters?.status) {
      // Query by status using GSI
      result = await queryItems<Order>(
        ORDERS_TABLE,
        '#status = :status',
        { ':status': filters.status },
        {
          indexName: 'StatusIndex',
          expressionAttributeNames: { '#status': 'status' },
          limit: limit + 1,
        }
      );
    } else {
      // Scan all orders (not recommended for production with large datasets)
      const { items } = await queryItems<Order>(
        ORDERS_TABLE,
        'begins_with(pk, :pk)',
        { ':pk': ORDER_KEY_PREFIX },
        { limit: limit + 1 }
      );
      result = { items };
    }

    const hasNext = result.items.length > limit;
    const items = hasNext ? result.items.slice(0, limit) : result.items;

    // Estimate total (in real app, you'd track this separately)
    const estimatedTotal = hasNext ? (page + 1) * limit : page * limit - (limit - items.length);

    return {
      data: items,
      pagination: {
        page,
        limit,
        total: estimatedTotal,
        totalPages: Math.ceil(estimatedTotal / limit),
        hasNext,
        hasPrev: page > 1,
      },
    };
  }

  // Update order status
  async updateOrderStatus(orderId: string, newStatus: OrderStatus): Promise<Order> {
    // Get current order
    const order = await this.getOrder(orderId);
    const currentStatus = order.status;

    // Validate status transition
    const allowedTransitions = STATUS_TRANSITIONS[currentStatus];
    if (!allowedTransitions?.includes(newStatus)) {
      throw new ValidationError(
        `Invalid status transition from '${currentStatus}' to '${newStatus}'`,
        {
          currentStatus,
          newStatus,
          allowedTransitions,
        }
      );
    }

    // Update in DynamoDB with optimistic locking to prevent race conditions.
    // The condition ensures the status hasn't changed since we read it.
    const now = new Date();
    const updated = await updateItem<Order>(
      ORDERS_TABLE,
      { pk: `${ORDER_KEY_PREFIX}${orderId}`, sk: `${ORDER_KEY_PREFIX}${orderId}` },
      { status: newStatus, updatedAt: now.toISOString() },
      {
        conditionExpression: '#currentStatus = :expectedStatus',
        conditionAttributeNames: { '#currentStatus': 'status' },
        conditionAttributeValues: { ':expectedStatus': currentStatus },
      }
    );

    logger.info({ orderId, previousStatus: currentStatus, newStatus }, 'Order status updated');

    // Publish status change event (non-blocking)
    try {
      await publishOrderEvent(`order.${newStatus}` as 'order.confirmed', orderId, order.customerId, {
        previousStatus: currentStatus,
        status: newStatus,
      });
    } catch (error) {
      logger.warn({ error, orderId }, `Failed to publish order.${newStatus} event, downstream processing may be delayed`);
    }

    return updated ?? { ...order, status: newStatus, updatedAt: now };
  }

  // Cancel order
  async cancelOrder(orderId: string): Promise<Order> {
    return this.updateOrderStatus(orderId, 'cancelled');
  }
}

export const orderService = new OrderService();
