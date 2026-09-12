import { defineConfig } from 'vitest/config';

export default defineConfig({
  base: './',
  server: {
    host: true,
    port: 5180,
    strictPort: true,
  },
  build: {
    target: 'es2022',
    assetsInlineLimit: 0,
    sourcemap: false,
  },
  test: {
    environment: 'node',
    include: ['tests/**/*.test.ts'],
  },
});
