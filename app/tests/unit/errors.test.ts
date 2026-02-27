// =============================================================================
// Unit Tests - Error Classification
// =============================================================================

import { describe, it, expect } from 'vitest';
import {
  isTransient,
  TransientError,
  PermanentError,
  ValidationError,
  NotFoundError,
  UnauthorizedError,
  AppError,
} from '@blueprint/shared';

describe('Error Classification', () => {
  describe('isTransient', () => {
    it('should classify TransientError as transient', () => {
      // Arrange
      const error = new TransientError('temporary issue');

      // Act
      const result = isTransient(error);

      // Assert
      expect(result).toBe(true);
    });

    it('should classify PermanentError as not transient', () => {
      // Arrange
      const error = new PermanentError('bad request');

      // Act
      const result = isTransient(error);

      // Assert
      expect(result).toBe(false);
    });

    it('should classify ValidationError as not transient', () => {
      // Arrange
      const error = new ValidationError('invalid input');

      // Act
      const result = isTransient(error);

      // Assert
      expect(result).toBe(false);
    });

    it('should classify NotFoundError as not transient', () => {
      // Arrange
      const error = new NotFoundError('Order', '123');

      // Act
      const result = isTransient(error);

      // Assert
      expect(result).toBe(false);
    });

    it('should classify UnauthorizedError as not transient', () => {
      // Arrange
      const error = new UnauthorizedError();

      // Act
      const result = isTransient(error);

      // Assert
      expect(result).toBe(false);
    });

    it('should classify AWS ThrottlingException as transient', () => {
      // Arrange
      const error = new Error('Rate exceeded');
      error.name = 'ThrottlingException';

      // Act
      const result = isTransient(error);

      // Assert
      expect(result).toBe(true);
    });

    it('should classify ProvisionedThroughputExceededException as transient', () => {
      // Arrange
      const error = new Error('Throughput exceeded');
      error.name = 'ProvisionedThroughputExceededException';

      // Act
      const result = isTransient(error);

      // Assert
      expect(result).toBe(true);
    });

    it('should classify ECONNRESET as transient', () => {
      // Arrange
      const error = new Error('Connection reset');
      (error as NodeJS.ErrnoException).code = 'ECONNRESET';

      // Act
      const result = isTransient(error);

      // Assert
      expect(result).toBe(true);
    });

    it('should classify ETIMEDOUT as transient', () => {
      // Arrange
      const error = new Error('Timed out');
      (error as NodeJS.ErrnoException).code = 'ETIMEDOUT';

      // Act
      const result = isTransient(error);

      // Assert
      expect(result).toBe(true);
    });

    it('should classify HTTP 429 as transient', () => {
      // Arrange
      const error = Object.assign(new Error('Too Many Requests'), {
        $metadata: { httpStatusCode: 429 },
      });

      // Act
      const result = isTransient(error);

      // Assert
      expect(result).toBe(true);
    });

    it('should classify HTTP 503 as transient', () => {
      // Arrange
      const error = Object.assign(new Error('Service Unavailable'), {
        $metadata: { httpStatusCode: 503 },
      });

      // Act
      const result = isTransient(error);

      // Assert
      expect(result).toBe(true);
    });

    it('should classify unknown errors as not transient by default', () => {
      // Arrange
      const error = new Error('Something unexpected');

      // Act
      const result = isTransient(error);

      // Assert
      expect(result).toBe(false);
    });

    it('should classify non-Error values as not transient', () => {
      // Act & Assert
      expect(isTransient('string error')).toBe(false);
      expect(isTransient(null)).toBe(false);
      expect(isTransient(undefined)).toBe(false);
      expect(isTransient(42)).toBe(false);
    });
  });

  describe('TransientError', () => {
    it('should have status code 503', () => {
      const error = new TransientError('service down');
      expect(error.statusCode).toBe(503);
      expect(error.code).toBe('TRANSIENT_ERROR');
    });

    it('should include details', () => {
      const error = new TransientError('service down', { service: 'dynamo' });
      expect(error.details).toEqual({ service: 'dynamo' });
    });
  });

  describe('PermanentError', () => {
    it('should have configurable status code', () => {
      const error = new PermanentError('bad input', 422);
      expect(error.statusCode).toBe(422);
      expect(error.code).toBe('PERMANENT_ERROR');
    });

    it('should default to 400', () => {
      const error = new PermanentError('bad request');
      expect(error.statusCode).toBe(400);
    });
  });
});

describe('AppError', () => {
  it('should serialize to JSON with error envelope', () => {
    // Arrange
    const error = new AppError('something broke', 'BROKEN', 500, { key: 'value' });

    // Act
    const json = error.toJSON();

    // Assert
    expect(json).toEqual({
      error: {
        code: 'BROKEN',
        message: 'something broke',
        details: { key: 'value' },
      },
    });
  });
});
