# =============================================================================
# API Dockerfile
# =============================================================================
# Multi-stage build for production-ready Node.js API container
# Build context: app/ (the workspace root)
# =============================================================================

# Stage 1: Build
FROM ghcr.io/pnpm/pnpm:12.18.0-alpine AS pnpm

FROM node:26-alpine AS builder

COPY --from=pnpm /opt/pnpm /opt/pnpm
RUN for bin in pnpm pn pnpx pnx; do ln -s "/opt/pnpm/$bin" "/usr/local/bin/$bin"; done

WORKDIR /app

# Copy workspace files
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml ./
COPY shared/package.json ./shared/
COPY api/package.json ./api/

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY shared ./shared
COPY api ./api

# Build shared library first, then API
RUN pnpm --dir shared build && pnpm --dir api build

# Stage 2: Production
FROM node:26-alpine AS production

# Install tini for proper PID 1 signal handling
RUN apk add --no-cache tini=0.19.0-r3

# Add non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copy workspace config and dependencies
COPY --from=builder /app/package.json ./
COPY --from=builder /app/pnpm-workspace.yaml ./
COPY --from=builder /app/node_modules ./node_modules

# Copy shared library build output
COPY --from=builder /app/shared/package.json ./shared/
COPY --from=builder /app/shared/dist ./shared/dist
COPY --from=builder /app/shared/node_modules ./shared/node_modules

# Copy API build output
COPY --from=builder /app/api/package.json ./api/
COPY --from=builder /app/api/dist ./api/dist
COPY --from=builder /app/api/node_modules ./api/node_modules

# Set ownership
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER 1001:1001

# Set environment
ENV NODE_ENV=production
ENV PORT=3000

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["/bin/sh", "-c", "wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1"]

# Use tini as PID 1 for proper signal forwarding
ENTRYPOINT ["/sbin/tini", "--"]

# Start the application
WORKDIR /app/api
CMD ["node", "dist/index.js"]
