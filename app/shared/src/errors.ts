// =============================================================================
// Custom Errors
// =============================================================================

export class AppError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: number = 500,
    public readonly details?: Record<string, unknown>
  ) {
    super(message);
    this.name = 'AppError';
    Error.captureStackTrace(this, this.constructor);
  }

  toJSON() {
    return {
      error: {
        code: this.code,
        message: this.message,
        details: this.details,
      },
    };
  }
}

export class ValidationError extends AppError {
  constructor(message: string, details?: Record<string, unknown>) {
    super(message, 'VALIDATION_ERROR', 400, details);
    this.name = 'ValidationError';
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string, id?: string) {
    super(
      id ? `${resource} with id '${id}' not found` : `${resource} not found`,
      'NOT_FOUND',
      404,
      { resource, id }
    );
    this.name = 'NotFoundError';
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized') {
    super(message, 'UNAUTHORIZED', 401);
    this.name = 'UnauthorizedError';
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Forbidden') {
    super(message, 'FORBIDDEN', 403);
    this.name = 'ForbiddenError';
  }
}

export class ConflictError extends AppError {
  constructor(message: string, details?: Record<string, unknown>) {
    super(message, 'CONFLICT', 409, details);
    this.name = 'ConflictError';
  }
}

export class ReadOnlyError extends AppError {
  constructor() {
    super(
      'Write operations are not allowed in read-only replica regions',
      'READ_ONLY_REGION',
      403
    );
    this.name = 'ReadOnlyError';
  }
}

export class ServiceUnavailableError extends AppError {
  constructor(service: string) {
    super(`Service '${service}' is temporarily unavailable`, 'SERVICE_UNAVAILABLE', 503, {
      service,
    });
    this.name = 'ServiceUnavailableError';
  }
}

export function isAppError(error: unknown): error is AppError {
  return error instanceof AppError;
}

// =============================================================================
// Error Classification
// =============================================================================

export class TransientError extends AppError {
  constructor(message: string, details?: Record<string, unknown>) {
    super(message, 'TRANSIENT_ERROR', 503, details);
    this.name = 'TransientError';
  }
}

export class PermanentError extends AppError {
  constructor(message: string, statusCode = 400, details?: Record<string, unknown>) {
    super(message, 'PERMANENT_ERROR', statusCode, details);
    this.name = 'PermanentError';
  }
}

const TRANSIENT_ERROR_CODES = new Set([
  'ThrottlingException',
  'ProvisionedThroughputExceededException',
  'RequestLimitExceeded',
  'TooManyRequestsException',
  'ServiceUnavailable',
  'InternalServerError',
  'ECONNRESET',
  'ECONNREFUSED',
  'ETIMEDOUT',
  'EPIPE',
  'EAI_AGAIN',
]);

const TRANSIENT_STATUS_CODES = new Set([408, 429, 500, 502, 503, 504]);

export function isTransient(error: unknown): boolean {
  if (error instanceof TransientError) return true;
  if (error instanceof PermanentError) return false;
  if (error instanceof ValidationError) return false;
  if (error instanceof NotFoundError) return false;
  if (error instanceof UnauthorizedError) return false;
  if (error instanceof ForbiddenError) return false;

  if (error instanceof Error) {
    const name = (error as { name?: string }).name ?? '';
    if (TRANSIENT_ERROR_CODES.has(name)) return true;

    const statusCode = (error as { $metadata?: { httpStatusCode?: number } }).$metadata
      ?.httpStatusCode;
    if (statusCode && TRANSIENT_STATUS_CODES.has(statusCode)) return true;

    const code = (error as { code?: string }).code;
    if (code && TRANSIENT_ERROR_CODES.has(code)) return true;
  }

  return false;
}
