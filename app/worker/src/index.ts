// =============================================================================
// Worker Entry Point
// =============================================================================

import { config, createLogger } from '@blueprint/shared';
import { WorkerManager } from './worker.js';

const logger = createLogger('worker');

let worker: WorkerManager | undefined;

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

  worker = new WorkerManager();

  // Start processing
  await worker.start();

  logger.info('Worker started successfully');
}

// Graceful shutdown
let isShuttingDown = false;

const GRACEFUL_TIMEOUT_MS = 5000;
const HARD_TIMEOUT_MS = 10000;

async function shutdown(signal: string) {
  if (isShuttingDown) return;
  isShuttingDown = true;

  logger.info({ signal }, 'Shutdown signal received');

  // Hard timeout: force exit if graceful shutdown takes too long
  const hardTimer = setTimeout(() => {
    logger.error('Hard shutdown timeout reached, forcing exit');
    process.exit(1);
  }, HARD_TIMEOUT_MS);
  hardTimer.unref();

  // Stop accepting new messages, then wait for in-flight to finish
  if (worker) {
    await worker.stop();
  }
  await new Promise((resolve) => setTimeout(resolve, GRACEFUL_TIMEOUT_MS));

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
