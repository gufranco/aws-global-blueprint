import { describe, it, expect, vi, afterEach } from 'vitest';
import { faker } from '@faker-js/faker';

describe('config validation', () => {
  afterEach(() => {
    vi.unstubAllEnvs();
    vi.resetModules();
  });

  it('should reject empty API_KEY string', async () => {
    // Arrange
    vi.stubEnv('API_KEY', '');
    vi.stubEnv('NODE_ENV', 'production');

    // Act & Assert
    // Empty string fails .min(1) validation for API_KEY
    await expect(async () => {
      await import('../../shared/src/config/index.js');
    }).rejects.toThrow();
  });

  it('should reject USE_LOCALSTACK in production', async () => {
    // Arrange
    vi.stubEnv('NODE_ENV', 'production');
    vi.stubEnv('USE_LOCALSTACK', 'true');
    vi.stubEnv('API_KEY', faker.string.alphanumeric(32));

    // Act & Assert
    await expect(async () => {
      await import('../../shared/src/config/index.js');
    }).rejects.toThrow('USE_LOCALSTACK must not be enabled in production');
  });

  it('should require API_KEY in production', async () => {
    // Arrange
    vi.stubEnv('NODE_ENV', 'production');
    vi.stubEnv('USE_LOCALSTACK', '');
    // API_KEY must be absent (undefined), not empty string.
    // Empty string fails Zod .min(1) before reaching the runtime check.
    delete process.env.API_KEY;

    // Act & Assert
    await expect(async () => {
      await import('../../shared/src/config/index.js');
    }).rejects.toThrow('API_KEY must be configured in production');
  });

  it('should accept valid development config with defaults', async () => {
    // Arrange
    vi.stubEnv('NODE_ENV', 'development');

    // Act
    const { config } = await import('../../shared/src/config/index.js');

    // Assert
    expect(config.NODE_ENV).toBe('development');
    expect(config.PORT).toBe(3000);
    expect(config.AWS_REGION).toBe('us-east-1');
  });
});
