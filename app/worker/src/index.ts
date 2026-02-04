// =============================================================================
// Worker Entry Point
// =============================================================================

import { config, createLogger } from '@multiregion/shared';
import { WorkerManager } from './worker.js';

const logger = createLogger('worker');

async function main() {
  logger.info(
    {
      region: config.AWS_REGION,
      regionKey: config.REGION_KEY,
      isPrimary: config.IS_PRIMARY_REGION,
      tier: config.REGION_TIER,
      env: config.NODE_ENV,
    },
    'Starting worker'
  );

  const worker = new WorkerManager();

  // Start processing
  await worker.start();

  logger.info('Worker started successfully');
}

// Graceful shutdown
let isShuttingDown = false;

async function shutdown(signal: string) {
  if (isShuttingDown) return;
  isShuttingDown = true;

  logger.info({ signal }, 'Shutdown signal received');

  // Give in-flight messages time to complete
  await new Promise((resolve) => setTimeout(resolve, 5000));

  logger.info('Worker shutdown complete');
  process.exit(0);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('unhandledRejection', (reason) => {
  logger.error({ reason }, 'Unhandled rejection');
});

process.on('uncaughtException', (error) => {
  logger.fatal({ error }, 'Uncaught exception');
  process.exit(1);
});

main().catch((error) => {
  logger.fatal({ error }, 'Worker failed to start');
  process.exit(1);
});
