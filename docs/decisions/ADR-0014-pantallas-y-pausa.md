# ADR-0014 — Pausa y adaptación a pantallas reales

Fecha: 2026-09-08 · Estado: aceptada

## Contexto
Flapo va a Android, donde pasan dos cosas que en el editor no: llega una
llamada y la app se va a segundo plano, y la pantalla no es 9:16 exacto ni
tiene por qué ser rectangular limpia.

## Decisión 1: pausar con `get_tree().paused`, no con un flag propio
El criterio de T-072 es "volver del segundo plano no provoca muerte
instantánea". Ese bug tiene una causa muy concreta: si se pausa con una
variable propia mientras el motor sigue corriendo, al volver el motor entrega
de golpe el `delta` acumulado de todo el rato que la app estuvo fuera, y la
gravedad estampa a Flapo contra el suelo antes de que el jugador toque nada.

`get_tree().paused = true` congela el árbol entero, física incluida, salvo lo
que declare `process_mode = ALWAYS` (el velo de pausa). Al no avanzar la
física, no hay delta que acumular. El test lo comprueba con **10 s simulados
en segundo plano**: Flapo se mueve 3 px y la partida sigue viva.

Se pausa además automáticamente con `NOTIFICATION_APPLICATION_PAUSED`
(Android) y `NOTIFICATION_WM_WINDOW_FOCUS_OUT` (escritorio y web).

Solo se puede pausar **jugando**: en `READY` o con el panel de muerte delante
no significa nada y complica el reinicio. Y `restart()` despausa siempre,
aunque hoy ese camino no sea alcanzable: un reinicio con el árbol pausado
dejaría el juego congelado y sin velo, es decir sin ninguna salida.

## Decisión 2: seguir con `aspect = keep`, pero sin barras negras
El criterio de T-073 pide que "el fondo cubra relaciones 16:9 a 21:9". Había
dos caminos:

- **Cambiar el modo de stretch** para que se vea más mundo en pantallas más
  altas. Suena mejor, pero rompe el diseño: `keep_height` en un móvil 20:9
  daría un viewport de **230 px de ancho en vez de 288** —se vería *menos*
  mundo, no más—, y `keep_width` daría 640 px de alto, cambiando la altura
  jugable de la que dependen el suelo (T-027), el rango del hueco (T-024) y
  los `@export` ya tuneados. Un cambio de dificultad disfrazado de ajuste de
  pantalla.
- **Mantener `keep`** (encuadre idéntico en toda pantalla, ADR-0002) y
  ocuparse de lo único que chirría: que lo que sobra sea negro.

Se elige lo segundo: `rendering/environment/defaults/default_clear_color` pasa
a ser el azul del cielo. En cualquier proporción entre 16:9 y 21:9 el marco
deja de ser un vacío negro y pasa por cielo.

## Decisión 3: el margen seguro se calcula en píxeles de juego
`DisplayServer.get_display_safe_area()` devuelve píxeles **reales** de
pantalla; el juego dibuja en 288×512 lógicos. Aplicar el recorte tal cual
metería el marcador cuarenta veces más abajo de lo que toca. La conversión
(`Hud.margen_seguro`) es `static` y está separada del nodo justo para poder
probarla con notches inventados: en headless no hay pantalla que consultar.

Con un móvil de 2400 px de alto y un notch de 100 px reales, el margen añadido
son **21,33 px de juego**.

## Consecuencias
- El HUD se recoloca solo al arrancar y al cambiar el tamaño de la ventana
  (`root.size_changed`), así que rotar el móvil o que aparezca una barra del
  sistema lo ajusta sin código extra.
- Queda pendiente lo único que no puede comprobar headless: **verlo en un
  emulador con notch**, que es literalmente el criterio de aceptación de
  T-073. Es tarea de Raúl.
- Si algún día se quisiera aprovechar el alto extra de los móviles largos,
  no es un cambio de `aspect`: hay que rediseñar la altura jugable y volver a
  tunear las constantes, y eso merece ADR propia y una vuelta de T-040.
