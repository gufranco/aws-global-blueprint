# =============================================================================
# API Dockerfile
# =============================================================================
# Multi-stage build for production-ready Node.js API container
# =============================================================================

# Stage 1: Build
FROM node:20-alpine AS builder

# Install pnpm
RUN corepack enable && corepack prepare pnpm@8.15.0 --activate

WORKDIR /app

# Copy workspace files
COPY package.json pnpm-workspace.yaml ./
COPY app/package.json ./app/
COPY app/shared/package.json ./app/shared/
COPY app/api/package.json ./app/api/

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY app/shared ./app/shared
COPY app/api ./app/api

# Build shared library
RUN cd app/shared && pnpm build

# Build API
RUN cd app/api && pnpm build

# Stage 2: Production
FROM node:20-alpine AS production

# Install pnpm
RUN corepack enable && corepack prepare pnpm@8.15.0 --activate

# Add non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copy production dependencies
COPY --from=builder /app/package.json ./
COPY --from=builder /app/pnpm-workspace.yaml ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/app/shared/package.json ./app/shared/
COPY --from=builder /app/app/shared/dist ./app/shared/dist
COPY --from=builder /app/app/api/package.json ./app/api/
COPY --from=builder /app/app/api/dist ./app/api/dist

# Set ownership
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Set environment
ENV NODE_ENV=production
ENV PORT=3000

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Start the application
WORKDIR /app/app/api
CMD ["node", "dist/index.js"]
