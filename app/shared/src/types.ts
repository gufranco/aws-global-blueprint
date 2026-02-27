// =============================================================================
// Shared Types
// =============================================================================

import { z } from 'zod';

// =============================================================================
// Order Types
// =============================================================================

export const OrderStatus = {
  PENDING: 'pending',
  CONFIRMED: 'confirmed',
  PROCESSING: 'processing',
  SHIPPED: 'shipped',
  DELIVERED: 'delivered',
  CANCELLED: 'cancelled',
} as const;

export type OrderStatus = (typeof OrderStatus)[keyof typeof OrderStatus];

// Single source of truth for the order status state machine.
// Both the service layer and tests should reference this map.
export const ORDER_STATUS_TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  pending: ['confirmed', 'cancelled'],
  confirmed: ['processing', 'cancelled'],
  processing: ['shipped', 'cancelled'],
  shipped: ['delivered'],
  delivered: [],
  cancelled: [],
} as const;

export function isValidStatusTransition(from: OrderStatus, to: OrderStatus): boolean {
  return ORDER_STATUS_TRANSITIONS[from]?.includes(to) ?? false;
}

export const orderItemSchema = z.object({
  productId: z.string().uuid(),
  productName: z.string().min(1),
  quantity: z.number().int().positive(),
  unitPrice: z.number().positive(),
  totalPrice: z.number().positive(),
});

export type OrderItem = z.infer<typeof orderItemSchema>;

export const createOrderSchema = z.object({
  customerId: z.string().uuid(),
  items: z.array(orderItemSchema).min(1),
  shippingAddress: z.object({
    street: z.string().min(1),
    city: z.string().min(1),
    state: z.string().min(1),
    country: z.string().min(2).max(2),
    postalCode: z.string().min(1),
  }),
  metadata: z
    .record(z.unknown())
    .refine((obj) => Object.keys(obj).length <= 50, 'metadata cannot have more than 50 keys')
    .optional(),
});

export type CreateOrderInput = z.infer<typeof createOrderSchema>;

export const orderSchema = createOrderSchema.extend({
  id: z.string().uuid(),
  status: z.nativeEnum(OrderStatus),
  totalAmount: z.number(),
  currency: z.string().default('USD'),
  createdAt: z.coerce.date(),
  updatedAt: z.coerce.date(),
});

export type Order = z.infer<typeof orderSchema>;

// =============================================================================
// Event Types
// =============================================================================

export const eventTypeSchema = z.enum([
  'order.created',
  'order.confirmed',
  'order.processing',
  'order.shipped',
  'order.delivered',
  'order.cancelled',
  'order.updated',
  'notification.email',
  'notification.push',
  'notification.sms',
]);

export type EventType = z.infer<typeof eventTypeSchema>;

export const CURRENT_SCHEMA_VERSION = '1.0';

export const baseEventSchema = z.object({
  id: z.string().uuid(),
  type: eventTypeSchema,
  schemaVersion: z.string().default(CURRENT_SCHEMA_VERSION),
  timestamp: z.coerce.date(),
  source: z.string(),
  region: z.string(),
  correlationId: z.string().uuid().optional(),
  metadata: z.record(z.unknown()).optional(),
});

export const orderEventSchema = baseEventSchema.extend({
  type: z.enum([
    'order.created',
    'order.confirmed',
    'order.processing',
    'order.shipped',
    'order.delivered',
    'order.cancelled',
    'order.updated',
  ]),
  data: z.object({
    orderId: z.string().uuid(),
    customerId: z.string().uuid(),
    status: z.nativeEnum(OrderStatus).optional(),
    previousStatus: z.nativeEnum(OrderStatus).optional(),
  }),
});

export type OrderEvent = z.infer<typeof orderEventSchema>;

export const notificationEventSchema = baseEventSchema.extend({
  type: z.enum(['notification.email', 'notification.push', 'notification.sms']),
  data: z.object({
    recipientId: z.string().uuid(),
    recipientEmail: z.string().email().optional(),
    recipientPhone: z.string().optional(),
    subject: z.string().optional(),
    body: z.string(),
    templateId: z.string().optional(),
    templateData: z.record(z.unknown()).optional(),
  }),
});

export type NotificationEvent = z.infer<typeof notificationEventSchema>;

// =============================================================================
// SQS Message Types
// =============================================================================

export interface SQSMessageBody<T> {
  Message: string; // JSON stringified event
  MessageId: string;
  Type: 'Notification';
  TopicArn?: string;
  Timestamp: string;
  data?: T; // Parsed event data
}

// =============================================================================
// Health Check Types
// =============================================================================

export interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  region: string;
  regionKey: string;
  isPrimary: boolean;
  tier: string;
  timestamp: string;
  version: string;
  uptime: number;
  checks: {
    database: 'ok' | 'error';
    redis: 'ok' | 'error';
    sqs: 'ok' | 'error';
    sns: 'ok' | 'error';
  };
}

// =============================================================================
// Pagination Types
// =============================================================================

export const paginationSchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
  sortBy: z.string().optional(),
  sortOrder: z.enum(['asc', 'desc']).default('desc'),
});

export type PaginationInput = z.infer<typeof paginationSchema>;

export interface PaginatedResult<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
    hasNext: boolean;
    hasPrev: boolean;
  };
}

// Cursor-based pagination (preferred for DynamoDB)
export const cursorPaginationSchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().positive().max(100).default(20),
});

export type CursorPaginationInput = z.infer<typeof cursorPaginationSchema>;

export interface CursorPaginatedResult<T> {
  data: T[];
  pagination: {
    nextCursor: string | null;
    hasMore: boolean;
    limit: number;
  };
}
