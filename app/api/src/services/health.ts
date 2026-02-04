// =============================================================================
// Health Check Services
// =============================================================================

import { Pool } from 'pg';
import Redis from 'ioredis';
import { config, getDatabaseUrl, createLogger } from '@multiregion/shared';

const logger = createLogger('health');

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

// Check database health
export async function checkDatabaseHealth(): Promise<boolean> {
  try {
    const pool = getDbPool();
    const result = await pool.query('SELECT 1');
    return result.rows.length > 0;
  } catch (error) {
    logger.error({ error }, 'Database health check failed');
    return false;
  }
}

// Check Redis health
export async function checkRedisHealth(): Promise<boolean> {
  try {
    const client = getRedisClient();
    const result = await client.ping();
    return result === 'PONG';
  } catch (error) {
    logger.error({ error }, 'Redis health check failed');
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
