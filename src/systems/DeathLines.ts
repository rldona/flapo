import type { Rng } from '../core/Rng';
import { DeathCause } from '../core/types';

/** Contenido portado de `assets/data/death_lines.tres` (T-056/T-075). */
const LINES = [
  '¡Uf!',
  'Casi.',
  'Ya casi lo tenías.',
  'El aire estaba raro hoy.',
  'Vuelve a intentarlo, va.',
  'Esa tubería salió de la nada.',
  'Flapo lo ha dado todo.',
  'Un poco más arriba y pasa.',
  'La gravedad no perdona.',
  'Otra vez, que ahora sí.',
  'Buen intento, de verdad.',
  'Se te ha ido un pelín.',
];

const LINES_PIPE = [
  'Esa tubería salió de la nada.',
  'De morros contra el tubo.',
  'Un poco más arriba y pasa.',
  'La tubería no se ha movido, eh.',
  'Ahí había hueco, de verdad.',
];

const LINES_GROUND = [
  'Aterrizaje mejorable.',
  'El suelo sigue ahí, sí.',
  'Se te ha ido hacia abajo.',
  'Un aleteo más y no pasa.',
  'La gravedad no perdona.',
];

const LINES_VOID = [
  'Se ha ido por abajo del todo.',
  'Ahí abajo no hay nada, Flapo.',
  'Eso ha sido un picado con ganas.',
];

const LINES_BREATHLESS = [
  'Se quedó sin fuelle.',
  'Ya no le quedaba aire.',
  'Aletear cansa, resulta.',
  'Flapo pedía un descanso.',
];

export class DeathLines {
  private ultima = '';

  pickFor(causa: DeathCause, breathless: boolean, rng: Rng): string {
    let candidatas = LINES;
    if (breathless && LINES_BREATHLESS.length > 0) {
      candidatas = LINES_BREATHLESS;
    } else {
      const porCausa =
        causa === DeathCause.TUBERIA
          ? LINES_PIPE
          : causa === DeathCause.SUELO
            ? LINES_GROUND
            : LINES_VOID;
      if (porCausa.length > 0) candidatas = porCausa;
    }
    const frase = this.elegir(candidatas, rng);
    if (frase !== '') this.ultima = frase;
    return frase;
  }

  private elegir(lista: string[], rng: Rng): string {
    if (lista.length === 0) return '';
    if (lista.length === 1) return lista[0];
    const noRepetidas = lista.filter((l) => l !== this.ultima);
    if (noRepetidas.length === 0) return lista[0];
    return noRepetidas[rng.randiRange(0, noRepetidas.length - 1)];
  }
}
