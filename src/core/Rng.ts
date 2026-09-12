/**
 * Generador determinista de la partida, equivalente a
 * `RandomNumberGenerator` de Godot (T-240, ADR-0030).
 *
 * Un solo generador por partida, compartido por tuberías, frutas y viento. La
 * secuencia depende solo de la semilla, así que dos navegadores con el mismo
 * código juegan exactamente las mismas tuberías.
 *
 * Implementación: mulberry32. No es el mismo PCG de Godot —no se busca
 * reproducir byte a byte el original—, pero sí es determinista, rápido y
 * estable entre motores JS.
 */
export class Rng {
  private state = 0;

  constructor(seed = 0) {
    this.seed = seed;
  }

  get seed(): number {
    return this.state >>> 0;
  }

  set seed(value: number) {
    // Godot usa la semilla en crudo; aquí se normaliza a uint32. El valor se
    // guarda tal cual para poder mostrarlo como código.
    this.state = (value >>> 0) || 0x9e3779b9;
  }

  randomize(): void {
    let s: number;
    if (typeof crypto !== 'undefined' && 'getRandomValues' in crypto) {
      const buf = new Uint32Array(1);
      crypto.getRandomValues(buf);
      s = buf[0];
    } else {
      s = (Math.random() * 0xffffffff) >>> 0;
    }
    this.state = s >>> 0;
  }

  /** [0, 1) */
  randf(): number {
    let t = (this.state += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  /** [from, to) como `randf_range`. */
  randfRange(from: number, to: number): number {
    return from + (to - from) * this.randf();
  }

  /** [from, to] ambos inclusive, como `randi_range`. */
  randiRange(from: number, to: number): number {
    if (to <= from) return from;
    return from + Math.floor(this.randf() * (to - from + 1));
  }
}
