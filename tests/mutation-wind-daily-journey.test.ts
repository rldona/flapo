import { beforeEach, describe, expect, it } from 'vitest';
import * as C from '../src/config/GameConfig';
import { Rng } from '../src/core/Rng';
import { GameState } from '../src/core/types';
import { DailyChallenge } from '../src/meta/DailyChallenge';
import { SaveManager } from '../src/meta/SaveManager';
import { Journey } from '../src/systems/Journey';
import { Wind } from '../src/systems/Wind';

/** Tests de detalle para matar mutantes en `Wind`, `Journey` y `DailyChallenge`. */

class MemStorage {
  private map = new Map<string, string>();
  getItem(k: string): string | null {
    return this.map.has(k) ? (this.map.get(k) as string) : null;
  }
  setItem(k: string, v: string): void {
    this.map.set(k, String(v));
  }
  removeItem(k: string): void {
    this.map.delete(k);
  }
  clear(): void {
    this.map.clear();
  }
}

beforeEach(() => {
  (globalThis as unknown as { localStorage: MemStorage }).localStorage = new MemStorage();
  SaveManager.forgetCache();
  SaveManager.clear();
});

function windHabilitado(seed = 99): { wind: Wind; eventos: string[] } {
  const eventos: string[] = [];
  const wind = new Wind({
    onWarning: (aFavor) => eventos.push(`aviso:${aFavor ? 'cola' : 'cara'}`),
    onGust: (aFavor) => eventos.push(`sopla:${aFavor ? 'cola' : 'cara'}`),
    onEnded: () => eventos.push('fin'),
  });
  wind.setRng(new Rng(seed));
  wind.enabled = true;
  return { wind, eventos };
}

describe('Wind · detalle', () => {
  it('arranca deshabilitado y con viento de cola por defecto', () => {
    const wind = new Wind({ onWarning: () => {}, onGust: () => {}, onEnded: () => {} });
    expect(wind.enabled).toBe(false);
    expect(wind.isTailwind()).toBe(true);
  });

  it('setRng no toca la semilla si randomSeed es 0', () => {
    const wind = new Wind({ onWarning: () => {}, onGust: () => {}, onEnded: () => {} });
    const rng = new Rng(123);
    wind.randomSeed = 0;
    wind.setRng(rng);
    expect(rng.seed).toBe(123);
  });

  it('onStateChanged(PLAYING) no resetea', () => {
    const { wind } = windHabilitado(7);
    wind.update(C.WIND_CALM_MAX + 0.01);
    expect(wind.isWarning()).toBe(true);
    wind.onStateChanged(GameState.PLAYING);
    expect(wind.enabled).toBe(true);
    expect(wind.isWarning()).toBe(true);
  });

  it('reset no re-siembra si randomSeed es 0', () => {
    const wind = new Wind({ onWarning: () => {}, onGust: () => {}, onEnded: () => {} });
    const rng = new Rng(1);
    const ref = new Rng(1);
    wind.setRng(rng);
    wind.reset();
    // El sorteo de la calma consume un `randf`; sin re-siembra, el estado debe
    // coincidir con el de un rng gemelo tras ese único consumo.
    ref.randf();
    expect(rng.seed).toBe(ref.seed);
  });

  it('reset re-siembra siempre con randomSeed', () => {
    const wind = new Wind({ onWarning: () => {}, onGust: () => {}, onEnded: () => {} });
    wind.randomSeed = 555;
    const rng = new Rng(1);
    wind.setRng(rng);
    rng.randf();
    rng.randf();
    wind.reset();
    expect(rng.randf()).toBeCloseTo(new Rng(555).randf(), 12);
  });

  it('el temporizador dispara también cuando llega justo a 0', () => {
    const { wind } = windHabilitado(7);
    wind.reset();
    const calma = wind.timeLeft();
    wind.update(calma);
    expect(wind.isWarning()).toBe(true);
  });

  it('la dirección sortea cola y cara con semillas distintas', () => {
    const direcciones = new Set<boolean>();
    for (let seed = 1; seed <= 60; seed++) {
      const { wind } = windHabilitado(seed);
      wind.reset();
      wind.update(wind.timeLeft());
      direcciones.add(wind.isTailwind());
    }
    expect(direcciones.has(true)).toBe(true);
    expect(direcciones.has(false)).toBe(true);
  });

  it('sin rng, la calma es el mínimo', () => {
    const wind = new Wind({ onWarning: () => {}, onGust: () => {}, onEnded: () => {} });
    wind.reset();
    expect(wind.timeLeft()).toBe(C.WIND_CALM_MIN);
  });

  it('con rng, la calma se sortea y supera el mínimo', () => {
    let max = 0;
    for (let seed = 1; seed <= 40; seed++) {
      const { wind } = windHabilitado(seed);
      wind.reset();
      max = Math.max(max, wind.timeLeft());
    }
    expect(max).toBeGreaterThan(C.WIND_CALM_MIN);
  });
});

describe('Journey · detalle', () => {
  function journey(): { j: Journey; eventos: string[] } {
    const eventos: string[] = [];
    const j = new Journey({
      onStarted: () => eventos.push('empieza'),
      onEnded: () => eventos.push('termina'),
    });
    return { j, eventos };
  }

  it('termina cuando el restante llega justo a 0', () => {
    const { j, eventos } = journey();
    j.quizaEmpezar(C.JOURNEY_END_SCORE);
    j.update(C.JOURNEY_SCENE_TIME);
    expect(j.activaAhora()).toBe(false);
    expect(eventos).toEqual(['empieza', 'termina']);
  });

  it('una vez usada y terminada, no se repite', () => {
    const { j } = journey();
    j.quizaEmpezar(C.JOURNEY_END_SCORE);
    j.update(C.JOURNEY_SCENE_TIME);
    expect(j.activaAhora()).toBe(false);
    expect(j.usadaYa()).toBe(true);
    expect(j.quizaEmpezar(C.JOURNEY_END_SCORE)).toBe(false);
  });
});

describe('DailyChallenge · detalle', () => {
  it('nace con fecha vacía', () => {
    const d = new DailyChallenge();
    expect(d.fecha).toEqual([]);
  });

  it('hoy usa el mes 1-based del reloj', () => {
    const d = new DailyChallenge();
    d.empezar();
    const ahora = new Date();
    expect(d.fecha).toEqual([ahora.getFullYear(), ahora.getMonth() + 1, ahora.getDate()]);
  });

  it('empezar con array vacío usa hoy', () => {
    const d = new DailyChallenge();
    d.empezar([]);
    expect(d.activo()).toBe(true);
    expect(d.fecha).toEqual(DailyChallenge.hoy());
  });

  it('parar deja la fecha a []', () => {
    const d = new DailyChallenge();
    d.empezar([2026, 9, 14]);
    d.parar();
    expect(d.fecha).toEqual([]);
    expect(d.activo()).toBe(false);
  });
});
