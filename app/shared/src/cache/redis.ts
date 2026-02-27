// =============================================================================
// Redis Cache Client
// =============================================================================

import Redis, { type RedisOptions } from 'ioredis';
import { config } from '../config/index.js';
import { createLogger } from '../logger.js';

const logger = createLogger('redis-cache');

let redisClient: Redis | null = null;

export function getRedisClient(): Redis {
  if (redisClient) return redisClient;

  const options: RedisOptions = {
    host: config.REDIS_HOST,
    port: config.REDIS_PORT,
    maxRetriesPerRequest: 3,
    retryStrategy: (times: number) => {
      if (times > 5) return null;
      return Math.min(times * 200, 2000);
    },
    lazyConnect: true,
  };

  if (config.REDIS_PASSWORD) {
    options.password = config.REDIS_PASSWORD;
  }

  redisClient = new Redis(options);

  redisClient.on('error', (err) => {
    logger.warn({ err }, 'Redis connection error');
  });

  redisClient.on('connect', () => {
    logger.info('Redis connected');
  });

  return redisClient;
}

const DEFAULT_TTL_SECONDS = 300; // 5 minutes

export async function cacheGet<T>(key: string): Promise<T | null> {
  try {
    const client = getRedisClient();
    const data = await client.get(key);
    if (!data) return null;
    return JSON.parse(data) as T;
  } catch (error) {
    logger.warn({ error, key }, 'Cache get failed, falling through to origin');
    return null;
  }
}

export async function cacheSet(
  key: string,
  value: unknown,
  ttlSeconds: number = DEFAULT_TTL_SECONDS
): Promise<void> {
  try {
    const client = getRedisClient();
    // Add 0-10% jitter to prevent synchronized expiration stampedes
    const jitter = Math.floor(Math.random() * ttlSeconds * 0.1);
    await client.set(key, JSON.stringify(value), 'EX', ttlSeconds + jitter);
  } catch (error) {
    logger.warn({ error, key }, 'Cache set failed');
  }
}

export async function cacheDelete(key: string): Promise<void> {
  try {
    const client = getRedisClient();
    await client.del(key);
  } catch (error) {
    logger.warn({ error, key }, 'Cache delete failed');
  }
}

export async function cacheDeletePattern(pattern: string): Promise<void> {
  try {
    const client = getRedisClient();
    // Use SCAN instead of KEYS to avoid blocking Redis on large datasets
    let cursor = '0';
    do {
      const [nextCursor, keys] = await client.scan(cursor, 'MATCH', pattern, 'COUNT', 100);
      cursor = nextCursor;
      if (keys.length > 0) {
        await client.del(...keys);
      }
    } while (cursor !== '0');
  } catch (error) {
    logger.warn({ error, pattern }, 'Cache pattern delete failed');
  }
}

export async function disconnectRedis(): Promise<void> {
  if (redisClient) {
    await redisClient.quit();
    redisClient = null;
  }
}
