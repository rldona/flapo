import { afterEach, describe, expect, it, vi } from 'vitest';
import { Input } from '../src/core/Input';

/**
 * Entrada real: flancos de puntero y teclado. La acción `flap` es una sola y
 * `consumeFlapJust` solo devuelve true una vez por pulsación.
 */

class ObjetivoFalso {
  readonly escuchas = new Map<string, Set<(e: unknown) => void>>();
  addEventListener(tipo: string, fn: (e: unknown) => void): void {
    if (!this.escuchas.has(tipo)) this.escuchas.set(tipo, new Set());
    this.escuchas.get(tipo)!.add(fn);
  }
  removeEventListener(tipo: string, fn: (e: unknown) => void): void {
    this.escuchas.get(tipo)?.delete(fn);
  }
  emitir(tipo: string, evento: Record<string, unknown> = {}): void {
    for (const fn of this.escuchas.get(tipo) ?? []) fn(evento);
  }
}

function instalar(): { input: Input; surface: ObjetivoFalso; ventana: ObjetivoFalso } {
  const surface = new ObjetivoFalso();
  const ventana = new ObjetivoFalso();
  vi.stubGlobal('window', ventana);
  const input = new Input(surface as unknown as HTMLElement);
  return { input, surface, ventana };
}

function puntero(extra: Record<string, unknown> = {}): Record<string, unknown> {
  return { button: 0, pointerType: 'mouse', pointerId: 1, preventDefault() {}, ...extra };
}

function tecla(code: string, extra: Record<string, unknown> = {}): Record<string, unknown> {
  return { code, repeat: false, target: { tagName: 'BODY' }, preventDefault() {}, ...extra };
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('Input · puntero', () => {
  it('pointerdown aletea una sola vez (flap just)', () => {
    const { input, surface } = instalar();
    surface.emitir('pointerdown', puntero());
    expect(input.isFlapPressed()).toBe(true);
    expect(input.consumeFlapJust()).toBe(true);
    expect(input.consumeFlapJust()).toBe(false);
  });

  it('pointerup suelta el flap', () => {
    const { input, surface, ventana } = instalar();
    surface.emitir('pointerdown', puntero({ pointerId: 7 }));
    ventana.emitir('pointerup', { pointerId: 7 });
    expect(input.isFlapPressed()).toBe(false);
  });

  it('ignora un segundo puntero mientras el primero sigue activo', () => {
    const { input, surface } = instalar();
    surface.emitir('pointerdown', puntero({ pointerId: 1 }));
    input.consumeFlapJust();
    surface.emitir('pointerdown', puntero({ pointerId: 2 }));
    expect(input.consumeFlapJust()).toBe(false);
  });

  it('ignora el botón no principal del ratón', () => {
    const { input, surface } = instalar();
    surface.emitir('pointerdown', puntero({ button: 2 }));
    expect(input.isFlapPressed()).toBe(false);
  });

  it('deshabilitado no aletea', () => {
    const { input, surface } = instalar();
    input.enabled = false;
    surface.emitir('pointerdown', puntero());
    expect(input.isFlapPressed()).toBe(false);
  });
});

describe('Input · teclado', () => {
  it('Space y ArrowUp aletean; keyup suelta', () => {
    const { input, ventana } = instalar();
    ventana.emitir('keydown', tecla('Space'));
    expect(input.consumeFlapJust()).toBe(true);
    ventana.emitir('keyup', tecla('Space'));
    expect(input.isFlapPressed()).toBe(false);

    ventana.emitir('keydown', tecla('ArrowUp'));
    expect(input.isFlapPressed()).toBe(true);
  });

  it('R y Enter piden reinicio', () => {
    const { input, ventana } = instalar();
    ventana.emitir('keydown', tecla('KeyR'));
    expect(input.consumeRestart()).toBe(true);
    expect(input.consumeRestart()).toBe(false);

    ventana.emitir('keydown', tecla('Enter'));
    expect(input.consumeRestart()).toBe(true);
  });

  it('P y Escape piden pausa', () => {
    const { input, ventana } = instalar();
    ventana.emitir('keydown', tecla('KeyP'));
    expect(input.consumePause()).toBe(true);
    ventana.emitir('keydown', tecla('Escape'));
    expect(input.consumePause()).toBe(true);
  });

  it('no aletea si el foco está en un campo o botón', () => {
    const { input, ventana } = instalar();
    ventana.emitir('keydown', tecla('Space', { target: { tagName: 'INPUT' } }));
    ventana.emitir('keydown', tecla('Space', { target: { tagName: 'BUTTON' } }));
    ventana.emitir('keydown', tecla('Space', { target: { tagName: 'DIV', isContentEditable: true } }));
    expect(input.isFlapPressed()).toBe(false);
  });

  it('ignora las repeticiones automáticas', () => {
    const { input, ventana } = instalar();
    ventana.emitir('keydown', tecla('Space', { repeat: true }));
    expect(input.isFlapPressed()).toBe(false);
  });

  it('blur suelta el flap', () => {
    const { input, ventana } = instalar();
    ventana.emitir('keydown', tecla('Space'));
    expect(input.isFlapPressed()).toBe(true);
    ventana.emitir('blur');
    expect(input.isFlapPressed()).toBe(false);
  });
});
