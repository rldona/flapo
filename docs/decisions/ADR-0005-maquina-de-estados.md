# ADR-0005 — Máquina de estados y comunicación entre nodos

Fecha: 2026-09-07 · Estado: aceptada

## Contexto
Flapo tiene tres estados (`READY`, `PLAYING`, `GAME_OVER`) y casi todos los
sistemas dependen de en cuál estemos: Flapo flota o cae, el spawner genera o
no genera tuberías, el parallax se mueve o se para, el HUD se muestra o se
sustituye por el panel. Sin un sitio único que mande, cada nodo acabaría con
su propio `var is_playing` y se desincronizarían.

## Opciones

### Dónde vive el estado
- **Un autoload `GameStateManager`**: accesible desde cualquier sitio sin
  cablear nada. Coste: es estado global mutable — cualquiera puede cambiarlo
  desde cualquier parte, y sobrevive entre escenas, así que al reiniciar
  (**T-028**) hay que acordarse de resetearlo a mano.
- **En `Main`**: el estado nace y muere con la escena de partida. Recargar la
  escena lo reinicia solo. Coste: los hijos necesitan que alguien les conecte.
- **Un nodo `StateMachine` con un nodo por estado**: el patrón "de libro",
  útil cuando cada estado tiene lógica gorda y propia. Para tres estados sin
  comportamiento propio es andamiaje sin retorno.

### Cómo se enteran los demás nodos
- **Que cada hijo haga `get_parent().state_changed.connect(...)`**: acopla al
  hijo con su posición en el árbol; `Bird.tscn` deja de poder abrirse suelto.
- **Que `Main` conecte a sus hijos en `_ready()`**: "call down, signal up",
  la recomendación oficial de Godot. El hijo solo expone métodos y señales.

### Dónde vive el enum
- **Dentro de `main.gd`**: obliga a `class_name Main` y a que `Bird` escriba
  `Main.GameState`, o sea a que el hijo conozca el tipo del padre.
- **En `GameConfig`**: lo prohíbe la ADR-0003 — ahí solo van datos de ajuste.
- **Fichero propio con `class_name GameState`**: un contenedor de tipo que no
  se instancia nunca (`RefCounted`).

## Decisión
Estado en `Main` (`scripts/main.gd`), enum en `scripts/game_state.gd`
(`GameState.State`), y comunicación con "call down, signal up".

Dos detalles deliberados:

- **Tabla de transiciones** (`_TRANSITIONS`) en vez de `if` repartidos. Solo
  son legales `READY→PLAYING`, `PLAYING→GAME_OVER` y `GAME_OVER→READY`.
  Un intento ilegal emite `push_warning` y no hace nada, en lugar de dejar el
  juego en un estado imposible. Muere-dos-veces es el bug clásico aquí.
- **`state_changed` se emite después** de actualizar `_state`, y `Main`
  anuncia también el estado inicial en `_ready()`. Así ningún nodo tiene que
  suponer en qué estado arranca el mundo. Funciona porque en Godot `_ready()`
  corre de abajo arriba: los hijos ya están listos cuando corre el del padre.
- **`_unhandled_input` y no `_input`**: la UI se queda primero con el evento.
  Cuando exista el botón "Otra vez" (**T-071**), pulsarlo no disparará además
  un aleteo.

## Consecuencias
- Recargar la escena reinicia el estado sin código de limpieza: es lo que
  hace viable el criterio de **T-028** (reiniciar 50 veces sin acumular nada).
- A partir de **T-023**, `Main` declarará referencias a sus hijos con
  `@export` (asignadas en el editor, no con rutas de texto) y las conectará
  en `_ready()`. Nada de `get_node("../../Bird")`.
- El estado no sobrevive entre escenas. Lo que sí debe persistir (récord,
  partidas jugadas) es responsabilidad de `SaveManager` (**T-070**), que sí
  será autoload.
- Si algún estado llega a tener lógica propia y larga, esta ADR se sustituye
  por otra que introduzca nodos de estado. Hoy sería sobreingeniería.
