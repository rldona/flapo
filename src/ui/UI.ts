import * as C from '../config/GameConfig';
import { Difficulty, type Medal } from '../config/GameConfig';
import { Assets } from '../render/Assets';

export interface MenuData {
  highScore: number;
  journeyCompleted: boolean;
  dailyName: string;
  dailyBest: number;
  hasCodeError: boolean;
}

export interface GameOverData {
  score: number;
  highScore: number;
  isRecord: boolean;
  medal: Medal;
  line: string;
  playerName: string;
  challenge: string;
  code: string;
  canShare: boolean;
  muted: boolean;
}

export interface OptionsData {
  name: string;
  difficulty: Difficulty;
  muted: boolean;
  ghostHidden: boolean;
  mirror: boolean;
  mirrorUnlocked: boolean;
}

export interface UICallbacks {
  onPlay(): void;
  onDaily(): void;
  onCode(codigo: string): void;
  onOpenOptions(): void;
  onOpenStats(): void;
  onClosePanel(): void;
  onDifficulty(modo: Difficulty): void;
  onName(nombre: string): void;
  onSound(): void;
  onGhost(): void;
  onMirror(): void;
  onRestart(): void;
  onMenu(): void;
  onResume(): void;
  onPause(): void;
  onSaveReplay(): void;
  onShare(text: string): void;
  onCopy(text: string): void;
}

const BASE = import.meta.env.BASE_URL;

