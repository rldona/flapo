# ADR-0023 — Tuberías especiales: móviles, blanditas y giratorias

Fecha: 2026-09-08 · Estado: aceptada · Extiende [ADR-0008](ADR-0008-tuberias.md) y [ADR-0018](ADR-0018-curva-de-dificultad.md)

## Contexto
Tres tickets tocan el mismo sistema y por eso comparten ADR: T-063 hace que
algunos pares oscilen arriba y abajo, y T-066 añade una tubería que **no
mata**. Las preguntas: qué las mueve, cómo se garantiza que no sea injusto,
cómo encaja con la curva que ya existe, y qué pasa con la física cuando por
primera vez hay contacto sin muerte.

## Decisión 1 · Se mueven cambiando `position`, sin `constant_linear_velocity`
Los tubos siguen siendo `StaticBody2D` (ADR-0008). Oscilan escribiendo su
`position.y` en `_physics_process`, igual que ya se desplazaban en horizontal.

El ticket preguntaba si hace falta `constant_linear_velocity` para que
`move_and_slide()` de Flapo trate bien un roce. **No hace falta, y la razón
es que en este juego no existe el roce**: para Flapo, cualquier contacto con
una tubería es la muerte (`get_slide_collision_count() > 0`, ADR-0008). Un
cuerpo estático con velocidad constante sirve para arrastrar a quien se apoya
en él —una plataforma móvil—, y aquí nadie se apoya: se muere.

Este párrafo se escribió avisando de que **habría que volver a mirarlo en
T-066**, y en efecto hubo que hacerlo. La respuesta está más abajo, en
"T-066 · La física del contacto sin muerte", y no es
`constant_linear_velocity`.

## Decisión 2 · La amplitud se recorta por tubería, no es una constante
`MOVING_PIPE_AMPLITUDE` (22 px) es un **máximo**, no la amplitud real.
`GameConfig.moving_pipe_amplitude(gap, centro)` la recorta al margen que
queda por arriba y por abajo:

```
amplitud = min(22, centro − hueco/2, altura_jugable − centro − hueco/2)
```

Y si no cabe margen, devuelve **0**: la tubería sale quieta. Es deliberado
que el caso degenerado sea "una tubería normal" y no "un hueco medio fuera de
pantalla", que sería una muerte que el jugador no ve venir.

Se calcula sobre el hueco **completo**, no sobre su centro. Es la diferencia
entre la garantía real y una que parece igual y no lo es: el centro puede
estar dentro de la pantalla con medio hueco fuera.

`tests/test_t063_tuberias_moviles.gd` barre 378 combinaciones de puntuación,
modo de dificultad y altura del hueco, y comprueba que ningún borde se sale.
Quitar el recorte pone el test en rojo con −2,02 px.

## Decisión 3 · La probabilidad es una función pura de la puntuación
Como todo lo demás en la curva (ADR-0018):

| Puntos | Probabilidad de par móvil |
|---|---|
| 0–14 | **0** |
| 15 | 0,15 |
| 30 y más | 0,45 |

Por debajo de 15 es **exactamente 0**, no "muy poco". Los primeros quince
puntos son la rampa de entrada del GDD: quien está aprendiendo a volar no se
encuentra una tubería que se mueve. Y el tope nunca llega a 1, porque un
tramo entero de tuberías móviles deja de ser una variante y pasa a ser otro
juego.

Al ser pura, reiniciar la devuelve sola a 0 sin código de reinicio, igual que
la velocidad y el hueco.

## Decisión 4 · La velocidad de la oscilación es la que la hace justa
Un periodo de 2,4 s con 22 px de amplitud da **58 px/s de punta**. Un aleteo
mueve a Flapo a 380 px/s: la tubería va al **15 %** de lo que Flapo puede.

Eso es lo que separa "exigente" de "inevitable". `moving_pipe_peak_speed()`
existe solo para que un test pueda comprobar esa relación contra el
`flap_impulse` real de Flapo —no contra un número copiado—, de modo que si
alguien tunea el aleteo en T-040 el test se entera. Multiplicar la velocidad
por 10 lo pone en rojo con 576 px/s.

## Consecuencias
- El desfase de cada tubería se sortea. Sin eso todas oscilarían en fase y se
  leería como un temblor de la pantalla, no como tuberías que se mueven.
- `_apply_layout()` se parte en dos: lo que depende de la altura del hueco
  (`_recolocar()`) corre en cada frame de física; vestir los sprites, no.
  Repetir 60 veces por segundo el cálculo de regiones y cabezas sería trabajo
  tirado.
- La zona de puntuación se mueve con el hueco, así que puntuar sigue siendo
  "pasar por el hueco" y la banda central de aliento (T-048) sigue valiendo.
- El reloj de la oscilación es propio y acumulado en `_physics_process`, no
  `Time`: se para con la pausa y con el hit-stop, como la ventana de fatiga
  de T-049.
- **No cubierto aquí**: si el movimiento *se siente* justo. Eso no lo dice un
  test; lo dice jugar.

---

# T-066 · La tubería blandita

