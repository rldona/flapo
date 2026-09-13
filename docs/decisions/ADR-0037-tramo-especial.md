# ADR-0037 — El tramo especial celebra, no examina

Fecha: 2026-09-08 · Estado: aceptada · Depende de [ADR-0023](ADR-0023-tuberias-moviles.md) y [ADR-0018](ADR-0018-curva-de-dificultad.md)

> **Nota de numeración.** T-067 pedía ADR-0024, pero ese número lo ocupó T-057
> (variantes de escenario) en esta misma tanda. Toma el siguiente libre. El
> desfase de numeración lleva arrastrándose desde ADR-0033 y necesita una
> decisión tuya, no mía.

## Contexto
La Ola 2 metió tres variantes de tubería —móvil (T-063), giratoria (T-065) y
blandita (T-066)— y cada una sale por su cuenta con una probabilidad que crece
con la puntuación (ADR-0023). Nunca coinciden a propósito: dos gimmicks a la
vez en mitad de la curva se leen como que el juego te la está jugando.

T-067 quiere justo eso que en cualquier otro momento sería injusto: **las tres
a la vez**. La pregunta que contesta esta ADR es por qué aquí sí.

## Decisión
Al superar el récord, las siguientes cuatro tuberías salen **móviles,
giratorias y teñidas de dorado**, con una blandita en el medio. Y, sobre todo:

> **La curva de dificultad se congela mientras dura el tramo.**

El hueco no se estrecha y el mundo no acelera. Esa línea es la ADR entera.

## Por qué aquí sí y en cualquier otro momento no
Combinar gimmicks se siente injusto cuando **te cuesta algo**. En mitad de una
partida normal, una tubería que se mueve y gira a la vez es una que te mata
por un motivo que no viste venir, y el jugador no lo lee como dificultad: lo
lee como trampa.

Aquí no cuesta nada, y por eso funciona. El jugador acaba de batir su récord:
está en el punto de la partida en el que todo lo que venga es ganancia. Y la
dificultad congelada garantiza que el tramo **es exactamente igual de difícil
que la tubería anterior**, solo que suena la banda.

Sin la congelación, el premio por batir tu récord sería que el juego se ponga
más difícil justo ahí. Eso es lo contrario de una celebración, y es lo que
habría pasado por defecto: la curva sube con la puntuación (ADR-0018) y el
tramo empieza precisamente cuando la puntuación acaba de subir.

Congelar tiene un límite: al acabar el tramo la curva **retoma donde le
tocaba**. Cuatro tuberías de tregua, no un descuento para el resto de la
partida. El test lo comprueba.

## Una vez por partida
Repetirlo en cada punto por encima del récord lo convertiría en el juego
normal a partir de ahí: el tramo dejaría de significar nada justo cuando el
jugador está mejor que nunca.

Y con récord 0 no se dispara. En la primera partida todo es récord, y celebrar
la primera tubería de alguien que todavía no sabe cruzar un hueco no celebra
nada.

## El tramo tiene guion, no dados
Ni una sola de las cuatro tuberías se sortea: móvil y giratoria siempre, la
del medio blandita, todas con el mismo desfase de oscilación para que se muevan
a la vez y se lea como **un tramo** y no como cuatro tuberías raras seguidas.

Eso no es solo estética. **El tramo no le pide un número al generador**, y no
puede pedírselo: si lo hiciera, la secuencia de tuberías se movería según
quién batiera su récord y cuándo. Dos jugadores con el mismo código de T-242
tendrían partidas distintas, y el replay de T-261 dejaría de cuadrar en cuanto
el récord del que reproduce no fuera el del que grabó. Un premio no puede
cambiar el mundo que premia.

## La blandita del medio
Un tramo de celebración con red debajo. Si el jugador se estrella justo en el
momento de su récord, el juego le ha tendido una trampa disfrazada de premio.

Cuando una tubería es especial **y** blandita, se pinta de blandita: lo que el
jugador necesita saber en ese instante no es que está en un tramo bonito, es
que esa no le mata.

## Consecuencias
- El tramo dura `SPECIAL_STRETCH_PIPES` (4) y su color es
  `SPECIAL_PIPE_TINT`. Alargarlo es cambiar un número.
- `Main` gana dos variables de partida (`_tramo_usado`, `_tramo_score`) y
  ningún método público más que el que usan los tests.
- El dorado no choca con nada: la blandita es verde y la normal no se tiñe.
