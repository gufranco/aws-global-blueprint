# =============================================================================
# Worker Dockerfile
# =============================================================================
# Multi-stage build for production-ready Node.js Worker container
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
COPY app/worker/package.json ./app/worker/

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY app/shared ./app/shared
COPY app/worker ./app/worker

# Build shared library
RUN cd app/shared && pnpm build

# Build Worker
RUN cd app/worker && pnpm build

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
COPY --from=builder /app/app/worker/package.json ./app/worker/
COPY --from=builder /app/app/worker/dist ./app/worker/dist

# Set ownership
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Set environment
ENV NODE_ENV=production

# Start the worker
WORKDIR /app/app/worker
CMD ["node", "dist/index.js"]
