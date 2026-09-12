import * as C from '../config/GameConfig';

export const enum EffectKind {
  NINGUNO = 0,
  INMUNIDAD = 1,
  PESADO = 2,
  LIGERO = 3,
  GRANDE = 4,
  LENTO = 5,
}

const EJES: Record<string, EffectKind[]> = {
  gravedad: [EffectKind.PESADO, EffectKind.LIGERO],
  tamano: [EffectKind.GRANDE],
  mundo: [EffectKind.LENTO],
};

function ejeDe(kind: EffectKind): string {
  for (const eje of Object.keys(EJES)) {
    if (EJES[eje].includes(kind)) return eje;
  }
  return '';
}

/**
 * Port de `effects.gd`: un efecto temporal por eje, escudos apilables hasta 3.
 * Las frutas de castigo pagan en puntos (ADR-0019).
 */
export class Effects {
  duration = 6;
  heavyGravityMult = 2;
  lightGravityMult = 0.5;
  bigSizeMult = 2;
  bigHitboxMult = 1.6;
  slowSpeedMult = 0.6;

  onChanged: (activos: Array<[EffectKind, number]>) => void = () => {};
  onShieldChanged: (cantidad: number) => void = () => {};

  private restantes = new Map<EffectKind, number>();
  private shield = 0;

  update(dt: number): void {
    if (this.restantes.size === 0) return;
    for (const [k, v] of [...this.restantes.entries()]) {
      const n = v - dt;
      if (n <= 0) this.restantes.delete(k);
      else this.restantes.set(k, n);
    }
    this.onChanged(this.activos());
  }

  apply(kind: EffectKind): void {
    if (kind === EffectKind.INMUNIDAD) {
      this.shield = Math.min(this.shield + 1, C.SHIELD_MAX);
      this.onShieldChanged(this.shield);
      return;
    }
    for (const otro of EJES[ejeDe(kind)] ?? []) {
      if (otro !== kind) this.restantes.delete(otro);
    }
    this.restantes.set(kind, this.duration);
    this.onChanged(this.activos());
  }

  consumeShield(): boolean {
    if (this.shield <= 0) return false;
    this.shield--;
    this.onShieldChanged(this.shield);
    return true;
  }

  hasShield(): boolean {
    return this.shield > 0;
  }

  shieldCount(): number {
    return this.shield;
  }

  activos(): Array<[EffectKind, number]> {
    const salida = [...this.restantes.entries()].map(
      ([k, v]) => [k, v] as [EffectKind, number],
    );
    salida.sort((a, b) => b[1] - a[1]);
    return salida;
  }

  activo(kind: EffectKind): boolean {
    return this.restantes.has(kind);
  }

  gravityMult(): number {
    if (this.activo(EffectKind.PESADO)) return this.heavyGravityMult;
    if (this.activo(EffectKind.LIGERO)) return this.lightGravityMult;
    return 1;
  }

  speedMult(): number {
    return this.activo(EffectKind.LENTO) ? this.slowSpeedMult : 1;
  }

  sizeMult(): number {
    return this.activo(EffectKind.GRANDE) ? this.bigSizeMult : 1;
  }

  hitboxMult(): number {
    return this.activo(EffectKind.GRANDE) ? this.bigHitboxMult : 1;
  }

  kindName(kind: EffectKind): string {
    switch (kind) {
      case EffectKind.PESADO:
        return 'Pesado';
      case EffectKind.LIGERO:
        return 'Ligero';
      case EffectKind.GRANDE:
        return 'Grande';
      case EffectKind.LENTO:
        return 'Lento';
      default:
        return '';
    }
  }

  clear(): void {
    this.restantes.clear();
    this.shield = 0;
    this.onChanged([]);
    this.onShieldChanged(0);
  }
}

export function fruitTexture(kind: EffectKind): string {
  switch (kind) {
    case EffectKind.INMUNIDAD:
      return 'fruit_azul';
    case EffectKind.PESADO:
      return 'fruit_roja';
    case EffectKind.LIGERO:
      return 'fruit_verde';
    case EffectKind.GRANDE:
      return 'fruit_naranja';
    case EffectKind.LENTO:
      return 'fruit_violeta';
    default:
      return 'fruit_azul';
  }
}
