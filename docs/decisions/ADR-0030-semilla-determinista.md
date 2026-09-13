# ADR-0030 — Un solo generador: qué garantiza el determinismo y qué no

Fecha: 2026-09-08 · Estado: aceptada · Base de T-241, T-242, T-243, T-260 y T-261

## Contexto
Cinco cosas de la Ola 2 —reto del día, códigos compartibles, fantasma del
récord, bot de justicia y replays para reproducir bugs— dependen de lo mismo:
que **la misma semilla dé la misma partida**. Ninguna funciona a medias.

Hasta T-240 el juego tenía **cinco generadores sueltos** (tuberías, frutas,
viento, cámara, frases) y un `randf()` global en `fruit.gd` para la fase del
balanceo. Cada uno se sembraba solo, con `randomize()`.

## Decisión 1 · Un generador, repartido por Main
`Main` tiene el único `RandomNumberGenerator` de la partida y lo **inyecta**
en el spawner de tuberías, el de frutas y el viento. Se comparte, no se
copia: si cada sistema tuviera el suyo sembrado con la misma semilla, la
partida dependería del orden en que cada uno pidiera números, que es un
detalle de implementación y no una regla del juego.

`Fruit` ya no sortea su fase: se la da el spawner. Era el único sitio que se
saltaba el determinismo **sin que se notara** — dos partidas con la misma
semilla tenían las mismas frutas en el mismo sitio, flotando en distinto
punto del seno.

## Decisión 2 · Lo cosmético se queda fuera, a propósito
La sacudida de cámara (`juice.gd`) y las frases al morir tienen su propio
generador y **no** entran en el de la partida.

No es dejadez: es la frontera. Si entraran, ver un flash o leer una frase
consumiría números del mismo generador que decide dónde va la siguiente
tubería, y entonces **el aspecto del juego afectaría a su simulación**. Un
replay grabado con el sonido puesto no se reproduciría con el sonido quitado.

La regla, y lo que comprueba el test: toda llamada aleatoria en `scripts/`
sale de una variable llamada `rng`. Lo que no menciona ninguna es
aleatoriedad global, y no queda ninguna.

## Decisión 3 · Se siembra al entrar en READY, no en `_ready()`
Sembrar al arrancar el juego habría hecho que **reiniciar diera una partida
distinta**, y entonces el determinismo no serviría para nada: el caso de uso
principal es repetir la misma partida.

Con semilla 0 se sortea una y **se guarda**: la partida libre sigue siendo
distinta cada vez, pero se puede leer qué semilla tocó. Eso es lo que hará
posible T-242 (compartir el código de la partida que acabas de jugar).

## Qué garantiza y qué NO
**Garantiza**: con la misma semilla, la secuencia de tuberías —altura del
hueco, si es móvil, giratoria o blandita— y la de frutas es idéntica. Y con
la misma semilla desde un arranque limpio, la partida es idéntica **frame a
frame**, incluidas las posiciones.

**No garantiza**:

- **Que sobreviva a cambiar `GameConfig`.** Tocar una constante cambia la
  partida aunque la semilla sea la misma. Un replay es válido para la
  versión del juego en que se grabó, y nada más.
- **Que la posición exacta sobreviva a reiniciar a media sesión.** El
  generador sí se reinicia igual, pero el frame en que arranca `PLAYING`
  puede caer en otra alineación entre el bucle de física y el de dibujo, y
  eso desplaza las tuberías. Medido: **1,67 px, justo un frame de scroll a
  100 px/s**. Por eso el test de reinicio compara la *secuencia generada* y
  no la x frame a frame: la secuencia es lo que la semilla determina.

Ese matiz importa para T-261: un replay tiene que grabar el frame de inicio,
no solo la semilla.

## Un bug que casi se cuela, y por qué el test lo cazó
La primera versión hacía `_rng.seed = _seed` y **además** `_rng.state = 0`.
Asignar `seed` ya reinicia el estado; poner `state = 0` a mano dejaba el
generador en un estado degenerado que devolvía **la misma secuencia con
cualquier semilla**.

Lo peor es que el test de "misma semilla, misma partida" **pasaba**: pasaba
porque todas las partidas eran iguales. Lo que lo destapó fue el caso
contrario, "semillas distintas dan partidas distintas". Sin ese caso, el
ticket se habría dado por hecho con el determinismo roto del todo.

## Consecuencias
- `random_seed` sigue existiendo en los spawners para poder aislarlos en un
  test suelto. En la partida real vale 0 y manda el generador de `Main`.
- `Wind` ya no reinicia desde el setter de `enabled`: reiniciar consume
  números, y hacerlo ahí metía un consumo extra que dependía de si el viento
  estaba encendido al morir. Dos partidas con la misma semilla dejaban de
  coincidir según lo que hubieras puntuado en la anterior.
- Cualquier sistema nuevo con azar (térmicas T-203, hermano T-204) **tiene
  que recibir el generador**, no crear el suyo. El test lo detecta solo.
