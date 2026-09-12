import './styles/main.css';
import * as C from './config/GameConfig';
import { Difficulty } from './config/GameConfig';
import { AudioDirector } from './audio/AudioDirector';
import { Game } from './core/Game';
import { Input } from './core/Input';
import { Loop } from './core/Loop';
import { GameState } from './core/types';
import { Assets } from './render/Assets';
import { Renderer } from './render/Renderer';
import { Settings } from './meta/Settings';
import { UI, type OptionsData } from './ui/UI';

const BASE = import.meta.env.BASE_URL;

function optionsData(game: Game, audio: AudioDirector): OptionsData {
  return {
    name: game.session.playerName(),
    difficulty: game.session.difficulty(),
    muted: audio.isMuted(),
    ghostHidden: Settings.isGhostHidden(),
    mirror: game.session.mirror(),
    mirrorUnlocked: game.getHighScore() >= 25,
  };
}

function shareText(game: Game): string {
  const score = game.getScore();
  const pieza = score === 1 ? '1 tubería' : `${score} tuberías`;
  const nombre = game.session.playerName();
  const reto = game.session.daily.nombre();
  if (reto !== '') {
    return nombre === '' ? `${reto}: ${score}.` : `${reto}: ${score} (${nombre}).`;
  }
  const firma = nombre === '' ? 'He' : `${nombre} ha`;
  const codigo = game.session.codigo();
  return `${firma} cruzado ${pieza} con Flapo. Código: ${codigo}`;
}

