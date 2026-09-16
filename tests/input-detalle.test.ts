import { describe, expect, it, vi } from 'vitest';
import { Input } from '../src/core/Input';

/** Detalles de `Input` que matan mutantes: estado inicial, preventDefault y bordes. */

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

function puntero(pd: () => void, extra: Record<string, unknown> = {}): Record<string, unknown> {
  return { button: 0, pointerType: 'mouse', pointerId: 1, preventDefault: pd, ...extra };
}

function tecla(code: string, extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    code,
    repeat: false,
    target: { tagName: 'BODY' },
    preventDefault: () => {},
    ...extra,
  };
}

describe('Input · estado inicial', () => {
  it('empieza sin flap, reinicio ni pausa pendientes', () => {
    const { input } = instalar();
    expect(input.isFlapPressed()).toBe(false);
    expect(input.consumeFlapJust()).toBe(false);
    expect(input.consumeRestart()).toBe(false);
    expect(input.consumePause()).toBe(false);
  });
});

describe('Input · bordes', () => {
  it('pointerdown evita el comportamiento por defecto', () => {
    const { surface } = instalar();
    const pd = vi.fn();
    surface.emitir('pointerdown', puntero(pd));
    expect(pd).toHaveBeenCalled();
  });

  it('un puntero no-ratón con botón no principal sí aletea', () => {
    const { input, surface } = instalar();
    surface.emitir('pointerdown', puntero(() => {}, { button: 2, pointerType: 'touch' }));
    expect(input.isFlapPressed()).toBe(true);
  });

  it('un pointerup de otro puntero no suelta el flap', () => {
    const { input, surface, ventana } = instalar();
    surface.emitir('pointerdown', puntero(() => {}, { pointerId: 1 }));
    ventana.emitir('pointerup', { pointerId: 2 });
    expect(input.isFlapPressed()).toBe(true);
  });

  it('ignora el teclado si el foco está en un TEXTAREA', () => {
    const { input, ventana } = instalar();
    ventana.emitir('keydown', tecla('Space', { target: { tagName: 'TEXTAREA' } }));
    expect(input.isFlapPressed()).toBe(false);
  });

  it('en repetición evita el scroll solo con Space', () => {
    const { input, ventana } = instalar();
    const pdSpace = vi.fn();
    ventana.emitir('keydown', tecla('Space', { repeat: true, preventDefault: pdSpace }));
    expect(pdSpace).toHaveBeenCalled();
    expect(input.isFlapPressed()).toBe(false);

    const pdArriba = vi.fn();
    ventana.emitir('keydown', tecla('ArrowUp', { repeat: true, preventDefault: pdArriba }));
    expect(pdArriba).not.toHaveBeenCalled();
  });

  it('consumePause solo devuelve true una vez', () => {
    const { input, ventana } = instalar();
    ventana.emitir('keydown', tecla('KeyP'));
    expect(input.consumePause()).toBe(true);
    expect(input.consumePause()).toBe(false);
  });

  it('un segundo puntero no roba el seguimiento del primero', () => {
    const { input, surface, ventana } = instalar();
    surface.emitir('pointerdown', puntero(() => {}, { pointerId: 1 }));
    surface.emitir('pointerdown', puntero(() => {}, { pointerId: 2 }));
    ventana.emitir('pointerup', { pointerId: 2 });
    expect(input.isFlapPressed()).toBe(true);
  });

  it('teclas ajenas no aletean ni pausan ni reinician', () => {
    const { input, ventana } = instalar();
    ventana.emitir('keydown', tecla('KeyA'));
    expect(input.isFlapPressed()).toBe(false);
    expect(input.consumePause()).toBe(false);
    expect(input.consumeRestart()).toBe(false);
  });

  it('ArrowUp aletea y Space evita el scroll', () => {
    const { input, ventana } = instalar();
    const pd = vi.fn();
    ventana.emitir('keydown', tecla('Space', { preventDefault: pd }));
    expect(pd).toHaveBeenCalled();
    expect(input.isFlapPressed()).toBe(true);

    const { input: otro, ventana: v2 } = instalar();
    v2.emitir('keydown', tecla('ArrowUp'));
    expect(otro.isFlapPressed()).toBe(true);
  });
});
