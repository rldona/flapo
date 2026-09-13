# ADR-0004 — Gestión de la entrada: acciones del InputMap

Fecha: 2026-09-07 · Estado: aceptada

## Contexto
Flapo se juega con un solo botón, pero ese botón es tres cosas distintas
según la plataforma: un toque en Android, un click en la web de escritorio y
la barra espaciadora en PC. Además hacen falta `restart` y `pause`.

Si el código pregunta por teclas (`Input.is_key_pressed(KEY_SPACE)`), añadir
soporte de móvil obliga a tocar todos los sitios donde se lee la entrada, y
no hay un único lugar donde ver qué controla el juego.

## Opciones
- **Leer teclas y botones directamente** en cada script: descartado. Es lo que
  el criterio de aceptación de T-021 prohíbe explícitamente.
- **Acciones del InputMap**: el motor traduce eventos físicos a nombres
  semánticos. El código pregunta `Input.is_action_just_pressed("flap")` y le
  da igual de dónde venga. Remapear es cambiar `project.godot`, no código.

## Decisión
Tres acciones en `project.godot`:

| Acción | Eventos |
|---|---|
| `flap` | click izquierdo · toque de pantalla · Espacio |
| `restart` | R · Intro |
| `pause` | Escape · P |

`input_devices/pointing/emulate_mouse_from_touch = true` (valor por defecto,
lo dejamos escrito explícitamente porque de él depende que la UI funcione).

Se usan **`physical_keycode`** y no `keycode`: el físico va por posición en el
teclado, así que la tecla bajo el pulgar sigue siendo la misma en QWERTY,
AZERTY o Dvorak. Para un juego de acción es lo correcto; `keycode` solo
importa cuando la letra en sí tiene significado.

`restart` **no** incluye `flap`. Al morir, el jugador suele estar aporreando
el botón; si Espacio reiniciara, la partida arrancaría sola antes de que
pueda leer la puntuación. La protección va en dos capas: teclas distintas
aquí, y el retardo de 0,5 s antes del panel de Game Over (**T-044**).

## Consecuencias
- Ningún script consultará teclas: solo `Input.is_action_just_pressed(...)` y
  `event.is_action_pressed(...)`. Es revisable con un `grep` de `KEY_` y
  `MOUSE_BUTTON_` sobre `scripts/`.
- **Doble evento en móvil**: con la emulación activada, un toque genera el
  `InputEventScreenTouch` *y* un `InputEventMouseButton` sintético, y los dos
  están mapeados a `flap`. No causa doble aleteo: `Input` colapsa ambos en un
  único estado de acción, y `is_action_just_pressed()` solo es verdadero en el
  primer frame. Se deja la emulación encendida porque los nodos `Control`
  (el botón "Otra vez" de **T-071**) la necesitan para responder al dedo.
  Si alguna vez se observara doble disparo, la solución es quitar el evento de
  touch de la acción, no apagar la emulación.
- `restart` y `pause` son solo de teclado: en Android no hay teclas. En móvil
  el reinicio se hace con el botón de la pantalla de Game Over (**T-071**) y
  la pausa la dispara el sistema al perder el foco (**T-072**). Las acciones
  siguen siendo el punto de entrada; solo cambia quién las emite.
- Godot borra de `project.godot` los ajustes que coinciden con el valor por
  defecto del motor. Por eso `window/stretch/aspect="keep"` y
  `physics/common/physics_ticks_per_second=60` no aparecen en el fichero
  aunque sean los valores que queremos (ver ADR-0002): son ya los del motor.
  Si alguna vez cambiaran de default, habría que fijarlos a mano.
