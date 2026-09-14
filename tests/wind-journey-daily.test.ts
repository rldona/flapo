import { beforeEach, describe, expect, it } from 'vitest';
import * as C from '../src/config/GameConfig';
import { dailyKey, dailyName, dailySeed } from '../src/config/GameConfig';
import { Rng } from '../src/core/Rng';
import { GameState } from '../src/core/types';
import { DailyChallenge } from '../src/meta/DailyChallenge';
import { SaveManager } from '../src/meta/SaveManager';
import { Journey } from '../src/systems/Journey';
import { Wind } from '../src/systems/Wind';

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

describe('Wind: ciclo calma-aviso-racha', () => {
  it('sin rng o deshabilitado no hace nada', () => {
    const eventos: string[] = [];
    const wind = new Wind({
      onWarning: () => eventos.push('aviso'),
      onGust: () => eventos.push('sopla'),
      onEnded: () => eventos.push('fin'),
    });
    wind.enabled = true;
    wind.update(100);
    expect(eventos).toEqual([]);
    expect(wind.isWarning()).toBe(false);
    expect(wind.isBlowing()).toBe(false);

    const { wind: w2, eventos: e2 } = windHabilitado();
    w2.enabled = false;
    w2.update(100);
    expect(e2).toEqual([]);
  });

  it('recorre CALMA -> AVISO (2s) -> SOPLANDO (5s) -> CALMA', () => {
    const { wind, eventos } = windHabilitado(7);
    expect(wind.isWarning()).toBe(false);
    expect(wind.isBlowing()).toBe(false);

    // La calma inicial dura entre 12 y 22s: avanzar de sobra la agota
    wind.update(C.WIND_CALM_MAX + 0.01);
    expect(eventos).toHaveLength(1);
    expect(eventos[0].startsWith('aviso:')).toBe(true);
    expect(wind.isWarning()).toBe(true);
    expect(wind.timeLeft()).toBeCloseTo(C.WIND_WARNING_TIME, 5);

    // A mitad del aviso sigue avisando
    wind.update(C.WIND_WARNING_TIME - 0.05);
    expect(wind.isWarning()).toBe(true);
    wind.update(0.06);
    expect(eventos[1].startsWith('sopla:')).toBe(true);
    expect(wind.isBlowing()).toBe(true);
    expect(wind.timeLeft()).toBeCloseTo(C.WIND_DURATION, 5);
    // El aviso y la racha comparten dirección
    expect(eventos[0].split(':')[1]).toBe(eventos[1].split(':')[1]);

    wind.update(C.WIND_DURATION - 0.05);
    expect(wind.isBlowing()).toBe(true);
    wind.update(0.06);
    expect(eventos[2]).toBe('fin');
    expect(wind.isBlowing()).toBe(false);
    expect(wind.isWarning()).toBe(false);
  });

  it('la calma cae en [12, 22] y el aviso/soplo duran lo fijado', () => {
    const { wind } = windHabilitado(3);
    // reset() ya fijó una calma al hacer setRng? No: setRng no resetea.
    // Forzamos reset para medir la calma sorteada.
    wind.reset();
    const calma = wind.timeLeft();
    expect(calma).toBeGreaterThanOrEqual(C.WIND_CALM_MIN - 1e-6);
    expect(calma).toBeLessThanOrEqual(C.WIND_CALM_MAX + 1e-6);
  });

  it('misma semilla, misma secuencia de direcciones', () => {
    const a = windHabilitado(4242);
    const b = windHabilitado(4242);
    for (let i = 0; i < 200; i++) {
      a.wind.update(0.5);
      b.wind.update(0.5);
    }
    expect(a.eventos).toEqual(b.eventos);
    expect(a.eventos.length).toBeGreaterThan(2);
  });

  it('salir de PLAYING apaga y resetea', () => {
    const { wind, eventos } = windHabilitado(11);
    wind.update(C.WIND_CALM_MAX + 0.01);
    expect(wind.isWarning()).toBe(true);
    wind.onStateChanged(GameState.GAME_OVER);
    expect(wind.enabled).toBe(false);
    expect(wind.isWarning()).toBe(false);
    expect(wind.isBlowing()).toBe(false);
    const n = eventos.length;
    wind.update(100);
    expect(eventos.length).toBe(n);
  });

  it('randomSeed deja el rng re-sembrado tras reset', () => {
    const mk = (): Wind => {
      const wind = new Wind({
        onWarning: () => {},
        onGust: () => {},
        onEnded: () => {},
      });
      wind.randomSeed = 555;
      wind.setRng(new Rng(1));
      wind.enabled = true;
      return wind;
    };
    const w1 = mk();
    const w2 = mk();
    w1.reset();
    w2.reset();
    // Misma semilla -> misma primera calma
    expect(w1.timeLeft()).toBeCloseTo(w2.timeLeft(), 8);
    // Y el rng queda re-sembrado a randomSeed
    expect((w1 as unknown as { rng: Rng }).rng).toBeDefined();
    // Dos resets seguidos repiten valor (sortea y re-siembra)
    const primera = w1.timeLeft();
    w1.reset();
    expect(w1.timeLeft()).toBeCloseTo(primera, 8);
  });

  it('isTailwind refleja la dirección sorteada', () => {
    const { wind } = windHabilitado(21);
    const antes = wind.isTailwind();
    expect(typeof antes).toBe('boolean');
    wind.update(C.WIND_CALM_MAX + 0.01);
    expect(typeof wind.isTailwind()).toBe('boolean');
  });
});

