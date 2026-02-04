// =============================================================================
// Fastify Application
// =============================================================================

import Fastify, { type FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import { config, logger as baseLogger, isAppError } from '@multiregion/shared';

import { healthRoutes } from './routes/health.js';
import { orderRoutes } from './routes/orders.js';
import { regionMiddleware } from './middleware/region.js';

export async function buildApp(): Promise<FastifyInstance> {
  const app = Fastify({
    logger: {
      level: config.NODE_ENV === 'production' ? 'info' : 'debug',
      ...(config.NODE_ENV === 'development' && {
        transport: {
          target: 'pino-pretty',
          options: {
            colorize: true,
            translateTime: 'SYS:standard',
          },
        },
      }),
    },
    trustProxy: true,
    requestIdHeader: 'x-request-id',
    requestIdLogLabel: 'requestId',
  });

  // ==========================================================================
  // Plugins
  // ==========================================================================

  // CORS
  await app.register(cors, {
    origin: true,
    credentials: true,
  });

  // Security headers
  await app.register(helmet, {
    contentSecurityPolicy: false,
  });

  // Rate limiting
  await app.register(rateLimit, {
    max: 100,
    timeWindow: '1 minute',
    keyGenerator: (request) => {
      return request.headers['x-forwarded-for']?.toString() ?? request.ip;
    },
  });

  // OpenAPI documentation
  await app.register(swagger, {
    openapi: {
      info: {
        title: 'Multi-Region API',
        description: 'Production-grade multi-region API with ECS Fargate',
        version: '1.0.0',
      },
      servers: [
        {
          url: `http://localhost:${config.PORT}`,
          description: 'Local development',
        },
        {
          url: 'https://api.example.com',
          description: 'Production (via Global Accelerator)',
        },
      ],
      tags: [
        { name: 'Health', description: 'Health check endpoints' },
        { name: 'Orders', description: 'Order management' },
      ],
    },
  });

  await app.register(swaggerUi, {
    routePrefix: '/docs',
    uiConfig: {
      docExpansion: 'list',
      deepLinking: true,
    },
  });

  // ==========================================================================
  // Middleware
  // ==========================================================================

  // Add region info to all requests
  app.addHook('preHandler', regionMiddleware);

  // ==========================================================================
  // Routes
  // ==========================================================================

  await app.register(healthRoutes, { prefix: '' });
  await app.register(orderRoutes, { prefix: '/api/orders' });

  // ==========================================================================
  // Error Handler
  // ==========================================================================

  app.setErrorHandler((error, request, reply) => {
    request.log.error({ error }, 'Request error');

    if (isAppError(error)) {
      return reply.status(error.statusCode).send(error.toJSON());
    }

    // Fastify validation errors
    if (error.validation) {
      return reply.status(400).send({
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid request',
          details: error.validation,
        },
      });
    }

    // Generic error
    return reply.status(500).send({
      error: {
        code: 'INTERNAL_ERROR',
        message: config.NODE_ENV === 'production' ? 'Internal server error' : error.message,
      },
    });
  });

  // ==========================================================================
  // Not Found Handler
  // ==========================================================================

  app.setNotFoundHandler((request, reply) => {
    return reply.status(404).send({
      error: {
        code: 'NOT_FOUND',
        message: `Route ${request.method} ${request.url} not found`,
      },
    });
  });

  return app;
}
