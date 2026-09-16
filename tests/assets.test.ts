import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { Assets } from '../src/render/Assets';

/**
 * Contratos de activos: lo declarado (sprites, sonidos) debe existir en disco y
 * no debe haber huérfanos; las fuentes y los recursos locales referidos por el
 * HTML/CSS deben resolverse a ficheros reales.
 */

function nombres(dir: string, extension: string): string[] {
  return readdirSync(dir)
    .filter((f) => f.endsWith(extension))
    .map((f) => f.slice(0, -extension.length));
}

describe('contratos · activos', () => {
  it('cada sprite declarado tiene su PNG, sin huérfanos', () => {
    const declarados = [...Assets.spriteNames()].sort();
    const enDisco = nombres('public/sprites', '.png').sort();
    expect(enDisco).toEqual(declarados);
  });

  it('cada sonido declarado tiene su WAV, sin huérfanos', () => {
    const declarados = [...Assets.audioNames()].sort();
    const enDisco = nombres('public/audio', '.wav').sort();
    expect(enDisco).toEqual(declarados);
  });

  it('las fuentes referidas por el CSS existen', () => {
    const css = readFileSync('src/styles/main.css', 'utf8');
    const urls = [...css.matchAll(/url\(['"]?([^'")]+)['"]?\)/g)].map((m) => m[1]);
    const fuentes = urls.filter((u) => u.endsWith('.ttf') || u.endsWith('.woff2'));
    expect(fuentes.length).toBeGreaterThan(0);
    for (const url of fuentes) {
      const ruta = `public/${url.replace(/^\//, '')}`;
      expect(existsSync(ruta), `falta ${ruta}`).toBe(true);
    }
  });

  it('los recursos locales de index.html existen', () => {
    const html = readFileSync('index.html', 'utf8');
    const refs = [...html.matchAll(/(?:src|href)="([^"]+)"/g)].map((m) => m[1]);
    const locales = refs.filter((r) => !/^(https?:|data:|#)/.test(r));
    expect(locales.length).toBeGreaterThan(0);
    for (const ref of locales) {
      const ruta = ref.replace(/^\.\//, '');
      // Los recursos servidos en la raíz viven en `public/`; el resto, en el repo.
      const existe = existsSync(ruta) || existsSync(`public/${ruta}`);
      expect(existe, `falta ${ruta}`).toBe(true);
    }
  });
});
