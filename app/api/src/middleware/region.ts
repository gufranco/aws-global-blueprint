// =============================================================================
// Region Middleware
// =============================================================================

import type { FastifyRequest, FastifyReply } from 'fastify';
import { config, ReadOnlyError } from '@multiregion/shared';

// Extend FastifyRequest to include region info
declare module 'fastify' {
  interface FastifyRequest {
    region: {
      awsRegion: string;
      regionKey: string;
      isPrimary: boolean;
      tier: string;
      isReadOnly: boolean;
    };
  }
}

// Methods that require write access
const WRITE_METHODS = ['POST', 'PUT', 'PATCH', 'DELETE'];

export async function regionMiddleware(
  request: FastifyRequest,
  _reply: FastifyReply
): Promise<void> {
  // Attach region info to request
  request.region = {
    awsRegion: config.AWS_REGION,
    regionKey: config.REGION_KEY,
    isPrimary: config.IS_PRIMARY_REGION,
    tier: config.REGION_TIER,
    isReadOnly: !config.IS_PRIMARY_REGION,
  };

  // Block write operations in read-only replica regions
  // Exception: health checks and other safe endpoints
  const isWriteMethod = WRITE_METHODS.includes(request.method);
  const isReadOnlyRegion = !config.IS_PRIMARY_REGION;
  const isSafeEndpoint =
    request.url.startsWith('/health') ||
    request.url.startsWith('/docs') ||
    request.url.startsWith('/metrics');

  if (isWriteMethod && isReadOnlyRegion && !isSafeEndpoint) {
    throw new ReadOnlyError();
  }
}