## Decisión 5 · Predecible, no aleatoria
Una de cada `SOFT_PIPE_INTERVAL` (7) tuberías es blandita, contando desde el
principio de la partida, y **la primera nunca lo es**: salir a jugar y
encontrarte la variante rara de entrada no explica nada.

Que sea predecible es la decisión. Al poder contarla, la blandita se
convierte en una decisión ("me la juego en la séptima") en vez de en un golpe
de suerte. Aleatoria sería un premio; contable es una herramienta.

`GameConfig.is_soft_pipe(indice)` es pura, como todo lo demás: reiniciar
reinicia la cuenta sin código de reinicio.

## Decisión 6 · Cuesta aliento y un punto, nunca la partida
| Coste | Valor |
|---|---|
| Aliento | 35 de 100 |
| Puntos | 1, con suelo en 0 |
| Enfriamiento | 0,8 s |
| Rebote | 260 px/s, vertical, **hacia el hueco** |

El suelo en 0 no es defensivo: un marcador negativo es un castigo que no se
puede recuperar, y la blandita existe justo para no castigar así (GDD, "se
ríe con el jugador, no de él").

El enfriamiento existe porque quedarse apoyado contra ella cobraría 60 veces
por segundo. Y el rebote empuja **hacia el hueco** y no hacia afuera: la
tubería que perdona te coloca donde tenías que haber pasado.

Tocar a la vez una blandita y una normal **mata**. Perdonar por estar rozando
una blandita la convertiría en un escudo, y no lo es.

## Decisión 7 · La física del contacto sin muerte
Aquí es donde la Decisión 1 tuvo que completarse. Con una tubería que no
mata, Flapo puede seguir en contacto con ella, y entonces sí pasa lo que con
las normales nunca llegaba a importar: **un `StaticBody2D` que se desplaza y
atraviesa a Flapo lo empuja al resolver la penetración**. Medido en un test:
la x de Flapo pasó de 320 a 338 en medio segundo, y como no moría se quedaba
desplazado para siempre.

La respuesta **no** es `constant_linear_velocity`: eso serviría para
arrastrarlo *más*, no menos. La respuesta es afirmar el invariante que el
juego siempre tuvo y nunca había necesitado escribir:

> Si Flapo no se está moviendo en horizontal a propósito, la física no puede
> moverlo en horizontal.

Se implementa restaurando la x de antes de `move_and_slide()`, y solo cuando
`velocity.x` era 0. Los dos matices importan: sin el primero, colocar a Flapo
a mano dejaría de valer; sin el segundo, quien le da velocidad horizontal
—varios tests cruzan una tubería moviendo a Flapo en vez de moverla a ella—
se encontraría con que no avanza. En la partida real `velocity.x` es siempre
0, así que la regla se aplica siempre.

## Consecuencias de T-066
- El tinte se aplica en `_ready()` y no solo en el setter de `soft`: el
  spawner marca la tubería **antes** de `add_child`, cuando los sprites
  todavía no existen. Es la misma trampa que con la textura de las frutas.
- Una blandita puede además oscilar. No se ha prohibido a propósito: combinar
  gimmicks es justo lo que pide T-067.
- El rebote vertical hacia el hueco depende del hueco **actual**, así que en
  una blandita que además oscila apunta al sitio correcto en cada momento.
- **No cubierto aquí**: si el rebote *se siente* bien. Eso lo dice jugar.

---

# T-065 · La tubería giratoria

## Decisión 8 · Gira el dibujo, no la hitbox — y solo las bocas
El ticket lo pide explícito: el giro es del sprite, no de la forma de
colisión. Es "más barato y más justo que mover el hueco físico", y la parte
de *justo* es la que importa: si el hueco real dejara de coincidir con el que
se ve, el jugador moriría en un sitio donde ve aire.

La implementación consiste en **no hacer lo natural**. Lo natural sería girar
el `StaticBody2D`, y eso giraría su `CollisionShape2D` con él. Así que se
gira cada `Cap` —hijo del cuerpo— sobre su propio centro.

El test lo comprueba girando el cuerpo a propósito: la transformada de la
forma pasa de identidad a una matriz rotada y, más importante, **el resultado
de la colisión cambia** (a y=300 se pasa donde antes se chocaba). Cuatro
fallos.

Y se giran las **bocas** y no el cuerpo del tubo porque el cuerpo es un
rectángulo repetido de 512 px de largo: girarlo se vería roto, no giratorio.

## Consecuencias de T-065
- 0,35 vueltas por segundo. Despacio: girar rápido lee como un error de
  dibujo.
- La probabilidad es pura y con rampa (0 por debajo de 12 puntos, hasta 0,35
  en el tope), igual que las móviles.
- El test es una **equivalencia**: misma puntuación y misma colisión con y sin
  giro. Una equivalencia entre dos cosas quietas se cumple sola, así que el
  test afirma **primero** que el giro ocurre de verdad; sin ese aserto todo lo
  demás pasaría con la variante desactivada.
- Una giratoria puede además oscilar o ser blandita. No se prohíbe: es lo que
  pide T-067.
