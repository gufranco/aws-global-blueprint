import { describe, it, expect, vi, beforeEach } from 'vitest';
import { faker } from '@faker-js/faker';

const mockConfig = vi.hoisted(() => ({
  API_KEY: '' as string,
  NODE_ENV: 'development' as const,
}));

vi.mock('@blueprint/shared', async () => {
  const actual = await vi.importActual<typeof import('@blueprint/shared')>('@blueprint/shared');
  return {
    ...actual,
    config: mockConfig,
  };
});

import { authMiddleware } from '../../api/src/middleware/auth.js';
import { UnauthorizedError } from '@blueprint/shared';

function createRequest(url: string, headers: Record<string, string | undefined> = {}) {
  return { url, headers } as Parameters<typeof authMiddleware>[0];
}

function createReply() {
  return {} as Parameters<typeof authMiddleware>[1];
}

describe('authMiddleware', () => {
  beforeEach(() => {
    mockConfig.API_KEY = '';
  });

  it('should skip auth for health endpoints', async () => {
    // Arrange
    mockConfig.API_KEY = faker.string.alphanumeric(32);
    const request = createRequest('/health/live');

    // Act & Assert
    await expect(authMiddleware(request, createReply())).resolves.toBeUndefined();
  });

  it('should skip auth for docs endpoints', async () => {
    // Arrange
    mockConfig.API_KEY = faker.string.alphanumeric(32);
    const request = createRequest('/docs');

    // Act & Assert
    await expect(authMiddleware(request, createReply())).resolves.toBeUndefined();
  });

  it('should skip auth when no API_KEY is configured', async () => {
    // Arrange
    mockConfig.API_KEY = '';
    const request = createRequest('/v1/orders');

    // Act & Assert
    await expect(authMiddleware(request, createReply())).resolves.toBeUndefined();
  });

  it('should reject request with missing API key', async () => {
    // Arrange
    mockConfig.API_KEY = faker.string.alphanumeric(32);
    const request = createRequest('/v1/orders');

    // Act & Assert
    await expect(authMiddleware(request, createReply())).rejects.toThrow(UnauthorizedError);
  });

  it('should reject request with wrong API key', async () => {
    // Arrange
    mockConfig.API_KEY = faker.string.alphanumeric(32);
    const request = createRequest('/v1/orders', {
      'x-api-key': faker.string.alphanumeric(32),
    });

    // Act & Assert
    await expect(authMiddleware(request, createReply())).rejects.toThrow(UnauthorizedError);
  });

  it('should accept request with correct x-api-key header', async () => {
    // Arrange
    const apiKey = faker.string.alphanumeric(32);
    mockConfig.API_KEY = apiKey;
    const request = createRequest('/v1/orders', { 'x-api-key': apiKey });

    // Act & Assert
    await expect(authMiddleware(request, createReply())).resolves.toBeUndefined();
  });

  it('should accept request with correct Bearer token', async () => {
    // Arrange
    const apiKey = faker.string.alphanumeric(32);
    mockConfig.API_KEY = apiKey;
    const request = createRequest('/v1/orders', {
      authorization: `Bearer ${apiKey}`,
    });

    // Act & Assert
    await expect(authMiddleware(request, createReply())).resolves.toBeUndefined();
  });

  it('should prefer x-api-key over authorization header', async () => {
    // Arrange
    const apiKey = faker.string.alphanumeric(32);
    mockConfig.API_KEY = apiKey;
    const request = createRequest('/v1/orders', {
      'x-api-key': apiKey,
      authorization: `Bearer ${faker.string.alphanumeric(32)}`,
    });

    // Act & Assert
    await expect(authMiddleware(request, createReply())).resolves.toBeUndefined();
  });
});
