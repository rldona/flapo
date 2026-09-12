# Arquitectura

Flapo es un port nativo a navegador del juego original en Godot. Esta nota
explica cómo está organizado el código, qué decisiones se tomaron y cómo se
mapea cada sistema del original.

## Principios

1. **Simulación, render y UI separados.** La simulación corre a paso fijo
   (1/60 s); el render se dibuja por frame con `requestAnimationFrame` y no
   altera el estado. Los menús y el HUD son DOM, no canvas.
2. **Funciones puras para las reglas.** La curva de dificultad, la fatiga, la
   confianza y el aliento son funciones puras de sus entradas. Reiniciar una
   partida no requiere código de reinicio: los valores vuelven solos.
3. **Determinismo.** Un único generador (`Rng`) sembrado por partida; ninguna
   llamada a `Math.random()` en la simulación. El azar cosmético queda fuera.
4. **Nunca reventar.** Guardado, fantasma y ajustes son tolerantes a fallos:
   datos ausentes o corruptos devuelven valores por defecto.
5. **"Call down, signal up".** El orquestador (`Game`) conoce a sus sistemas y
   los llama; los sistemas no se buscan entre sí.

## Módulos

| Ruta | Responsabilidad |
| --- | --- |
| `src/config/GameConfig.ts` | Constantes y funciones puras del juego |
| `src/config/AirConfig.ts` | Constantes de térmicas y rebufo |
| `src/core/Loop.ts` | Bucle a paso fijo con acumulador y `timeScale` (hit-stop) |
| `src/core/Rng.ts` | PRNG determinista (mulberry32) |
| `src/core/Input.ts` | Entrada unificada (toque, ratón, teclado) |
| `src/core/Game.ts` | Máquina de estados, cableado y colisiones |
| `src/core/types.ts` | Estado, causa de muerte y ayudas geométricas |
| `src/systems/Bird.ts` | Física, aliento, fatiga, planeo y jadeo |
| `src/systems/Pipe.ts` / `PipeSpawner.ts` | Tuberías y su generación |
| `src/systems/Fruit.ts` | Frutas y su generador |
| `src/systems/AirSpawner.ts` | Térmicas, hermano y rebufo |
| `src/systems/Wind.ts` | Ráfagas globales |
| `src/systems/Journey.ts` | El nido (fin del viaje) |
| `src/systems/Ghost.ts` / `GhostRecord` | Fantasma del récord |
| `src/systems/Buddy.ts` | Compañero silencioso |
| `src/systems/Effects.ts` | Efectos de fruta y escudos |
| `src/systems/Juice.ts` | Flash, sacudida y hit-stop |
| `src/systems/DeathLines.ts` | Frases según causa de muerte |
| `src/systems/Snapshot.ts` / `ReplayRecorder.ts` | Captura y replay |
| `src/systems/Ground.ts` / `Background.ts` | Suelo y parallax/escenarios |
| `src/render/Assets.ts` | Carga de sprites y tintes precocinados |
| `src/render/Renderer.ts` | Dibujo del playfield |
| `src/meta/` | Persistencia, sesión, reto diario y fantasma |
| `src/ui/UI.ts` | Menús, HUD y paneles en DOM |
| `src/audio/AudioDirector.ts` | Web Audio |
| `src/main.ts` | Arranque, layout y conexión |

## Bucle y determinismo

`Loop` acumula el tiempo real y ejecuta `update(1/60)` tantas veces como haga
falta, con un tope de pasos para evitar el *spiral of death*. El `timeScale`
permite el **hit-stop** de la muerte sin dejar de dibujar. El render recibe el
factor de interpolación.

`Rng` (mulberry32) se siembra una vez por partida y se comparte entre el
generador de tuberías, el de frutas y el viento. El escenario se deriva de la
semilla con un módulo (no con una tirada), para no desplazar la secuencia: un
adorno no puede cambiar el juego. Por eso el **reto del día** y los **códigos
compartidos** dan exactamente las mismas tuberías en cualquier navegador.

## Render y escalado

El canvas se dibuja a resolución lógica 288×(512 o más) y se escala por CSS con
`image-rendering: pixelated`. Reglas de layout:

- **Manda el ancho** (ventana más estrecha que 288:512): el alto lógico crece y
  el mundo llena la pantalla; sin franjas.