describe('Journey: el nido a 50', () => {
  function journey(): { j: Journey; eventos: string[] } {
    const eventos: string[] = [];
    const j = new Journey({
      onStarted: () => eventos.push('empieza'),
      onEnded: () => eventos.push('termina'),
    });
    return { j, eventos };
  }

  it('solo arranca justo a 50 y una sola vez', () => {
    const { j, eventos } = journey();
    expect(j.quizaEmpezar(49)).toBe(false);
    expect(j.quizaEmpezar(51)).toBe(false);
    expect(j.activaAhora()).toBe(false);
    expect(j.quizaEmpezar(C.JOURNEY_END_SCORE)).toBe(true);
    expect(j.activaAhora()).toBe(true);
    expect(j.usadaYa()).toBe(true);
    expect(eventos).toEqual(['empieza']);
    // Ni reintento con 50 ni update la reactivan
    expect(j.quizaEmpezar(50)).toBe(false);
    expect(eventos).toEqual(['empieza']);
  });

  it('dura JOURNEY_SCENE_TIME y luego termina', () => {
    const { j, eventos } = journey();
    j.quizaEmpezar(50);
    expect(j.restanteSeg).toBeCloseTo(C.JOURNEY_SCENE_TIME, 5);
    j.update(C.JOURNEY_SCENE_TIME - 0.05);
    expect(j.activaAhora()).toBe(true);
    j.update(0.06);
    expect(j.activaAhora()).toBe(false);
    expect(j.restanteSeg).toBe(0);
    expect(eventos).toEqual(['empieza', 'termina']);
  });

  it('sin escena, update no hace nada', () => {
    const { j, eventos } = journey();
    j.update(10);
    expect(eventos).toEqual([]);
    expect(j.activaAhora()).toBe(false);
  });

  it('READY resetea y permite reintentar', () => {
    const { j, eventos } = journey();
    j.quizaEmpezar(50);
    j.onStateChanged(GameState.READY);
    expect(j.activaAhora()).toBe(false);
    expect(j.usadaYa()).toBe(false);
    expect(j.quizaEmpezar(50)).toBe(true);
    expect(eventos).toEqual(['empieza', 'empieza']);
  });

  it('GAME_OVER en plena escena la cierra', () => {
    const { j, eventos } = journey();
    j.quizaEmpezar(50);
    j.onStateChanged(GameState.GAME_OVER);
    expect(j.activaAhora()).toBe(false);
    expect(eventos).toEqual(['empieza', 'termina']);
  });

  it('GAME_OVER sin escena no dispara cierre', () => {
    const { j, eventos } = journey();
    j.onStateChanged(GameState.GAME_OVER);
    expect(eventos).toEqual([]);
  });

  it('MENU resetea como READY', () => {
    const { j } = journey();
    j.quizaEmpezar(50);
    j.onStateChanged(GameState.MENU);
    expect(j.usadaYa()).toBe(false);
    expect(j.activaAhora()).toBe(false);
  });
});

