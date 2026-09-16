// Comprueba que el bundle de producción no engorda por encima del presupuesto
// (gzip). Pensado para correr tras `npm run build` (local o en CI).
import { readdirSync, readFileSync } from 'node:fs';
import { gzipSync } from 'node:zlib';

const PRESUPUESTO = { '.js': 26 * 1024, '.css': 4 * 1024 };

let ficheros;
try {
  ficheros = readdirSync('dist/assets');
} catch {
  console.error('No existe dist/: ejecuta `npm run build` antes.');
  process.exit(1);
}

const porExtension = { '.js': 0, '.css': 0 };
for (const fichero of ficheros) {
  const ext = fichero.slice(fichero.lastIndexOf('.'));
  if (!(ext in porExtension)) continue;
  porExtension[ext] += gzipSync(readFileSync(`dist/assets/${fichero}`), { level: 9 }).length;
}

let fallo = false;
for (const [ext, bytes] of Object.entries(porExtension)) {
  const kb = (bytes / 1024).toFixed(1);
  const max = (PRESUPUESTO[ext] / 1024).toFixed(0);
  const dentro = bytes <= PRESUPUESTO[ext];
  console.log(`${dentro ? '✓' : '✗'} ${ext}: ${kb} KB gzip (máx ${max} KB)`);
  if (!dentro) fallo = true;
}
process.exit(fallo ? 1 : 0);
