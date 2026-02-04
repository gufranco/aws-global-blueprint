import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['**/*.test.ts'],
    testTimeout: 60000,
    hookTimeout: 60000,
    // Integration tests require longer timeouts for LocalStack
  },
});
