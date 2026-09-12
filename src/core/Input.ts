/**
 * Entrada unificada: toque, ratón y teclado.
 *
 * Port de `ADR-0004` del original: la acción `flap` es una sola, venga de
 * donde venga, y las pulsaciones se consumen una sola vez por tick de física,
 * igual que `is_action_just_pressed`.
 */
export class Input {
  private flapHeld = false;
  private flapJust = false;
  private restartJust = false;
  private pauseJust = false;
  private pointerId: number | null = null;

  /** Desactiva el flap (por ejemplo con un modal abierto). */
  enabled = true;

  constructor(private readonly surface: HTMLElement) {
    surface.addEventListener('pointerdown', this.onPointerDown);
    window.addEventListener('pointerup', this.onPointerUp);
    window.addEventListener('pointercancel', this.onPointerUp);
    window.addEventListener('keydown', this.onKeyDown);
    window.addEventListener('keyup', this.onKeyUp);
    window.addEventListener('blur', this.releaseAll);
  }

  dispose(): void {
    this.surface.removeEventListener('pointerdown', this.onPointerDown);
    window.removeEventListener('pointerup', this.onPointerUp);
    window.removeEventListener('pointercancel', this.onPointerUp);
    window.removeEventListener('keydown', this.onKeyDown);
    window.removeEventListener('keyup', this.onKeyUp);
    window.removeEventListener('blur', this.releaseAll);
  }

  isFlapPressed(): boolean {
    return this.flapHeld;
  }

  /** Flanco de subida del flap; se limpia al leerlo. */
  consumeFlapJust(): boolean {
    const v = this.flapJust;
    this.flapJust = false;
    return v;
  }

  consumeRestart(): boolean {
    const v = this.restartJust;
    this.restartJust = false;
    return v;
  }

  consumePause(): boolean {
    const v = this.pauseJust;
    this.pauseJust = false;
    return v;
  }

  private pressFlap(): void {
    if (!this.enabled || this.flapHeld) return;
    this.flapHeld = true;
    this.flapJust = true;
  }

  private releaseFlap(): void {
    this.flapHeld = false;
  }

  private onPointerDown = (e: PointerEvent): void => {
    if (e.button !== 0 && e.pointerType === 'mouse') return;
    e.preventDefault();
    if (this.pointerId !== null) return;
    this.pointerId = e.pointerId;
    this.pressFlap();
  };

  private onPointerUp = (e: PointerEvent): void => {
    if (this.pointerId !== null && e.pointerId !== this.pointerId) return;
    this.pointerId = null;
    this.releaseFlap();
  };

  private onKeyDown = (e: KeyboardEvent): void => {
    const t = e.target as HTMLElement | null;
    if (
      t &&
      (t.tagName === 'INPUT' ||
        t.tagName === 'TEXTAREA' ||
        t.tagName === 'BUTTON' ||
        t.isContentEditable)
    ) {
      return;
    }
    if (e.repeat) {
      if (e.code === 'Space') e.preventDefault();
      return;
    }
    if (e.code === 'Space' || e.code === 'ArrowUp') {
      e.preventDefault();
      this.pressFlap();
    } else if (e.code === 'KeyR' || e.code === 'Enter') {
      this.restartJust = true;
    } else if (e.code === 'KeyP' || e.code === 'Escape') {
      this.pauseJust = true;
    }
  };

  private onKeyUp = (e: KeyboardEvent): void => {
    if (e.code === 'Space' || e.code === 'ArrowUp') this.releaseFlap();
  };

  private releaseAll = (): void => {
    this.flapHeld = false;
    this.pointerId = null;
  };
}
