import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  resolve: {
    alias: {
      '@blueprint/shared': path.resolve(__dirname, 'shared/dist/index.js'),
    },
  },
  test: {
    globals: true,
    environment: 'node',
    passWithNoTests: true,
    env: {
      NODE_ENV: 'development',
    },
    include: ['**/*.test.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov', 'html'],
      include: ['**/src/**/*.ts'],
      exclude: ['**/node_modules/**', '**/dist/**', '**/*.test.ts'],
    },
    testTimeout: 30000,
    hookTimeout: 30000,
  },
});
