// =============================================================================
// API Entry Point
// =============================================================================

// Load environment variables before anything else
import 'dotenv/config';

import { config, createLogger } from '@multiregion/shared';
import { buildApp } from './app.js';

const logger = createLogger('api');

async function main() {
  const app = await buildApp();

  try {
    const address = await app.listen({
      port: config.PORT,
      host: '0.0.0.0',
    });

    logger.info(
      {
        address,
        region: config.AWS_REGION,
        regionKey: config.REGION_KEY,
        isPrimary: config.IS_PRIMARY_REGION,
        tier: config.REGION_TIER,
        env: config.NODE_ENV,
      },
      'API server started'
    );
  } catch (error) {
    logger.fatal({ error }, 'Failed to start server');
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});

// Unhandled errors
process.on('unhandledRejection', (reason) => {
  logger.error({ reason }, 'Unhandled rejection');
});

process.on('uncaughtException', (error) => {
  logger.fatal({ error }, 'Uncaught exception');
  process.exit(1);
});

main();
