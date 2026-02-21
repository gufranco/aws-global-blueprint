// =============================================================================
// Health Check Services
// =============================================================================

import { Pool } from 'pg';
import Redis from 'ioredis';
import { config, getDatabaseUrl, createLogger } from '@multiregion/shared';

const logger = createLogger('health');

const HEALTH_CHECK_TIMEOUT_MS = 3000;

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) =>
      setTimeout(() => reject(new Error(`Health check timed out after ${ms}ms`)), ms)
    ),
  ]);
}

// Database connection pool
let dbPool: Pool | null = null;

function getDbPool(): Pool {
  if (!dbPool) {
    dbPool = new Pool({
      connectionString: getDatabaseUrl(),
      max: 5,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 5000,
    });
  }
  return dbPool;
}

// Redis client
let redisClient: Redis | null = null;

function getRedisClient(): Redis {
  if (!redisClient) {
    redisClient = new Redis({
      host: config.REDIS_HOST,
      port: config.REDIS_PORT,
      password: config.REDIS_PASSWORD ?? undefined,
      maxRetriesPerRequest: 3,
      retryStrategy: (times) => {
        if (times > 3) return null;
        return Math.min(times * 100, 3000);
      },
    });
  }
  return redisClient;
}

// Check database health with timeout
export async function checkDatabaseHealth(): Promise<boolean> {
  try {
    const pool = getDbPool();
    const result = await withTimeout(pool.query('SELECT 1'), HEALTH_CHECK_TIMEOUT_MS);
    return result.rows.length > 0;
  } catch (error) {
    logger.error({ error }, 'Database health check failed');
    dbPool = null;
    return false;
  }
}

// Check Redis health with timeout
export async function checkRedisHealth(): Promise<boolean> {
  try {
    const client = getRedisClient();
    const result = await withTimeout(client.ping(), HEALTH_CHECK_TIMEOUT_MS);
    return result === 'PONG';
  } catch (error) {
    logger.error({ error }, 'Redis health check failed');
    redisClient = null;
    return false;
  }
}

// Cleanup connections on shutdown
export async function cleanupConnections(): Promise<void> {
  if (dbPool) {
    await dbPool.end();
    dbPool = null;
  }
  if (redisClient) {
    redisClient.disconnect();
    redisClient = null;
  }
}
