# ADR-0040 — Cuatro capas que siempre existen

Fecha: 2026-09-09 · Estado: aceptada · Depende de [ADR-0016](ADR-0016-arte-generado.md) y [ADR-0027](ADR-0027-fin-del-viaje.md)

## Contexto
T-222 quiere que el fondo cambie cada `JOURNEY_STAGE_SCORE` puntos: parque →
tejados → nubes → cielo abierto, con fundido y no de golpe. Convierte "cuántas
tuberías" en "hasta dónde he llegado".

Y pone un criterio que suena a detalle de implementación y no lo es: **la
transición no puede dejar capas huérfanas.**

## Decisión
Las **cuatro capas existen desde el primer frame**, dentro del mismo
`Parallax2D`, y cambiar de tramo es mover alfas.

No se instancia nada al cambiar de tramo y no se destruye nada. Por eso no
puede haber capas huérfanas: **no hay nada que pueda quedarse huérfano**. El
criterio no se cumple limpiando bien, se cumple no ensuciando.

Para que las cuatro quepan en un solo `Parallax2D` tienen que compartir
`repeat_size`, así que las cuatro miden **96 px de ancho** — el mismo que la
ciudad, que ya existía. Esa restricción es la que hace posible todo lo demás.

El coste es cuatro texturas siempre en memoria. Son 96×120 y pesan menos de
medio kilobyte cada una: el precio de no tener un ciclo de vida que gestionar.

## El fundido suma exactamente una capa
Durante la transición solo dos capas tienen alfa: la que entra a `mezcla` y la
que sale a `1 - mezcla`. Suman 1 siempre.

No es un detalle estético. Si sumaran menos, la pantalla se aclararía a mitad
de cada cambio; si sumaran más, se oscurecería. Un parpadeo cada 13 puntos, en
el momento en que el jugador está cruzando un hueco, sería un fallo grave
disfrazado de transición. El test lo comprueba con números, no mirando.

## El paisaje anuncia el final, no lo acompaña
`JOURNEY_STAGE_SCORE` es **13**, que no es redondo a propósito: cuatro tramos
de 13 ponen el cielo abierto en el punto 39, y el nido (T-209) cae en el 50,
**once puntos después**. El paisaje avisa de que queda poco antes de que
llegue, en vez de cambiar justo encima del momento importante.

## Por qué el parque no es verde
El único verde de la paleta es el de la fruta, y ese existe justo para **no**
parecer escenario (`docs/art-guide.md`, T-047). Las cuatro capas van en los
azul-grises del fondo, que además es lo correcto: es perspectiva atmosférica,
lo lejano pierde color.

Se generan con `tools/generar_arte.py` como todo lo demás (ADR-0016): si
cambia la paleta, se regeneran.

## Función pura, como toda la curva
El tramo sale de `GameConfig.journey_stage(score)` y nada más. No hay estado
de tramo que sincronizar, y **reiniciar vuelve al parque sin código de
reinicio** porque el marcador vuelve a 0 (ADR-0018).

Aun así, el fondo se reinicia también al entrar en `READY`, y es a propósito:
volver al parque tiene que ser **instantáneo**, no un fundido de dos segundos
desde el cielo. El fundido cuenta un viaje, y al empezar no se ha viajado.

## Dos cosas que salieron de romper el test
- Un `_ready()` que repartía las alfas al arrancar era **código muerto**:
  `MENU` ya las reparte, y el juego siempre pasa por `MENU`. Se quitó al ver
  que romperlo no cambiaba nada.
- El test leía las alfas en el mismo frame del reinicio, cuando todavía son
  las de antes: daba por bueno un reinicio que no reiniciaba. Ahora deja pasar
  un frame.