function esc(texto: string): string {
  return texto
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/**
 * Toda la interfaz en DOM real: menús responsivos, accesibles y navegables por
 * teclado, en lugar de dibujar paneles en el canvas a 288 px.
 */
export class UI {
  private overlay = document.getElementById('overlay') as HTMLDivElement;
  private app = document.getElementById('app') as HTMLDivElement;
  private stage = document.getElementById('stage') as HTMLDivElement;
  private sideLeft = document.getElementById('side-left') as HTMLDivElement;
  private sideRight = document.getElementById('side-right') as HTMLDivElement;
  private flashEl = document.getElementById('flash') as HTMLDivElement;
  private fadeEl = document.getElementById('fade') as HTMLDivElement;
  private pauseButton = document.getElementById('pause-button') as HTMLButtonElement;

  private hud = document.getElementById('hud') as HTMLDivElement;
  private hudScore = document.getElementById('hud-score') as HTMLDivElement;
  private hudEffect = document.getElementById('hud-effect') as HTMLDivElement;
  private hudShield = document.getElementById('hud-shield') as HTMLDivElement;
  private hudWind = document.getElementById('hud-wind') as HTMLDivElement;
  private hudJourney = document.getElementById('hud-journey') as HTMLDivElement;
  private hudBreath = document.getElementById('hud-breath-fill') as HTMLDivElement;
  private glideHint = document.getElementById('glide-hint') as HTMLDivElement;

  private toastTimer = 0;
  private panel: 'menu' | 'options' | 'stats' | 'pause' | 'gameover' | null = null;

  constructor(private readonly cb: UICallbacks) {
    this.pauseButton.addEventListener('click', () => this.cb.onPause());
  }

  // ---------------------------------------------------------------- layout
  layout(scale: number, marginX: number, viewH: number, offsetY: number): void {
    document.documentElement.style.setProperty('--scale', String(scale));
    document.documentElement.style.setProperty('--u', `${scale}px`);
    const sideW = Math.max(0, Math.min(marginX - 24, 280));
    document.documentElement.style.setProperty('--side-w', `${sideW}px`);
    // Los paneles se enseñan en cuanto hay hueco de verdad a los lados, sin
    // exigir una escala mínima: con el marco, la escala baja y se ocultaban.
    this.app.classList.toggle(
      'has-sides',
      sideW >= 150 && window.innerWidth > window.innerHeight,
    );
    this.stage.style.width = `${C.VIEWPORT_WIDTH * scale}px`;
    this.stage.style.height = `${viewH * scale}px`;
    // El HUD se ancla a la banda jugable, no al borde del viewport, para que
    // el cielo/suelo extra no lo deje flotando lejos del juego.
    const top = (offsetY + 24) * scale;
    const topSm = (offsetY + 8) * scale;
    const bottom = (offsetY + 8) * scale;
    const root = document.documentElement.style;
    root.setProperty('--hud-top', `${top}px`);
    root.setProperty('--hud-top-sm', `${topSm}px`);
    root.setProperty('--hud-bottom', `${bottom}px`);
  }

  setSky(color: string): void {
    this.app.style.background = `radial-gradient(120% 90% at 50% 0%, ${color} 0%, ${shade(color, -0.08)} 55%, ${shade(color, -0.3)} 100%)`;
    this.fadeEl.style.background = color;
  }

  updateSides(rows: Array<[string, string]>, stageName: string, variantName: string): void {
    this.sideLeft.innerHTML = `
      <div class="panel-mini">
        <img class="logo-mini" src="${BASE}sprites/logo.png" alt="Flapo" />
        <div class="stat-row"><span>Récord</span><b>${rows[0]?.[1] ?? '0'}</b></div>
        <div class="stat-row"><span>Partidas</span><b>${rows[1]?.[1] ?? '0'}</b></div>
        <div class="stat-row"><span>Medalla</span><b>${rows[2]?.[1] ?? '—'}</b></div>
      </div>`;
    this.sideRight.innerHTML = `
      <div class="panel-mini">
        <h2>Sitio</h2>
        <div class="stat-row"><span>Tramo</span><b>${esc(stageName)}</b></div>
        <div class="stat-row"><span>Cielo</span><b>${esc(variantName)}</b></div>
      </div>
      <div class="panel-mini">
        <h2>Controles</h2>
        <div class="keys">
          <kbd>TOQUE</kbd><span>aletea</span>
          <kbd>MANTÉN</kbd><span>planea</span>
          <kbd>P</kbd><span>pausa</span>
          <kbd>R</kbd><span>reinicia</span>
        </div>
      </div>`;
  }

  // ------------------------------------------------------------------ HUD
  setHudVisible(v: boolean): void {
    this.hud.classList.toggle('is-hidden', !v);
    this.pauseButton.classList.toggle('is-hidden', !v);
  }

  setScore(score: number): void {
    this.hudScore.textContent = String(score);
  }

  setEffects(lineas: string[]): void {
    this.hudEffect.textContent = lineas.join(' · ');
    this.hudEffect.style.visibility = lineas.length > 0 ? 'visible' : 'hidden';
  }

  setShield(cantidad: number): void {
    if (cantidad <= 0) {
      this.hudShield.textContent = '';
      this.hudShield.style.visibility = 'hidden';
      return;
    }
    this.hudShield.textContent = cantidad > 1 ? `Escudo x${cantidad}` : 'Escudo';
    this.hudShield.style.visibility = 'visible';
  }

  setWind(fase: 'aviso' | 'sopla' | '', aFavor: boolean): void {
    if (fase === '') {
      this.hudWind.style.visibility = 'hidden';
      return;
    }
    const flecha = aFavor ? '»»' : '««';
    this.hudWind.textContent =
      fase === 'aviso' ? `${flecha} viento ${flecha}` : `${flecha} ${flecha} ${flecha}`;
    this.hudWind.style.color = fase === 'aviso' ? C.SPECIAL_PIPE_TINT : '#FFF4D6';
    this.hudWind.style.visibility = 'visible';
  }

  setJourney(texto: string): void {
    this.hudJourney.textContent = texto;
    this.hudJourney.style.visibility = texto !== '' ? 'visible' : 'hidden';
  }

  setBreath(actual: number, maximo: number, fatigued: boolean): void {
    const ratio = maximo > 0 ? Math.max(0, Math.min(actual / maximo, 1)) : 0;
    this.hudBreath.style.width = `${ratio * 100}%`;
    this.hudBreath.classList.toggle('is-fatigued', fatigued);
    this.hudBreath.classList.toggle('is-low', actual / maximo < C.BREATH_LOW_RATIO);
  }

  setGlideHint(modo: '' | 'pictograma' | 'aviso'): void {
    if (modo === '') {
      this.glideHint.classList.add('is-hidden');
      return;
    }
    this.glideHint.textContent =
      modo === 'pictograma' ? 'Mantén pulsado\npara planear' : 'Mantén pulsado para planear';
    this.glideHint.classList.remove('is-hidden');
  }

  flash(alpha: number): void {
    this.flashEl.style.opacity = String(alpha);
  }

  fade(alpha: number): void {
    this.fadeEl.style.opacity = String(alpha);
  }

  // --------------------------------------------------------------- paneles
  private open(html: string, kind: NonNullable<UI['panel']>): void {
    this.overlay.innerHTML = html;
    this.overlay.classList.add('is-open');
    this.panel = kind;
    const first = this.overlay.querySelector<HTMLElement>('[data-autofocus]');
    first?.focus();
  }

  close(): void {
    this.overlay.classList.remove('is-open');
    this.overlay.innerHTML = '';
    this.panel = null;
  }

  currentPanel(): UI['panel'] {
    return this.panel;
  }

  showMenu(d: MenuData): void {
    const nido = d.journeyCompleted ? '🪹 ' : '';
    const dailyLabel =
      d.dailyBest > 0 ? `Reto del día · mejor ${d.dailyBest}` : `${d.dailyName || 'Reto del día'}`;
    this.open(
      `
      <div class="panel" role="dialog" aria-label="Menú principal">
        <img class="logo" src="${BASE}sprites/logo.png" alt="Flapo" />
        <p class="record">${nido}Récord: ${d.highScore}</p>
        <div class="buttons">
          <button class="btn primary" data-act="play" data-autofocus>Jugar</button>
          <button class="btn" data-act="daily">${esc(dailyLabel)}</button>
        </div>
        <div class="row">
          <input class="code-input" id="code-input" maxlength="${C.CODIGO_LARGO}" inputmode="text"
            autocomplete="off" spellcheck="false" placeholder="código" aria-label="Código de partida" />
          <button class="btn" data-act="code">Ir</button>
        </div>
        <p class="aviso" id="menu-aviso">${d.hasCodeError ? 'Ese código no vale' : ''}</p>
        <div class="buttons cols-2">
          <button class="btn ghost" data-act="options">Opciones</button>
          <button class="btn ghost" data-act="stats">Estadísticas</button>
        </div>
        <p class="hint">Toca la pantalla para aletear. Mantén pulsado para planear.</p>
      </div>`,
      'menu',
    );
    const input = document.getElementById('code-input') as HTMLInputElement | null;
    input?.addEventListener('input', () => {
      input.value = input.value.toLowerCase().replace(/[^0-9a-z]/g, '');
      const aviso = document.getElementById('menu-aviso');
      if (aviso) aviso.textContent = '';
    });
    input?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') this.cb.onCode(input.value);
      e.stopPropagation();
    });
    this.wire();
  }

  showOptions(d: OptionsData): void {
    const diffs: Array<[Difficulty, string]> = [
      [Difficulty.FACIL, 'Fácil'],
      [Difficulty.NORMAL, 'Normal'],
      [Difficulty.DIFICIL, 'Difícil'],
    ];
    const seg = diffs
      .map(
        ([v, label]) =>
          `<button class="btn" data-act="diff" data-value="${v}" aria-pressed="${v === d.difficulty}">${label}</button>`,
      )
      .join('');
    this.open(
      `
      <div class="panel" role="dialog" aria-label="Opciones">
        <h2>Opciones</h2>
        <label class="muted" for="name-input">Tu nombre</label>
        <input class="input" id="name-input" maxlength="${C.PLAYER_NAME_MAX_LEN}"
          value="${esc(d.name)}" placeholder="Flapo" autocomplete="off" />
        <p class="muted" style="margin-top:14px">Dificultad</p>
        <div class="seg">${seg}</div>
        <div class="toggle-row"><span>Sonido</span>
          <button class="btn toggle" data-act="sound">${d.muted ? 'Apagado' : 'Activado'}</button></div>
        <div class="toggle-row"><span>Fantasma del récord</span>
          <button class="btn toggle" data-act="ghost">${d.ghostHidden ? 'Oculto' : 'Visible'}</button></div>
        ${
          d.mirrorUnlocked
            ? `<div class="toggle-row"><span>Modo espejo</span>
                <button class="btn toggle" data-act="mirror">${d.mirror ? 'Sí' : 'No'}</button></div>`
            : ''
        }
        <div class="buttons">
          <button class="btn primary" data-act="close" data-autofocus>Volver</button>
        </div>
      </div>`,
      'options',
    );
    const name = document.getElementById('name-input') as HTMLInputElement | null;
    name?.addEventListener('input', () => this.cb.onName(name.value));
    name?.addEventListener('keydown', (e) => e.stopPropagation());
    this.wire();
  }

  showStats(rows: Array<[string, string]>): void {
    const body = rows
      .map(([k, v]) => `<div class="stat-row"><span>${esc(k)}</span><b>${esc(v)}</b></div>`)
      .join('');
    this.open(
      `
      <div class="panel" role="dialog" aria-label="Estadísticas">
        <h2>Estadísticas</h2>
        <div class="stat-list">${body}</div>
        <div class="buttons">
          <button class="btn primary" data-act="close" data-autofocus>Volver</button>
        </div>
      </div>`,
      'stats',
    );
    this.wire();
  }

  showPause(muted: boolean): void {
    this.open(
      `
      <div class="panel" role="dialog" aria-label="Pausa">
        <h2>Pausa</h2>
        <div class="buttons">
          <button class="btn primary" data-act="resume" data-autofocus>Continuar</button>
          <button class="btn" data-act="sound">Sonido: ${muted ? 'apagado' : 'activado'}</button>
          <button class="btn" data-act="save-replay">Guardar replay</button>
          <button class="btn" data-act="restart">Reiniciar</button>
          <button class="btn ghost" data-act="menu">Menú</button>
        </div>
      </div>`,
      'pause',
    );
    this.wire();
  }

  updatePauseMuted(muted: boolean): void {
    const btn = this.overlay.querySelector('[data-act="sound"]');
    if (btn && this.panel === 'pause') {
      btn.textContent = `Sonido: ${muted ? 'apagado' : 'activado'}`;
    }
  }

  showGameOver(d: GameOverData): void {
    const medalImg =
      d.medal !== C.Medal.NINGUNA
        ? `<img class="medal" src="${BASE}sprites/${C.medalTextureName(d.medal)}.png" alt="${C.medalName(d.medal)}" />
           <p class="muted">${C.medalName(d.medal)}</p>`
        : '';
    const code = d.code !== '' ? `<div class="code-badge" data-act="copy" title="Copiar código">${esc(d.code)}</div>` : '';
    this.open(
      `
      <div class="panel" role="dialog" aria-label="Fin de la partida">
        <h1>${esc(d.line || 'Otra vez')}</h1>
        ${medalImg}
        <p style="font-size:34px;margin:2px 0">${d.score}</p>
        <p class="record">Récord ${d.highScore}</p>
        ${d.isRecord ? '<span class="new-record">¡Nuevo récord!</span>' : ''}
        ${code}
        <div class="buttons">
          <button class="btn primary" data-act="restart" data-autofocus>Otra vez</button>
          ${d.canShare ? '<button class="btn" data-act="share">Compartir</button>' : ''}
          <button class="btn ghost" data-act="menu">Menú</button>
        </div>
        <p class="hint">Pulsa R o Espacio para volver a intentarlo.</p>
      </div>`,
      'gameover',
    );
    this.wire();
    void d.playerName;
    void d.challenge;
  }

  toast(texto: string): void {
    let el = document.querySelector('.toast') as HTMLDivElement | null;
    if (!el) {
      el = document.createElement('div');
      el.className = 'toast';
      document.body.appendChild(el);
    }
    el.textContent = texto;
    el.classList.add('is-visible');
    window.clearTimeout(this.toastTimer);
    this.toastTimer = window.setTimeout(() => el?.classList.remove('is-visible'), 1800);
  }

  private wire(): void {
    this.overlay.querySelectorAll<HTMLElement>('[data-act]').forEach((el) => {
      el.addEventListener('click', () => {
        const act = el.dataset.act;
        if (act === 'play') this.cb.onPlay();
        else if (act === 'daily') this.cb.onDaily();
        else if (act === 'code') {
          const input = document.getElementById('code-input') as HTMLInputElement | null;
          this.cb.onCode(input?.value ?? '');
        } else if (act === 'options') this.cb.onOpenOptions();
        else if (act === 'stats') this.cb.onOpenStats();
        else if (act === 'close') this.cb.onClosePanel();
        else if (act === 'diff') this.cb.onDifficulty(Number(el.dataset.value) as Difficulty);
        else if (act === 'sound') this.cb.onSound();
        else if (act === 'ghost') this.cb.onGhost();
        else if (act === 'mirror') this.cb.onMirror();
        else if (act === 'restart') this.cb.onRestart();
        else if (act === 'menu') this.cb.onMenu();
        else if (act === 'resume') this.cb.onResume();
        else if (act === 'save-replay') this.cb.onSaveReplay();
        else if (act === 'share') this.cb.onShare('');
        else if (act === 'copy') {
          const code = document.querySelector('.code-badge')?.textContent ?? '';
          this.cb.onCopy(code);
        }
      });
    });
    // Evita que las pulsaciones del panel lleguen al playfield.
    this.overlay.querySelectorAll('button, input').forEach((el) => {
      el.addEventListener('pointerdown', (e) => e.stopPropagation());
    });
  }
}

function shade(hex: string, amount: number): string {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex);
  if (!m) return hex;
  const n = parseInt(m[1], 16);
  let r = (n >> 16) & 255;
  let g = (n >> 8) & 255;
  let b = n & 255;
  const f = (c: number) => Math.max(0, Math.min(255, Math.round(c + (amount < 0 ? c * amount : (255 - c) * amount))));
  r = f(r);
  g = f(g);
  b = f(b);
  return `rgb(${r},${g},${b})`;
}

void Assets;
