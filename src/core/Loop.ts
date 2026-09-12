/**
 * Bucle de juego a paso fijo de 60 Hz con acumulador, igual que la física de
 * Godot (ADR-0002): las constantes en px/s significan siempre lo mismo pase lo
 * que pase con los fps.
 *
 * El render puede ocurrir más o menos veces que la simulación, y recibe el
 * factor de interpolación por si un día se quiere suavizar. El `timeScale`
 * permite el hit-stop de la muerte (T-042) sin parar el dibujado.
 */
export class Loop {
  readonly step = 1 / 60;
  timeScale = 1;
  paused = false;

  private acc = 0;
  private last = 0;
  private raf = 0;
  private running = false;
  private readonly maxFrame = 0.25;
  private readonly maxSteps = 5;

  constructor(
    private readonly update: (dt: number) => void,
    private readonly render: (alpha: number) => void,
    private readonly onFrame: (realDt: number) => void = () => {},
  ) {}

  start(): void {
    if (this.running) return;
    this.running = true;
    this.last = performance.now();
    this.acc = 0;
    this.raf = requestAnimationFrame(this.frame);
  }

  stop(): void {
    this.running = false;
    cancelAnimationFrame(this.raf);
  }

  private frame = (now: number): void => {
    if (!this.running) return;
    let dtReal = (now - this.last) / 1000;
    this.last = now;
    if (dtReal > this.maxFrame) dtReal = this.maxFrame;

    this.onFrame(dtReal);

    if (!this.paused) {
      this.acc += dtReal * this.timeScale;
      let steps = 0;
      while (this.acc >= this.step && steps < this.maxSteps) {
        this.update(this.step);
        this.acc -= this.step;
        steps++;
      }
      if (steps === this.maxSteps) this.acc = 0;
    }

    this.render(this.paused ? 0 : this.acc / this.step);
    this.raf = requestAnimationFrame(this.frame);
  };
}
