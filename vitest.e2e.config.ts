import { defineConfig } from 'vitest/config';

/**
 * Configuración de los tests E2E (Puppeteer + Chrome headless).
 *
 * Se separa de `vite.config.ts` a propósito: `npm test` debe seguir corriendo
 * solo tests unitarios, sin abrir navegador. Aquí no se mide cobertura (la
 * recoge el proceso de Node, no el navegador).
 */
export default defineConfig({
  test: {
    environment: 'node',
    include: ['tests/e2e/**/*.e2e.ts'],
    testTimeout: 60_000,
    hookTimeout: 120_000,
    // Un navegador por archivo y sin solaparse: comparten CPU y puertos.
    fileParallelism: false,
  },
});
