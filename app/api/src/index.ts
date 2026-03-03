// =============================================================================
// API Entry Point
// =============================================================================

// Load environment variables before anything else
import 'dotenv/config';

import { config, createLogger } from '@blueprint/shared';
import { buildApp } from './app.js';

const logger = createLogger('api');

let app: Awaited<ReturnType<typeof buildApp>> | undefined;

async function main() {
  app = await buildApp();

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
      'API server started',
    );
  } catch (error) {
    logger.fatal({ error }, 'Failed to start server');
    process.exit(1);
  }
}

// Graceful shutdown
let isShuttingDown = false;

async function shutdown(signal: string) {
  if (isShuttingDown) return;
  isShuttingDown = true;

  logger.info({ signal }, 'Shutdown signal received');

  try {
    if (app) {
      await app.close();
    }
    logger.info('Server closed, exiting');
    process.exit(0);
  } catch (error) {
    logger.error({ error }, 'Error during shutdown');
    process.exit(1);
  }
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Unhandled errors
process.on('unhandledRejection', (reason) => {
  logger.error({ reason }, 'Unhandled rejection');
});

process.on('uncaughtException', (error) => {
  logger.fatal({ error }, 'Uncaught exception');
  process.exit(1);
});

main();
