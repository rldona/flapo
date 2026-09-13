# ADR-0027 — Un final en un juego infinito, y por qué no es un estado

Fecha: 2026-09-09 · Estado: aceptada · Depende de [ADR-0005](ADR-0005-main-cablea.md)

## Contexto
Flappy Bird no tiene final. Nadie "se pasa" un endless runner: se juega hasta
que te cansas, y eso deja una sensación rara — mucho esfuerzo y ningún sitio
al que llegar.

T-209 propone que a 50 puntos Flapo **llegue**: las tuberías paran, hay tres
segundos de escena, una línea, y la partida sigue.

## Por qué un final aquí sí
Porque el juego ya cuenta una historia pequeña: un pájaro gordito que quiere
volar y le cuesta. Un juego así con puntuación infinita y nada más deja la
historia sin cerrar.

Y sobre todo porque **no quita nada**. El bucle infinito sigue intacto: quien
quiera seguir, sigue, con la dificultad en tope. Los 50 puntos están por
encima de la medalla de oro (40): alcanzable, pero no de casualidad.

Es lo contrario de un "modo historia", que sí estaría fuera de alcance: no hay
niveles, ni progresión, ni una segunda mitad del juego que mantener.

## Por qué no es un estado de la máquina
Sería lo primero que uno piensa: `PLAYING → ESCENA → PLAYING`. No se hace, y
es la decisión técnica del ticket.

Un quinto estado obligaría a **cada pieza del juego** a saber que existe una
pantalla en la que casi todo sigue igual. El suelo, el fondo, el HUD, el
aire, el compañero: todos escuchan `state_changed` y todos tendrían que
decidir qué hacer con un estado nuevo en el que, para ellos, no cambia nada.
Y al salir habría que garantizar que se vuelve **exactamente** al estado
anterior, que es justo el tipo de cosa que se rompe seis tickets después.

En vez de eso, la escena es **una pausa del generador de tuberías con un
cartel encima**. Se sigue en `PLAYING`. Lo que se apaga se apaga a mano y se
vuelve a encender a mano, y son tres cosas contadas:

| Se apaga | Por qué |
|---|---|
| El generador de tuberías | Para que el cielo se abra de verdad |
| El control de Flapo | Es una escena, no un tramo fácil |
| La puntuación | No hay tuberías que cruzar |

Pausar **no toca el contador de tuberías ni el generador de aleatoriedad**: al
reanudar, la partida sigue donde estaba. Es la misma idea que ya usan las
estadísticas (T-084) y las opciones (T-087): un panel encima de algo que
sigue existiendo debajo.

## Flapo no puede morir durante la escena
Tres segundos sin control con el mundo en marcha serían una trampa. Mientras
la escena dura, Flapo flota: ni gravedad, ni entrada, ni muerte. Es el mismo
comportamiento que ya tiene en `READY`, reutilizado.

## Una guarda doblemente redundante, a propósito
El nido solo puede pasar **una vez por partida**, y eso se comprueba dos
veces: que no se haya usado ya, y que la puntuación sea **exactamente** la del
nido y no "a partir de".

Es redundante y está bien que lo sea. Se verificó rompiendo cada
comprobación por separado y el comportamiento no cambiaba: la otra la tapa.
Solo rompiendo las dos a la vez el nido empieza a salir en bucle — 50
reapariciones en 51 puntos. Para un momento que solo puede ocurrir una vez en
la vida de una partida, dos cerrojos independientes es lo correcto.

## Lo que se guarda
Un `sí`, y nada más. No hay porcentaje de completado ni "veces que has
llegado": el viaje se hace una vez y lo demás es seguir jugando. El menú lo
enseña con un nido pequeño delante del récord — un símbolo y no una línea
aparte, porque quien ha llegado ya lo sabe y a quien no ha llegado no se le
anuncia lo que le falta.

Se guarda **al llegar**, no al morir: quien llega al nido y cierra el juego de
la emoción no tiene que volver a llegar.

## Consecuencias
- La línea vive en el HUD, no en un panel: un panel encima diría "esto ha
  terminado", y es exactamente lo contrario de lo que pasa.
- T-222 (tramos del viaje) puede colgarse de aquí: ya hay un punto final que
  el paisaje puede anticipar.
- T-290 (museo de placeholders) se desbloquea con `journey_completed`, que ya
  existe.
