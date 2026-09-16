import { describe, expect, it } from 'vitest';
import { Rng } from '../src/core/Rng';
import { circleRectOverlap, rectsOverlap, type Rect } from '../src/core/types';

/**
 * Tests de detalle para matar mutantes en las utilidades geométricas y en el
 * generador determinista. Cada caso está pensado para que una única condición
 * o término cambie el resultado.
 */

describe('rectsOverlap', () => {
  const a: Rect = { x: 0, y: 0, w: 10, h: 10 };

  it('detecta solape real y es simétrico', () => {
    const b: Rect = { x: 5, y: 5, w: 10, h: 10 };
    expect(rectsOverlap(a, b)).toBe(true);
    expect(rectsOverlap(b, a)).toBe(true);
  });

  it('el borde pegado no cuenta como solape', () => {
    expect(rectsOverlap(a, { x: 10, y: 0, w: 10, h: 10 })).toBe(false);
    expect(rectsOverlap(a, { x: -10, y: 0, w: 10, h: 10 })).toBe(false);
    expect(rectsOverlap(a, { x: 0, y: 10, w: 10, h: 10 })).toBe(false);
    expect(rectsOverlap(a, { x: 0, y: -10, w: 10, h: 10 })).toBe(false);
  });

  it('cada condición puede ser la única que falla', () => {
    // Sólo falla a.x < b.x + b.w
    expect(rectsOverlap(a, { x: -5, y: -5, w: 5, h: 20 })).toBe(false);
    // Sólo falla a.x + a.w > b.x
    expect(rectsOverlap(a, { x: 10, y: -5, w: 5, h: 20 })).toBe(false);
    // Sólo falla a.y < b.y + b.h
    expect(rectsOverlap(a, { x: -5, y: 5, w: 20, h: -5 })).toBe(false);
    // Sólo falla a.y + a.h > b.y
    expect(rectsOverlap(a, { x: -5, y: 10, w: 20, h: 0 })).toBe(false);
  });
});

describe('circleRectOverlap', () => {
  it('un círculo dentro del rect solapa', () => {
    expect(circleRectOverlap(5, 5, 1, 0, 0, 10, 10)).toBe(true);
  });

  it('un círculo lejos no solapa', () => {
    expect(circleRectOverlap(50, 50, 1, 0, 0, 10, 10)).toBe(false);
  });

  it('tocar exactamente el borde cuenta como solape', () => {
    // Punto más cercano (10, 5): distancia 5 === radio 5
    expect(circleRectOverlap(15, 5, 5, 0, 0, 10, 10)).toBe(true);
  });

  it('justo pasado el radio, no solapa', () => {
    expect(circleRectOverlap(15.5, 5, 5, 0, 0, 10, 10)).toBe(false);
  });

  it('usa los bordes rx+rw y ry+rh en las esquinas', () => {
    expect(circleRectOverlap(9, 9, 1, 0, 0, 10, 10)).toBe(true);
    expect(circleRectOverlap(12, 12, 2, 0, 0, 10, 10)).toBe(false);
  });
});

describe('Rng: semilla y normalización', () => {
  it('normaliza a uint32 y 0 usa la constante por defecto', () => {
    const r = new Rng(42);
    expect(r.seed).toBe(42);
    expect(typeof r.seed).toBe('number');
    r.seed = 0x1_0000_0001;
    expect(r.seed).toBe(1);
    expect(new Rng(0).seed).toBe(0x9e3779b9);
  });
});

describe('Rng: secuencia determinista', () => {
  it('la semilla 42 produce el vector conocido', () => {
    const r = new Rng(42);
    const esperado = [
      0.6011037519201636,
      0.44829055899754167,
      0.8524657934904099,
      0.6697340414393693,
      0.17481389874592423,
    ];
    for (const v of esperado) expect(r.randf()).toBeCloseTo(v, 12);
  });

  it('randf cae siempre en [0, 1)', () => {
    const r = new Rng(7);
    for (let i = 0; i < 1000; i++) {
      const v = r.randf();
      expect(v).toBeGreaterThanOrEqual(0);
      expect(v).toBeLessThan(1);
    }
  });

  it('randfRange respeta [from, to) y cubre el rango', () => {
    const r = new Rng(3);
    let min = Infinity;
    let max = -Infinity;
    for (let i = 0; i < 1000; i++) {
      const v = r.randfRange(10, 20);
      expect(v).toBeGreaterThanOrEqual(10);
      expect(v).toBeLessThan(20);
      min = Math.min(min, v);
      max = Math.max(max, v);
    }
    expect(min).toBeLessThan(12);
    expect(max).toBeGreaterThan(18);
  });

  it('randiRange con to<=from devuelve from', () => {
    const r = new Rng(1);
    expect(r.randiRange(5, 3)).toBe(5);
    expect(r.randiRange(5, 5)).toBe(5);
  });

  it('randiRange es inclusivo por ambos extremos', () => {
    const r = new Rng(7);
    const vistos = new Set<number>();
    for (let i = 0; i < 400; i++) {
      const v = r.randiRange(10, 19);
      expect(Number.isInteger(v)).toBe(true);
      expect(v).toBeGreaterThanOrEqual(10);
      expect(v).toBeLessThanOrEqual(19);
      vistos.add(v);
    }
    expect(vistos.has(10)).toBe(true);
    expect(vistos.has(19)).toBe(true);
  });

  it('misma semilla, misma secuencia de enteros', () => {
    const a = new Rng(123);
    const b = new Rng(123);
    for (let i = 0; i < 50; i++) expect(a.randiRange(0, 100)).toBe(b.randiRange(0, 100));
  });

  it('randomize cambia el estado', () => {
    const r = new Rng(1);
    let cambios = 0;
    for (let i = 0; i < 5; i++) {
      const antes = r.seed;
      r.randomize();
      if (r.seed !== antes) cambios++;
    }
    expect(cambios).toBeGreaterThan(0);
  });
});
