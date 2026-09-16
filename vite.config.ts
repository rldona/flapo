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
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],
      reportsDirectory: 'coverage',
      include: ['src/**/*.ts'],
      exclude: ['src/main.ts', 'src/**/*.d.ts'],
      all: true,
      reportOnFailure: true,
      // Ratchet: baseline medida (61.09 / 81.46 / 73.03 / 61.09) menos ~3 puntos.
      // CI falla si alguien baja la cobertura por debajo de estos valores.
      thresholds: {
        statements: 58,
        branches: 78,
        functions: 70,
        lines: 58,
      },
    },
  },
});
