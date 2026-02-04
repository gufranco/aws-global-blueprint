// =============================================================================
// Logger
// =============================================================================

import pino from 'pino';
import { config } from './config/index.js';

const transport = config.NODE_ENV === 'development'
  ? {
      target: 'pino-pretty',
      options: {
        colorize: true,
        translateTime: 'SYS:standard',
      },
    }
  : undefined;

export const logger = pino({
  level: config.NODE_ENV === 'production' ? 'info' : 'debug',
  ...(transport && { transport }),
  base: {
    region: config.AWS_REGION,
    regionKey: config.REGION_KEY,
    isPrimary: config.IS_PRIMARY_REGION,
    tier: config.REGION_TIER,
    service: config.OTEL_SERVICE_NAME,
  },
  formatters: {
    level: (label) => ({ level: label }),
  },
});

export function createLogger(name: string) {
  return logger.child({ module: name });
}
