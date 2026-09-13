# ADR-0020 — Aliento: un recurso de vuelo sin añadir botones

Fecha: 2026-09-08 · Estado: aceptada · Reabre parcialmente [ADR-0006](ADR-0006-cuerpo-de-flapo.md)

## Contexto
Flapo es un juego de **un solo botón**: está en el pitch, en el título de la
Fase 2 y en la ficha de tienda. Cualquier mecánica nueva que exija un input
nuevo rompe la premisa.

T-048 pide un recurso de vuelo: planear gastando aliento, y recuperarlo
volando bien. La pregunta no era si añadir el recurso, sino **cómo darle al
jugador una acción más sin darle un botón más**.

## Decisión
Se reinterpreta la duración de la pulsación:

- **Toque corto** → el aleteo de siempre. Impulso fijo, sin cambios.
- **Mantener pulsado** más de `glide_hold_time` (0,18 s) → **planeo**: la
  gravedad se reduce al 25 % y el tope de caída baja de 500 a 90 px/s.

**El aleteo no espera a saber si es un toque o un mantenido.** Sale en el
mismo frame de la pulsación, como siempre. Detectar el "hold" antes de
responder metería 180 ms de latencia en la única acción del juego, y eso se
siente inmediatamente como que el juego no responde. El planeo se activa
*después*, encima del aleteo que ya ha ocurrido.

### Qué se reabre de la ADR-0006, y qué no
La ADR-0006 fijó que Flapo es un `CharacterBody2D` cuya física **obedece en
vez de simular**: se escribe `velocity` y el motor solo resuelve el
desplazamiento. **Eso no cambia.** El planeo no introduce simulación: sigue
siendo `velocity.y` escrito a mano, solo que con otro multiplicador de
gravedad y otro tope de caída. Sigue siendo determinista y sigue viviendo en
`_physics_process`.

Lo que sí se matiza es la afirmación de que "el aleteo fija la velocidad de
golpe y no hay nada más": ahora hay **dos** formas de alterar la caída. Se
mantienen separadas a propósito —`_apply_gravity()` decide una de dos ramas,
sin mezclar— para que siga siendo legible qué hace cada una.

### El aliento vive en `Bird`, las constantes en `GameConfig`
El recurso es de Flapo y lo gastan sus acciones, así que el estado está en
`bird.gd`. Los números están en `GameConfig` (`MAX_BREATH`,
`BREATH_DRAIN_FLAP`, `BREATH_DRAIN_GLIDE`, `BREATH_RECOVER_ON_GAP`,
`BREATH_BAND_RATIO`), que es la regla del proyecto desde la ADR-0003: lo
compartido y lo que define el juego, ahí; lo que se tunea a ojo por nodo,
como los ángulos del planeo, en `@export`.

### La economía del recurso
| Acción | Coste |
|---|---|
| Aletear | 10 por aleteo (~25/s a ritmo normal) |
| Planear | 15 por segundo |
| Cruzar un hueco **por el centro** | +25 |

Con un hueco cada 1,6 s, la recuperación son ~15,6/s. Eso hace que **el
planeo continuo sea sostenible y el aleteo continuo no**. No es un ajuste
arbitrario: es la mecánica entera. Machacar el botón se paga; volar con
criterio, no.

Recuperar exige pasar por la **mitad central** del hueco
(`BREATH_BAND_RATIO = 0.5`). Si valiera cruzar por cualquier sitio,
recuperar sería automático y el recurso no existiría.

### Nunca se queda sin poder aletear
A 0 de aliento el planeo deja de frenar la caída, pero **el toque corto sigue
dando el impulso completo**. Es la regla que hace el recurso justo: un juego
de un botón donde el botón deja de funcionar no es difícil, está roto. El
castigo por quedarse sin aliento es perder una herramienta, no el control.

## Consecuencias
- Una acción nueva sin un input nuevo: la premisa de "un solo botón" sigue
  siendo literalmente cierta.
- La barra de aliento va **abajo**, sobre la franja del suelo. Arriba ya están
  el marcador, el efecto de fruta activo y el escudo; el criterio del ticket
  es explícito en que no tape la puntuación.
- El aliento se llena al volver a `READY`: es estado de partida, no progresión.
  **T-074** quiere que `MAX_BREATH` crezca con las partidas jugadas, y ahí sí
  habrá que persistirlo.
- Interacción con las frutas (T-047) que conviene vigilar al jugar: la fruta
  violeta ralentiza el mundo, así que los huecos llegan más espaciados y el
  aliento se recupera **menos por segundo**. Es coherente —ir despacio da más
  margen pero menos aliento— pero no estaba diseñado, ha salido solo.
## Fatiga por aleteo sin pausa (T-049)

El aliento castiga el gasto total, pero no distingue **volar** de **machacar
el botón**. La fatiga sí: más de `FATIGUE_FLAP_COUNT` (4) aleteos en
`FATIGUE_WINDOW` (1,2 s) reduce el impulso del siguiente un
`FATIGUE_PENALTY` (30 %).

### Es una función pura del historial, no un estado
`GameConfig.fatigue_impulse_mult(aleteos_en_ventana)` no tiene memoria. Flapo
guarda las marcas de tiempo de sus aleteos —eso son datos— y pregunta. No hay
un `_fatigado` que sincronizar, reiniciar o depurar, y podar el historial a la
ventana hace que "hace rato que no aleteo" y "he dejado de aletear" sean lo
mismo sin código extra.

### El umbral está calibrado contra la curva de dificultad
En su punto más duro, la curva de la ADR-0018 da **3,39 aleteos por hueco**.
El umbral está en 4: **jugar bien nunca fatiga**. Solo llega quien martillea.
Hay test que lo comprueba contra la propia curva, así que si algún día se
retoca una, la otra se entera.

### Dos salidas, y una es una acción
La fatiga se quita **planeando** (borra el historial de golpe) o dejando pasar
la ventana. Que planear descanse no es un detalle: convierte "deja de
machacar" en algo que **haces**, no en algo que esperas, y ata las dos
mecánicas de esta ADR en un solo bucle — machacas, te cansas, planeas,
recuperas aliento cruzando centrado.

### El reloj es el del juego, no el del sistema
La primera versión usaba `Time.get_ticks_msec()`. Es tiempo real, así que la
ventana de fatiga habría seguido corriendo **con el juego en pausa** (T-072) y
se habría descuadrado con el hit-stop de la muerte (T-042), que pone
`Engine.time_scale` a 0. Flapo acumula su propio `delta` en
`_physics_process`: el único reloj que se para cuando el juego se para.

### Nunca deja a Flapo sin control
Fatigado el impulso baja un 30 %, pero **sigue siendo un impulso hacia
arriba**. Igual que con el aliento a cero: el castigo es que cuesta más, no
que deje de responder.

Ojo a un efecto que no es obvio: la altura de un salto va con el **cuadrado**
de la velocidad inicial, así que un 30 % menos de impulso es un 51 % menos de
altura. Se nota más de lo que el número sugiere. `tools/medir_feel.gd` lo
imprime.
