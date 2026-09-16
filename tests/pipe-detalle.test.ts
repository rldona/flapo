import { describe, expect, it } from 'vitest';
import { Pipe } from '../src/systems/Pipe';

/** Detalles que matan mutantes de `Pipe`. */

describe('Pipe · estados por defecto', () => {
  it('un tubo nuevo no es blandito ni giratorio', () => {
    const p = new Pipe();
    expect(p.soft).toBe(false);
    expect(p.spin).toBe(false);
    expect(p.scored).toBe(false);
    expect(p.gone).toBe(false);
    expect(p.moving).toBe(true);
  });
});

describe('Pipe · oscilación', () => {
  it('sin amplitud o sin periodo no oscila', () => {
    const sinAmp = new Pipe();
    sinAmp.setGapCenter(200);
    sinAmp.oscillationAmplitude = 0;
    sinAmp.oscillationPeriod = 2;
    sinAmp.update(0.5);
    expect(sinAmp.gapCenter).toBe(200);
    expect(sinAmp.isOscillating()).toBe(false);

    const sinPeriodo = new Pipe();
    sinPeriodo.setGapCenter(200);
    sinPeriodo.oscillationAmplitude = 10;
    sinPeriodo.oscillationPeriod = 0;
    sinPeriodo.update(0.5);
    expect(sinPeriodo.gapCenter).toBe(200);
  });

  it('oscila según la fórmula exacta', () => {
    const p = new Pipe();
    p.setGapCenter(200);
    p.oscillationAmplitude = 10;
    p.oscillationPeriod = 2;
    p.oscillationPhase = 0;
    p.update(0.5); // ángulo = (0.5·2π)/2 = π/2
    expect(p.gapCenter).toBeCloseTo(210, 9);
    p.update(0.5); // ángulo = π
    expect(p.gapCenter).toBeCloseTo(200, 9);
  });

  it('no oscila si no se mueve', () => {
    const p = new Pipe();
    p.setGapCenter(200);
    p.oscillationAmplitude = 10;
    p.oscillationPeriod = 2;
    p.moving = false;
    p.update(0.5);
    expect(p.gapCenter).toBe(200);
  });
});

describe('Pipe · giro y bordes', () => {
  it('solo acumula tiempo de giro si es giratorio', () => {
    const gira = new Pipe();
    gira.spin = true;
    gira.update(1);
    expect(gira.spinTime).toBeCloseTo(1, 9);

    const quieto = new Pipe();
    quieto.spin = false;
    quieto.update(1);
    expect(quieto.spinTime).toBe(0);
  });

  it('se marca gone justo al cruzar el borde izquierdo', () => {
    const p = new Pipe();
    p.scrollSpeed = 0;
    p.x = -p.width / 2; // x + width/2 = 0, todavía no
    p.update(0);
    expect(p.gone).toBe(false);

    p.x = -p.width / 2 - 1e-6;
    p.update(0);
    expect(p.gone).toBe(true);
  });

  it('no se marca gone por pasar cerca del borde con x positiva', () => {
    const p = new Pipe();
    p.scrollSpeed = 0;
    p.x = 10;
    p.update(0);
    expect(p.gone).toBe(false);
  });

  it('bottomRect usa x - width/2', () => {
    const p = new Pipe();
    p.x = 100;
    p.width = 26;
    p.gap = 100;
    p.setGapCenter(250);
    expect(p.bottomRect().x).toBe(100 - 13);
  });
});
