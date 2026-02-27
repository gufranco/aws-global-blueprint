// =============================================================================
// Unit Tests - Input Validation Schemas
// =============================================================================

import { describe, it, expect } from 'vitest';
import {
  createOrderSchema,
  paginationSchema,
  orderEventSchema,
  notificationEventSchema,
} from '@blueprint/shared';

const VALID_UUID = '550e8400-e29b-41d4-a716-446655440000';
const VALID_UUID_2 = '550e8400-e29b-41d4-a716-446655440001';

describe('createOrderSchema', () => {
  const validInput = {
    customerId: VALID_UUID,
    items: [
      {
        productId: VALID_UUID_2,
        productName: 'Widget',
        quantity: 2,
        unitPrice: 10.0,
        totalPrice: 20.0,
      },
    ],
    shippingAddress: {
      street: '123 Main St',
      city: 'Springfield',
      state: 'IL',
      country: 'US',
      postalCode: '62704',
    },
  };

  it('should accept valid order input', () => {
    const result = createOrderSchema.safeParse(validInput);
    expect(result.success).toBe(true);
  });

  it('should reject non-UUID customerId', () => {
    const result = createOrderSchema.safeParse({
      ...validInput,
      customerId: 'not-a-uuid',
    });
    expect(result.success).toBe(false);
  });

  it('should reject empty items array', () => {
    const result = createOrderSchema.safeParse({
      ...validInput,
      items: [],
    });
    expect(result.success).toBe(false);
  });

  it('should reject negative quantity', () => {
    const result = createOrderSchema.safeParse({
      ...validInput,
      items: [{ ...validInput.items[0], quantity: -1 }],
    });
    expect(result.success).toBe(false);
  });

  it('should reject missing shipping address fields', () => {
    const result = createOrderSchema.safeParse({
      ...validInput,
      shippingAddress: { street: '123 Main' },
    });
    expect(result.success).toBe(false);
  });

  it('should reject country code longer than 2 chars', () => {
    const result = createOrderSchema.safeParse({
      ...validInput,
      shippingAddress: { ...validInput.shippingAddress, country: 'USA' },
    });
    expect(result.success).toBe(false);
  });

  it('should accept optional metadata', () => {
    const result = createOrderSchema.safeParse({
      ...validInput,
      metadata: { source: 'web', campaign: 'summer' },
    });
    expect(result.success).toBe(true);
  });

  it('should reject metadata with more than 50 keys', () => {
    const bigMetadata: Record<string, string> = {};
    for (let i = 0; i < 51; i++) {
      bigMetadata[`key${i}`] = 'value';
    }
    const result = createOrderSchema.safeParse({
      ...validInput,
      metadata: bigMetadata,
    });
    expect(result.success).toBe(false);
  });
});

describe('paginationSchema', () => {
  it('should provide defaults', () => {
    const result = paginationSchema.parse({});
    expect(result.page).toBe(1);
    expect(result.limit).toBe(20);
    expect(result.sortOrder).toBe('desc');
  });

  it('should coerce string numbers', () => {
    const result = paginationSchema.parse({ page: '3', limit: '50' });
    expect(result.page).toBe(3);
    expect(result.limit).toBe(50);
  });

  it('should reject limit over 100', () => {
    const result = paginationSchema.safeParse({ limit: 101 });
    expect(result.success).toBe(false);
  });

  it('should reject page zero', () => {
    const result = paginationSchema.safeParse({ page: 0 });
    expect(result.success).toBe(false);
  });
});

describe('orderEventSchema', () => {
  it('should accept valid order event', () => {
    const event = {
      id: VALID_UUID,
      type: 'order.created',
      timestamp: new Date().toISOString(),
      source: 'test-service',
      region: 'us-east-1',
      data: {
        orderId: VALID_UUID,
        customerId: VALID_UUID_2,
      },
    };
    const result = orderEventSchema.safeParse(event);
    expect(result.success).toBe(true);
  });

  it('should reject unknown event type', () => {
    const event = {
      id: VALID_UUID,
      type: 'order.unknown',
      timestamp: new Date().toISOString(),
      source: 'test',
      region: 'us-east-1',
      data: { orderId: VALID_UUID, customerId: VALID_UUID_2 },
    };
    const result = orderEventSchema.safeParse(event);
    expect(result.success).toBe(false);
  });
});

describe('notificationEventSchema', () => {
  it('should accept valid email notification', () => {
    const event = {
      id: VALID_UUID,
      type: 'notification.email',
      timestamp: new Date().toISOString(),
      source: 'test-service',
      region: 'us-east-1',
      data: {
        recipientId: VALID_UUID,
        recipientEmail: 'user@example.com',
        body: 'Hello',
        subject: 'Test',
      },
    };
    const result = notificationEventSchema.safeParse(event);
    expect(result.success).toBe(true);
  });

  it('should reject invalid email format', () => {
    const event = {
      id: VALID_UUID,
      type: 'notification.email',
      timestamp: new Date().toISOString(),
      source: 'test',
      region: 'us-east-1',
      data: {
        recipientId: VALID_UUID,
        recipientEmail: 'not-an-email',
        body: 'Hello',
      },
    };
    const result = notificationEventSchema.safeParse(event);
    expect(result.success).toBe(false);
  });
});
