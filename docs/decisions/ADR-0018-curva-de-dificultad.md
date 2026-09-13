# ADR-0018 — Curva de dificultad

Fecha: 2026-09-08 · Estado: aceptada

## Contexto
El juego era de dificultad constante, como el Flappy original. Raúl pidió que
subiera con la puntuación: "que cuando vaya pasando de niveles vaya más
rápido".

No choca con el alcance: el GDD deja fuera de v1 skins, ranking, power-ups y
*modos* de juego, y una curva de dificultad no es nada de eso.

## El límite que decidió la forma
Una rampa de velocidad pura tiene techo, y lo marca un número que ya estaba
medido en el GDD: **por debajo de 3 aleteos entre tuberías el juego pasa de
difícil a injusto**, porque no da tiempo a corregir.

Con la separación fija en 160 px:

| Velocidad | Tiempo entre tuberías | Aleteos |
|---|---|---|
| 100 px/s | 1,60 s | 4,57 |
| 150 px/s | 1,07 s | **3,05** |
| 200 px/s | 0,80 s | 2,29 |

A partir de ~150 px/s subir la velocidad ya no hace el juego más difícil, lo
hace peor. Cualquier curva tenía que respetar ese suelo.

## Opciones
- **Solo velocidad**: vértigo y menos tiempo de reacción, con tope obligatorio.
- **Solo hueco**: más precisión, ritmo intacto. Lo más justo y lo que menos se
  nota.
- **Por niveles con saltos visibles**: se siente como progresar, pero mete
  picos bruscos justo cuando llevas buena racha.
- **Velocidad y hueco, con tope**: lo que hacen la mayoría de clones.

## Decisión
Velocidad y hueco a la vez, con tope a los **30 puntos**:

| | Inicio | Tope |
|---|---|---|
| Velocidad | 100 px/s | 145 px/s |
| Hueco | 118 px | 82 px |
| Separación | 160 px | 172 px |
| Aleteos entre tuberías | 4,57 | **3,39** |

La separación sube **a propósito**, aunque parezca contradictorio en una curva
de dificultad: es lo que mantiene los aleteos por encima del suelo de 3. Sin
ella, a 145 px/s quedarían 3,15 y el margen sería demasiado fino.

El hueco mínimo de 82 px sigue siendo **cinco veces la hitbox** de Flapo
(16 px de diámetro) y más de tres veces su dibujo.

### El hueco de salida sube a 118 px (T-046)
El GDD fijaba 100 px, que es el hueco habitual del género. Se sube a 118 para
la salida: los primeros diez segundos de alguien que no ha jugado nunca son
los que deciden si sigue jugando, y con 100 px el margen es de 42 px por lado
frente a los 51 de ahora.

El efecto secundario es que la curva llega a los 100 px **justo a los 15
puntos**: los primeros quince son la rampa de entrada y a partir de ahí el
juego es el de siempre.

Esto abrió un invariante que antes no existía: con huecos más anchos hay que
comprobar que **el hueco cabe entre el techo y el suelo** en las dos
posiciones extremas del rango de sorteo (20 %–80 %). Con 118 px quedan 30,6 px
de margen por arriba y por abajo. Hay test, porque ensanchar más sin mirarlo
dejaría tuberías con un tubo de altura cero: un hueco pegado al borde que no
se ve venir.

### Todo son funciones puras de la puntuación
`GameConfig.scroll_speed_for(score)`, `pipe_gap_for(score)`,
`pipe_spacing_for(score)`. No hay estado de dificultad en ningún sitio.

Eso tiene una consecuencia práctica: **reiniciar restaura la dificultad sin
código de reinicio**, porque al volver a `READY` la puntuación es 0 y la
curva devuelve los valores del GDD. Es el mismo criterio que hizo que
`pipe_spawn_interval()` fuera derivada y no una constante suelta (ADR-0003).

### La velocidad se empuja, no se consulta
Antes, `Pipe`, `Ground` y `Background` leían `GameConfig.SCROLL_SPEED`
directamente. Ahora cada uno tiene su `scroll_speed` y **Main se lo pasa** al
cambiar la puntuación: "call down" (ADR-0005). Los sistemas no conocen el
marcador.

`PipeSpawner` propaga además la velocidad a las tuberías **ya vivas**. Si unas
fueran más rápidas que otras, la separación entre ellas se deformaría en
pantalla y el mundo dejaría de moverse como un bloque.

## Consecuencias
- Hay un test que recorre **toda** la curva, no solo el tope, y comprueba que
  nunca baja de 3 aleteos: mínimo 3,39 a los 30 puntos. Si alguien sube la
  velocidad máxima sin pensar, el test lo para.
- `tools/medir_feel.gd` imprime la curva punto por punto, para tunearla
  mirando la columna de aleteos y no a ojo.
- El tope existe porque un juego sin techo de dificultad acaba siendo una
  lotería. A partir de 30 puntos lo que queda es aguantar, que es lo que hace
  el género.
- Se aleja del Flappy original, que **no** tiene rampa. Es una decisión
  deliberada de Raúl y queda anotada como tal: si al jugar resulta que la
  dificultad constante se sentía mejor, deshacerla es poner
  `DIFFICULTY_CAP` a un número enorme, sin tocar código.
