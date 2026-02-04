// =============================================================================
// Shared Module - Main Export
// =============================================================================

export * from './config/index.js';
export * from './aws/index.js';
export * from './logger.js';
export * from './errors.js';
export * from './types.js';

// Re-export tracing (must be imported separately for setup)
export { initTracing, shutdownTracing } from './tracing/index.js';

// Re-export resilience patterns
export * from './resilience/circuit-breaker.js';
