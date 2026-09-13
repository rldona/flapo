# ADR-0023 — Tuberías móviles: física, límites y por qué no hay `constant_linear_velocity`

Fecha: 2026-09-08 · Estado: aceptada · Extiende [ADR-0008](ADR-0008-tuberias.md) y [ADR-0018](ADR-0018-curva-de-dificultad.md)

## Contexto
T-063 pide que, pasada cierta puntuación, algunos pares de tuberías oscilen
arriba y abajo. Tres preguntas: **qué las mueve**, **cómo se garantiza que no
sea injusto** y **cómo encaja con la curva de dificultad que ya existe**.

## Decisión 1 · Se mueven cambiando `position`, sin `constant_linear_velocity`
Los tubos siguen siendo `StaticBody2D` (ADR-0008). Oscilan escribiendo su
`position.y` en `_physics_process`, igual que ya se desplazaban en horizontal.

El ticket preguntaba si hace falta `constant_linear_velocity` para que
`move_and_slide()` de Flapo trate bien un roce. **No hace falta, y la razón
es que en este juego no existe el roce**: para Flapo, cualquier contacto con
una tubería es la muerte (`get_slide_collision_count() > 0`, ADR-0008). Un
cuerpo estático con velocidad constante sirve para arrastrar a quien se apoya
en él —una plataforma móvil—, y aquí nadie se apoya: se muere.

Si algún día una tubería dejara de matar —la "blandita" de T-066—, esta
decisión hay que volver a mirarla, porque entonces sí habría contacto sin
muerte y Flapo podría quedarse rozando una tubería que sube.

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
