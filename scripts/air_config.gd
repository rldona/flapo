class_name AirConfig
extends RefCounted
## Las constantes del aire: térmicas (T-203) y rebufo del hermano (T-204).
##
## Salen de `GameConfig` por dos motivos, y el segundo es el que importa.
##
## El barato: `GameConfig` pasó de mil líneas y el linter lo paró. El bueno: el
## aire **es un sistema con su propia regla** —lo que cambia lo que hace el
## planeo, no lo que hay que esquivar (ADR-0026)— y tenerlo junto hace que se
## lea como lo que es. El viento (T-064) se queda en `GameConfig` a propósito:
## sus funciones son parte de la curva de dificultad y dependen de ella.
##
## Es un `RefCounted` y no un autoload, como `GameConfig`: un `class_name` se
## resuelve en compilación y existe en `--check-only` y en los scripts `-s` de
## los tests (ADR-0009).

## --- Térmicas: columnas de aire ascendente (T-203) ---

## Cada cuántas tuberías sale una térmica. 5: sale a menudo para que se
## aprenda a usarla, no tanto como para que sea el modo normal de volar.
const THERMAL_INTERVAL: int = 5

## A qué puntuación empiezan a salir. Antes de eso el jugador todavía está
## aprendiendo que el planeo existe (T-200); darle un segundo uso al planeo
## antes del primero es enseñar dos cosas a la vez.
const THERMAL_MIN_SCORE: int = 8

## Aceleración hacia arriba dentro de la térmica, px/s². Es una aceleración y
## no una velocidad fija: así entrar en la columna se **siente** —tarda un
## momento en tirar— en vez de teletransportar a Flapo hacia arriba.
const THERMAL_LIFT: float = 900.0

## Tope de subida dentro de la térmica, px/s.
##
## Sin tope, planear dentro sube cada vez más rápido y Flapo se estampa contra
## el techo sin poder hacer nada. 170 es menos de la mitad de lo que sube un
## aleteo: la térmica ayuda, no vuela por ti.
const THERMAL_MAX_RISE: float = 170.0

## Tamaño de la columna, px. Estrecha y alta: es una columna, y tiene que
## poder esquivarse.
const THERMAL_SIZE := Vector2(26.0, 220.0)

## --- El hermano pasa: rebufo (T-204) ---

## Cada cuántas tuberías cruza el hermano. 9 y no 5 como las térmicas: es un
## chiste, y un chiste repetido deja de serlo.
const BROTHER_INTERVAL: int = 9

## A qué puntuación empieza a aparecer.
const BROTHER_MIN_SCORE: int = 12

## A cuánto cruza, en múltiplos de la velocidad del mundo. 2,4x: pasa
## claramente más rápido que todo lo demás, que es el chiste — él no se
## esfuerza.
const BROTHER_SPEED_MULT: float = 2.4

## Cuánto dura la estela, s.
##
## 2,0 y no más, y el número sale de la geometría, no del gusto: la estela
## mide una pantalla de ancho y se mueve con el mundo, así que tarda unos 2,4 s
## en salirse por la izquierda. Con los 3,5 s de la primera versión, el
## temporizador **no llegaba a notarse nunca** — la estela ya estaba fuera de
## pantalla cuando le tocaba caducar, y su desvanecido no lo veía nadie.
##
## Lo destapó el test al preguntar algo que parecía una tontería: no *cuándo*
## muere la estela, sino **dónde**.
const SLIPSTREAM_TIME: float = 2.0

## Alto de la estela, px. Estrecha: hay que meterse en ella a propósito.
const SLIPSTREAM_HEIGHT: float = 22.0

## A qué distancia del borde de la pantalla cruza el hermano, px.
##
## Cruza **pegado a un borde**, arriba o abajo, y no "a media pantalla lejos
## del hueco". El motivo es geométrico: los huecos se sortean entre el 20 % y
## el 80 % de la altura jugable (`Pipe.gap_center_min_ratio`), así que el
## hueco más alto posible empieza por debajo de este margen y el más bajo
## acaba por encima del de abajo. Cruzando por el borde, el hermano **nunca**
## pasa por dentro de ningún hueco — ni del siguiente ni del que venga tres
## tuberías después, que es por donde también cruza.
##
## La primera versión se apartaba del hueco de la última tubería creada y no
## valía: el hermano atraviesa media pantalla y se encuentra huecos que
## todavía no existían cuando se decidió su altura. Se midió: 62 invasiones.
const BROTHER_EDGE_MARGIN: float = 26.0
