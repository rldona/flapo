# ADR-0003 — Dónde viven las constantes de juego

Fecha: 2026-09-07 · Estado: aceptada

## Contexto
El GDD tiene una tabla de constantes (gravedad, impulso, velocidad de scroll,
separación y hueco de tuberías). Varias de ellas las necesita más de un nodo:
la velocidad de scroll la usan las tuberías, el suelo y el parallax. Si cada
escena lleva su copia, tunear el juego en la Fase 3 (**T-040**) significa
tocar N sitios y olvidarse de uno.

## Opciones
- **Hardcodear en cada script**: descartado por el enunciado del proyecto.
- **`@export` en cada nodo**: excelente para tunear en vivo desde el
  inspector, pero el valor se guarda dentro del `.tscn`; duplicado en tres
  escenas, se desincroniza.
- **Autoload `GameConfig` (Node con constantes)**: un solo símbolo global,
  disponible en cualquier script sin `get_node` ni `preload`. Coste: no se
  edita desde el inspector y cambiar un valor obliga a reiniciar la escena.
- **`Resource` (.tres) inyectado por `@export`**: lo más "correcto" de Godot,
  editable en el inspector y permite varios perfiles (fácil/difícil). Coste:
  cada escena necesita que alguien le pase el recurso, y una escena instanciada
  a mano sin el recurso peta con null.

## Decisión
Autoload `GameConfig` (`scripts/game_config.gd`) con la regla:

- **Lo compartido entre sistemas** → constante en `GameConfig`
  (`SCROLL_SPEED`, `PIPE_SPACING`, `PIPE_GAP`, umbrales de medalla…).
- **Lo que se tunea a ojo dentro de un nodo** → `@export` en ese nodo, con el
  valor de `GameConfig` como punto de partida documentado.
- **Lo derivado** → función, no constante suelta. `pipe_spawn_interval()` es
  `PIPE_SPACING / SCROLL_SPEED`: así no se pueden desincronizar.

Durante la Fase 2 las constantes de Flapo (`GRAVITY`, `FLAP_IMPULSE`) viven en
`GameConfig`. En **T-023** se promueven a `@export` del nodo `Bird` para poder
tunearlas en caliente en **T-040**, y los valores finales vuelven a la tabla
del GDD al cerrar la Fase 3.

## Consecuencias
- Un solo sitio que leer para saber cómo está configurado el juego, y que
  cuadra 1:1 con la tabla del GDD.
- El autoload se carga también en el editor, así que las herramientas y los
  tests headless (**T-080**) lo tienen disponible sin montar nada.
- No se puede tunear desde el inspector: para iterar hay que editar el `.gd`
  y volver a lanzar. Aceptable porque lo que de verdad se itera acaba en
  `@export`.
- `GameConfig` debe quedarse siendo datos. En cuanto tenga estado de partida
  (puntuación, récord) deja de ser configuración: eso irá a `SaveManager`
  (**T-070**) y a la máquina de estados de `Main` (**T-022**).
