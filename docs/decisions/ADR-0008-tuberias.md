# ADR-0008 — Tuberías: cuerpo, ciclo de vida y aleatoriedad

Fecha: 2026-09-07 · Estado: aceptada

## Contexto
Las tuberías son el único obstáculo del juego. Aparecen fuera de pantalla por
la derecha, cruzan a velocidad de scroll y desaparecen por la izquierda, para
siempre, muchas veces por partida. Tres decisiones: qué tipo de cuerpo son,
quién las destruye, y de dónde sale su aleatoriedad.

## Opciones

### Tipo de cuerpo
- **`Area2D`**: detecta solapamientos pero no colisiona. Flapo la atravesaría,
  y su detección de muerte (`get_slide_collision_count()`, ADR-0006) no la
  vería. Habría que añadir una segunda vía de muerte por señal de área, o sea
  dos caminos para lo mismo.
- **`StaticBody2D`**: colisiona de verdad, frena a Flapo y aparece en las
  colisiones de deslizamiento. Un único mecanismo de muerte.
- **`AnimatableBody2D`**: pensado para cuerpos que se mueven y empujan a
  otros. Aquí las tuberías no deben empujar a Flapo: si el jugador muere
  rozando una, queremos que muera, no que lo arrastren.

### Quién libera la tubería
- **Que el spawner lleve una lista** y las borre: el spawner tendría que saber
  dónde está cada tubería y cuánto mide.
- **Que cada tubería se libere sola** al salir de pantalla: sabe su posición y
  su ancho mejor que nadie.
- **`VisibleOnScreenNotifier2D`**: lo idiomático en Godot… pero depende de que
  haya cámara y render. En headless no hay ninguna de las dos, y el criterio
  de nodos huérfanos dejaría de ser comprobable (ADR-0007).

### Aleatoriedad del hueco
- **`randf_range()` global**: cómodo, pero una partida no se puede reproducir.
- **`RandomNumberGenerator` inyectado**: quien crea la tubería pasa el
  generador; sembrándolo, la misma semilla da la misma partida.

## Decisión
Dos `StaticBody2D` (arriba y abajo) bajo un `Node2D` que se mueve solo y se
libera al salir de pantalla, con el generador aleatorio inyectado.

Detalles deliberados:

- **Las formas de colisión se crean por instancia**, en `_ready()`, y no se
  guardan en el `.tscn`. Un sub-recurso guardado en una escena es **el mismo
  objeto en todas sus instancias**: cambiar el tamaño de una tubería las
  cambiaría todas. Hay un test que lo comprueba comparando RIDs.
- **Capas de colisión con nombre** en `project.godot`: Flapo en `flapo`
  (capa 2), tuberías y suelo en `obstaculos` (capa 3). Las tuberías tienen
  máscara 0: no necesitan detectar nada, solo ser detectadas.
- **`gap` y su rango son `@export` de `Pipe`**; la velocidad de scroll y la
  separación siguen en `GameConfig` porque las comparten suelo y parallax.
  Se han retirado de `GameConfig` `PIPE_GAP` y `GAP_RANGE_*`, igual que se
  hizo con la física de Flapo en T-023. Coherente con la ADR-0003.

## Consecuencias
- Un solo mecanismo de muerte para tuberías y suelo: colisión real. **T-027**
  usará `StaticBody2D` también, y **T-028** no necesitará casos especiales.
- El criterio "no quedan nodos huérfanos tras 5 minutos" se verifica de verdad
  y en 0,36 s: 18 000 ticks simulados, 188 tuberías creadas, 2 vivas al final,
  pico de 3 simultáneas, 0 huérfanos. Antes era un criterio que dependía de
  mirar el monitor con paciencia.
- Al inyectar el generador, **T-080** podrá fijar una semilla y comprobar una
  partida completa de forma determinista.
- Renunciamos a `VisibleOnScreenNotifier2D`, que es lo que recomienda la
  documentación de Godot. El motivo es concreto: no funciona sin render, y
  preferimos un criterio comprobable a un idiomatismo. Si algún día el margen
  de recorte da problemas con cámaras móviles, se revisa.
- La tubería se mueve sola en `_physics_process`. Cuando exista `PipeSpawner`
  (**T-025**) será él quien ponga `moving = false` al pasar a `GAME_OVER`;
  hoy el flag ya está expuesto y probado.
