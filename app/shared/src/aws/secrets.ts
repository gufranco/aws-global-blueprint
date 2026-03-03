// =============================================================================
// Secrets Manager Client
// =============================================================================

import {
  SecretsManagerClient,
  GetSecretValueCommand,
  type GetSecretValueCommandInput,
} from '@aws-sdk/client-secrets-manager';
import { config, getAwsEndpoint } from '../config/index.js';
import { createLogger } from '../logger.js';

const logger = createLogger('secrets');

// Create Secrets Manager client
const endpoint = getAwsEndpoint();
export const secretsClient = new SecretsManagerClient({
  region: config.AWS_REGION,
  ...(endpoint && { endpoint }),
  ...(config.USE_LOCALSTACK && {
    credentials: {
      accessKeyId: 'test',
      secretAccessKey: 'test',
    },
  }),
});

// Cache for secrets
const secretsCache = new Map<string, { value: string; expiresAt: number }>();
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

// Get secret value
export async function getSecret(secretId: string, useCache = true): Promise<string> {
  // Check cache
  if (useCache) {
    const cached = secretsCache.get(secretId);
    if (cached && cached.expiresAt > Date.now()) {
      logger.debug({ secretId }, 'Secret retrieved from cache');
      return cached.value;
    }
  }

  const input: GetSecretValueCommandInput = {
    SecretId: secretId,
  };

  const command = new GetSecretValueCommand(input);
  const response = await secretsClient.send(command);

  const value = response.SecretString;
  if (!value) {
    throw new Error(`Secret ${secretId} has no string value`);
  }

  // Update cache
  secretsCache.set(secretId, {
    value,
    expiresAt: Date.now() + CACHE_TTL_MS,
  });

  logger.debug({ secretId }, 'Secret retrieved from Secrets Manager');
  return value;
}

// Get secret as JSON
export async function getSecretJson<T = Record<string, unknown>>(
  secretId: string,
  useCache = true,
): Promise<T> {
  const value = await getSecret(secretId, useCache);
  return JSON.parse(value) as T;
}

// Clear secrets cache
export function clearSecretsCache(): void {
  secretsCache.clear();
  logger.info('Secrets cache cleared');
}

// Database credentials type
export interface DatabaseCredentials {
  username: string;
  password: string;
  host: string;
  port: number;
  dbname: string;
  engine?: string;
}

// Get database credentials
export async function getDatabaseCredentials(secretId: string): Promise<DatabaseCredentials> {
  return getSecretJson<DatabaseCredentials>(secretId);
}