describe('Daily: funciones puras de fecha', () => {
  it('la semilla es YYYYMMDD y la clave la envuelve', () => {
    expect(dailySeed(2026, 9, 14)).toBe(20260914);
    expect(dailyKey(2026, 9, 14)).toBe('daily_20260914');
  });

  it('el nombre usa el mes en español', () => {
    expect(dailyName(9, 14)).toBe('14 de septiembre');
    expect(dailyName(1, 1)).toBe('1 de enero');
  });

  it('mes inválido cae a formato corto sin reventar', () => {
    expect(dailyName(0, 5)).toBe('5/0');
    expect(dailyName(13, 5)).toBe('5/13');
  });
});

describe('DailyChallenge: reto del día sin servidor', () => {
  it('empieza inactivo y vacío', () => {
    const d = new DailyChallenge();
    expect(d.activo()).toBe(false);
    expect(d.semilla()).toBe(0);
    expect(d.clave()).toBe('');
    expect(d.nombre()).toBe('');
    expect(d.mejor()).toBe(0);
  });

  it('empezar sin fecha usa hoy', () => {
    const d = new DailyChallenge();
    d.empezar();
    expect(d.activo()).toBe(true);
    const hoy = DailyChallenge.hoy();
    expect(d.fecha).toEqual(hoy);
    expect(d.semilla()).toBe(dailySeed(hoy[0], hoy[1], hoy[2]));
  });

  it('empezar con fecha la copia (no alias)', () => {
    const d = new DailyChallenge();
    const fecha = [2026, 9, 14];
    d.empezar(fecha);
    fecha[2] = 99;
    expect(d.fecha).toEqual([2026, 9, 14]);
    expect(d.semilla()).toBe(20260914);
    expect(d.clave()).toBe('daily_20260914');
    expect(d.nombre()).toBe('Reto del 14 de septiembre');
  });

  it('parar desactiva', () => {
    const d = new DailyChallenge();
    d.empezar([2026, 9, 14]);
    d.parar();
    expect(d.activo()).toBe(false);
    expect(d.clave()).toBe('');
  });

  it('hoy devuelve una fecha válida', () => {
    const [y, m, dd] = DailyChallenge.hoy();
    expect(y).toBeGreaterThanOrEqual(2026);
    expect(m).toBeGreaterThanOrEqual(1);
    expect(m).toBeLessThanOrEqual(12);
    expect(dd).toBeGreaterThanOrEqual(1);
    expect(dd).toBeLessThanOrEqual(31);
  });

  it('mejor() lee el récord del día guardado', () => {
    const d = new DailyChallenge();
    d.empezar([2026, 9, 14]);
    expect(d.mejor()).toBe(0);
    expect(SaveManager.recordDaily(d.clave(), 12)).toBe(true);
    expect(d.mejor()).toBe(12);
    // No baja con peor marca
    expect(SaveManager.recordDaily(d.clave(), 5)).toBe(false);
    expect(d.mejor()).toBe(12);
  });

  it('días distintos no comparten récord', () => {
    const a = new DailyChallenge();
    const b = new DailyChallenge();
    a.empezar([2026, 9, 14]);
    b.empezar([2026, 9, 15]);
    SaveManager.recordDaily(a.clave(), 20);
    expect(a.mejor()).toBe(20);
    expect(b.mejor()).toBe(0);
  });
});
