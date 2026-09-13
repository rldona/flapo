# ADR-0022 — Modos de dificultad: una curva, tres escalas

Fecha: 2026-09-08 · Estado: aceptada · Extiende [ADR-0018](ADR-0018-curva-de-dificultad.md) y [ADR-0005](ADR-0005-main-cablea.md)

## Contexto
T-078 pide una pantalla de inicio con selector de fácil / normal / difícil.
El juego ya tiene una curva de dificultad (ADR-0018): funciones puras de la
puntuación que interpolan entre unos valores iniciales y un tope a los 30
puntos. La pregunta era **cómo mete un selector la mano en esa curva sin
partirla en tres**.

## Opciones consideradas
1. **Tres tablas de constantes**, una por modo. Descartada: triplica el sitio
   donde tunear (T-040) y garantiza que dos de las tres se queden viejas.
2. **Desplazar el punto de partida** de la curva: fácil empieza como si
   llevaras −10 puntos, difícil como si llevaras +10. Descartada: a partir de
   los 30 puntos los tres modos convergen, y elegir "difícil" dejaría de
   servir para nada justo para quien lo elige.
3. **Escalar la curva entera** con un multiplicador por modo. Elegida.

## Decisión
Dos multiplicadores por modo, en `GameConfig`:

| Modo | Hueco | Velocidad | Hueco a 0 pts | Hueco en el tope |
|---|---|---|---|---|
| Fácil | ×1,18 | ×0,85 | 139 px | 97 px |
| Normal | ×1,0 | ×1,0 | 118 px | 82 px |
| Difícil | ×0,88 | ×1,15 | 104 px | 72 px |

Las funciones existentes (`pipe_gap_for`, `scroll_speed_for`,
`pipe_spacing_for`) ganan un segundo parámetro **con NORMAL por defecto**:
todo el código y los tests anteriores a T-078 siguen valiendo sin tocarse, y
el modo se cuela por donde ya pasaba la puntuación.

### La parte que importa: la separación escala con la velocidad
`pipe_spacing_for` se multiplica por el **mismo** factor que la velocidad, no
por el del hueco. Eso hace que el tiempo entre dos tuberías —y por tanto los
aleteos que caben— sea **idéntico en los tres modos**: 4,57 al empezar y 3,39
en el tope.

No es un detalle de implementación, es la decisión: ADR-0018 fijó que por
debajo de 3 aleteos entre tuberías el juego pasa de difícil a **injusto**. Un
modo difícil que solo subiera la velocidad daría 2,95 aleteos y cruzaría esa
línea. Escalando la separación a la vez, **la dificultad cambia el margen de
paso y el tiempo de reacción, nunca el ritmo**.

`tests/test_t078_menu.gd` comprueba las dos cosas: que ningún modo baja de 3
aleteos y que los tres dan exactamente el mismo número. Quitar el factor de
`pipe_spacing_for` pone el test en rojo con 2,95.

## El estado MENU
La máquina de ADR-0005 gana un estado por delante:

`MENU → READY → PLAYING → GAME_OVER`, con vuelta a `MENU` desde `READY` y
desde `GAME_OVER`. No se vuelve al menú jugando, y del menú no se salta
directo a jugar.

**MENU es READY con un panel encima**, no un sitio aparte: cada pieza lo trata
igual que READY, así que el mundo se ve quieto y correcto detrás del menú, y
no hay una segunda escena que mantener. Si no se hiciera así, Flapo caería
mientras el jugador lee el título.

Y en MENU el aleteo no arranca la partida: manda la UI. Un toque en cualquier
sitio de la pantalla no puede saltarse la elección de modo.

## Consecuencias
- La dificultad se guarda **al elegirla**, no al morir: cerrar el juego desde
  el propio menú no pierde la elección.
- El defecto es NORMAL, y por eso `SaveManager.get_difficulty()` no usa
  `_leer_int`: ese devuelve 0 para lo que falta, y 0 es FACIL. El juego habría
  arrancado en fácil sin que nadie lo eligiera. Lo cazó la suite existente
  (T-045 midió 137 px de separación donde el GDD dice 160).
- El modo no se puede cambiar en mitad de una partida: movería las tuberías
  que ya están en pantalla.
- El récord **deja de ser comparable entre modos**. Se acepta en v1: un
  récord por modo es más honesto pero pide una pantalla que decida cuál
  enseñar, y eso es otro ticket.
- Un selector de dificultad no estaba en "fuera de alcance en v1" (esa lista
  es skins, ranking online, anuncios, compras y modos de juego), pero se roza
  con lo último. La diferencia: esto no es un **modo de juego**, son las
  mismas reglas escaladas. El modo espejo de T-076 sí lo sería, y por eso
  necesita su propia ADR.