- **Manda el alto**: se llena el alto y el sobrante lateral se usa para paneles.
- **Enteros si caen cerca**, si no fraccional, para no dejar barras.
- Un **marco proporcional** (`min(48, max(12, min(w,h)×0,04))`) mantiene el
  campo separado de los bordes de la ventana.

Los sprites se cargan una vez y los tintes (tubería blandita/especial, fantasma,
compañero, jadeo) se **precuecen** en canvas offscreen. En el bucle no se crea ni
un solo canvas.

## Persistencia

| Clave | Contenido |
| --- | --- |
| `flapo.save.v1` | Récord, partidas, total, confianza, modo, espejo, nombre, marcas de reto |
| `flapo.settings.v1` | Silencio y visibilidad del fantasma |
| `flapo.ghost.v1` | Vuelo del récord (posiciones) |
| `flapo.replay.v1` | Último replay (flancos de entrada) |

Todo va a `localStorage` con lectura defensiva.

## Mapa del port (Godot → TypeScript)

| Original (GDScript) | Aquí |
| --- | --- |
| `game_config.gd` | `config/GameConfig.ts` |
| `air_config.gd` | `config/AirConfig.ts` |
| `main.gd` | `core/Game.ts` |
| `game_state.gd` | `core/types.ts` |
| `bird.gd` | `systems/Bird.ts` |
| `pipe.gd` / `pipe_spawner.gd` | `systems/Pipe.ts` / `PipeSpawner.ts` |
| `fruit.gd` / `fruit_spawner.gd` | `systems/Fruit.ts` |
| `air_spawner.gd` / `thermal.gd` / `brother.gd` / `slipstream.gd` | `systems/AirSpawner.ts` |
| `wind.gd` | `systems/Wind.ts` |
| `journey.gd` | `systems/Journey.ts` |
| `ghost.gd` / `ghost_record.gd` | `systems/Ghost.ts` + `meta/GhostRecord.ts` |
| `buddy.gd` | `systems/Buddy.ts` |
| `effects.gd` | `systems/Effects.ts` |
| `juice.gd` | `systems/Juice.ts` |
| `death_lines.gd` + `.tres` | `systems/DeathLines.ts` |
| `snapshot.gd` | `systems/Snapshot.ts` |
| `replay.gd` / `replay_recorder.gd` | `systems/ReplayRecorder.ts` |
| `ground.gd` / `background.gd` | `systems/Ground.ts` / `Background.ts` |
| `save_manager.gd` / `settings.gd` | `meta/SaveManager.ts` / `Settings.ts` |
| `game_session.gd` / `daily_challenge.gd` | `meta/GameSession.ts` / `DailyChallenge.ts` |
| `audio_director.gd` | `audio/AudioDirector.ts` |
| `hud.gd` y paneles `.tscn` | `ui/UI.ts` |
| `layout_director.gd` | cálculo de layout en `main.ts` |
| `project.godot` | `index.html` + `vite.config.ts` |

## Decisiones destacadas

- **Canvas 2D en vez de WebGL/WebGPU.** Con este número de sprites el coste es
  bajo y se gana compatibilidad y nitidez pixel-perfect. WebGPU habría sumado
  complejidad sin ganancia real.
- **Menús en DOM.** Accesibilidad, foco, teclado y responsive gratis. El original
  dibujaba `Control` de Godot a 288 px; aquí se gana con pantallas grandes.
- **Un solo RNG compartido.** Coincide con el original: dos generadores serían
  dos partidas distintas.
- **PRNG distinto a Godot.** El determinismo se garantiza dentro de la web (misma
  semilla → misma partida), no byte a byte contra el original.
- **Viewport vertical dinámico.** Replica el comportamiento del build web original
  (llenar la pantalla) y evita franjas en ventanas altas.
- **PWA con service worker.** El juego es offline por diseño; instalarlo cierra
  el círculo.

## Rendimiento

- Física fija a 60 Hz, render desacoplado.
- Sin asignaciones por frame en el camino caliente; sprites y tintes cacheados.
- Culling y limpieza de entidades fuera de pantalla.
- Bundle minimizado: ~23 KB gzip de JS, ~3 KB de CSS, ningún runtime de framework.