async function boot(): Promise<void> {
  const overlay = document.getElementById('overlay') as HTMLDivElement;
  overlay.innerHTML =
    '<div class="panel"><h2>Flapo</h2><p class="pixel-font" style="font-size:12px">Cargando…</p></div>';
  overlay.classList.add('is-open');

  const audio = new AudioDirector();
  await Promise.all([Assets.load(), audio.load()]);

  const stage = document.getElementById('stage') as HTMLElement;
  const canvas = document.getElementById('playfield') as HTMLCanvasElement;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('Canvas 2D no disponible');

  const input = new Input(stage);
  const game = new Game(input);
  const renderer = new Renderer(
    ctx,
    game.bird,
    game.pipeSpawner,
    game.fruitSpawner,
    game.air,
    game.buddy,
    game.ghost,
    game.ground,
    game.background,
  );

  const ui = new UI({
    onPlay: () => {
      audio.playButton();
      ui.close();
      game.startFree();
    },
    onDaily: () => {
      audio.playButton();
      ui.close();
      game.startDaily();
    },
    onCode: (codigo) => {
      audio.playButton();
      if (game.startCode(codigo)) ui.close();
      else game.showMenu(true);
    },
    onOpenOptions: () => {
      audio.playButton();
      ui.showOptions(optionsData(game, audio));
    },
    onOpenStats: () => {
      audio.playButton();
      ui.showStats(game.statsRows());
    },
    onClosePanel: () => {
      audio.playButton();
      if (game.getState() === GameState.MENU) game.showMenu();
      else if (game.getState() === GameState.PLAYING) game.setPaused(false);
    },
    onDifficulty: (modo: Difficulty) => {
      audio.playButton();
      game.session.setDifficulty(modo);
      ui.showOptions(optionsData(game, audio));
      game.refreshSidePanels();
    },
    onName: (nombre) => game.session.setPlayerName(nombre),
    onSound: () => {
      audio.toggleMuted();
      audio.playButton();
      ui.updatePauseMuted(audio.isMuted());
      if (ui.currentPanel() === 'options') ui.showOptions(optionsData(game, audio));
    },
    onGhost: () => {
      Settings.setGhostHidden(!Settings.isGhostHidden());
      audio.playButton();
      ui.showOptions(optionsData(game, audio));
    },
    onMirror: () => {
      if (game.getHighScore() < 25) return;
      game.session.setMirror(!game.session.mirror());
      audio.playButton();
      ui.showOptions(optionsData(game, audio));
    },
    onRestart: () => {
      audio.playButton();
      ui.close();
      game.restart();
    },
    onMenu: () => {
      audio.playButton();
      game.toMenu();
      game.showMenu();
    },
    onResume: () => {
      audio.playButton();
      game.setPaused(false);
    },
    onPause: () => {
      audio.playButton();
      game.setPaused(true);
    },
    onSaveReplay: () => ui.toast('Replay guardado'),
    onShare: (texto) => {
      const mensaje = texto || shareText(game);
      const nav = navigator as Navigator & { share?: (data: { text: string }) => Promise<void> };
      if (typeof nav.share === 'function') {
        void nav.share({ text: mensaje }).catch(() => {
          void navigator.clipboard?.writeText(mensaje);
          ui.toast('Copiado al portapapeles');
        });
      } else {
        void navigator.clipboard?.writeText(mensaje);
        ui.toast('Copiado al portapapeles');
      }
    },
    onCopy: (texto) => {
      void navigator.clipboard?.writeText(texto).then(
        () => ui.toast('Código copiado'),
        () => ui.toast(texto),
      );
    },
  });

  const loop = new Loop(
    (dt) => game.update(dt),
    () => game.render(),
    (realDt) => game.updateJuice(realDt),
  );

  game.attach(ui, audio, loop, renderer);
  game.initSession();
  game.showMenu();
  (window as unknown as { __flapo?: Game }).__flapo = game;

  // ------------------------------------------------------------- layout
  const layout = (): void => {
    const w = window.innerWidth;
    const h = window.innerHeight;
    // Marco proporcional: el campo nunca queda pegado a los bordes de la
    // ventana. En móvil es pequeño; en escritorio respira más.
    const frame = Math.round(Math.min(48, Math.max(12, Math.min(w, h) * 0.04)));
    document.documentElement.style.setProperty('--frame', `${frame}px`);
    const availW = Math.max(1, w - frame * 2);
    const availH = Math.max(1, h - frame * 2);
    const scaleX = availW / C.VIEWPORT_WIDTH;
    const scaleY = availH / C.VIEWPORT_HEIGHT;

    let scale: number;
    let viewH: number;
    if (scaleX <= scaleY) {
      // Manda el ancho (ventana más estrecha que el diseño): se llena todo el
      // alto y el mundo crece en vertical. Sin franjas arriba ni abajo.
      scale = Math.min(scaleX, C.MAX_WINDOW_SCALE);
      viewH = Math.max(C.VIEWPORT_HEIGHT, Math.round(availH / scale));
    } else {
      // Manda el alto: se llena el alto y sobra a los lados, que es donde van
      // los paneles. Se ajusta a escala entera si cae cerca (píxeles exactos)
      // y si no, fraccional para no dejar barras.
      let s = scaleY;
      const near = Math.round(s);
      if (Math.abs(s - near) < 0.06) s = near;
      scale = Math.min(Math.max(s, 0.5), C.MAX_WINDOW_SCALE);
      if (scale < 1) scale = scaleY;
      viewH = C.VIEWPORT_HEIGHT;
    }

    const offsetY = game.viewOffsetY(viewH);
    canvas.width = C.VIEWPORT_WIDTH;
    canvas.height = viewH;
    game.setViewport(viewH);

    const stageW = C.VIEWPORT_WIDTH * scale;
    const marginX = Math.max((availW - stageW) / 2, 0);
    ui.layout(scale, marginX, viewH, offsetY);
    game.refreshSidePanels();
  };
  layout();
  window.addEventListener('resize', layout);
  window.addEventListener('orientationchange', () => setTimeout(layout, 120));
  window.visualViewport?.addEventListener('resize', layout);

  // --------------------------------------------------------- audio y foco
  const resumeAudio = (): void => audio.resume();
  window.addEventListener('pointerdown', resumeAudio, { once: true });
  window.addEventListener('keydown', resumeAudio, { once: true });

  document.addEventListener('visibilitychange', () => {
    if (document.hidden && game.getState() === GameState.PLAYING) game.setPaused(true);
  });
  window.addEventListener('blur', () => {
    if (game.getState() === GameState.PLAYING) game.setPaused(true);
  });

  // La pausa se gestiona fuera del bucle fijo: el bucle se detiene al pausar,
  // así que P/Escape tienen que poder reanudar sin depender de él.
  window.addEventListener('keydown', (e) => {
    if (e.code !== 'KeyP' && e.code !== 'Escape') return;
    const t = e.target as HTMLElement | null;
    if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.isContentEditable)) return;
    if (game.getState() === GameState.PLAYING) game.setPaused(!game.isPaused());
  });

  // Evita el zoom por doble toque en iOS.
  document.addEventListener('dblclick', (e) => e.preventDefault(), { passive: false });

  if (import.meta.env.PROD && 'serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      void navigator.serviceWorker.register(`${BASE}sw.js`).catch(() => {});
    });
  }

  loop.start();
}

void boot();
