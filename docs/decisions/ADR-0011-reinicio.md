# ADR-0011 — Reinicio en sitio, sin recargar la escena

Fecha: 2026-09-07 · Estado: aceptada

## Contexto
Al morir, el jugador tiene que poder volver a jugar. En un juego donde una
partida dura veinte segundos, el reinicio se pulsa cientos de veces por
sesión: es una de las interacciones más frecuentes del juego.

El enunciado de **T-028** dice "botón/acción `restart` que **recarga la
escena** limpiamente", y la ADR-0005 apuntaba en la misma dirección: recargar
reinicia el estado sin código de limpieza que se pueda olvidar. El criterio de
aceptación, en cambio, no habla de recargar sino del resultado: *"reiniciar 50
veces seguidas no acumula nodos ni timers"*.

## Opciones
- **`get_tree().reload_current_scene()`**: tira el árbol entero y lo vuelve a
  construir. Imposible dejarse estado sucio, porque no queda estado. A cambio:
  reconstruir nodos y volver a resolver recursos en cada muerte, un tirón
  perceptible en Web y en Android de gama baja, y en la Fase 5 se llevaría por
  delante los `AudioStreamPlayer` (un sonido de golpe cortado a la mitad).
  Además deja muerta la transición `GAME_OVER → READY` de la máquina de
  estados: existiría un estado al que no se llega nunca.
- **Reinicio en sitio**: `change_state(READY)` y que cada sistema se reinicie
  al recibirlo. Instantáneo y sin reconstruir nada. El riesgo es real y hay
  que nombrarlo: si un sistema olvida reiniciar algo, el bug es silencioso y
  aparece en la segunda partida, no en la primera.

## Decisión
Reinicio en sitio. `Main.restart()` es `change_state(READY)`, y cada sistema
ya sabe qué hacer con ese estado:

| Sistema | Qué reinicia al recibir READY |
|---|---|
| `Main` | puntuación a 0 |
| `PipeSpawner` | libera las tuberías vivas y resiembra el generador |
| `Bird` | posición, velocidad, rotación y el flag `_dead` |
| `Ground` | vuelve a moverse |
| `GameOverPanel` | se oculta |

Es una **desviación del texto del ticket**, no de su criterio de aceptación.
El criterio se cumple y se comprueba; la forma de llegar a él es distinta.

El riesgo de olvidarse algo se compensa con el test: 50 muertes y 50
reinicios reales, comparando recuento de nodos, de `Timer` y de huérfanos
antes y después, más una comprobación de que Flapo vuelve a poder morir —si
el flag `_dead` no se limpiara, la segunda partida sería inmortal.

## Consecuencias
- Reinicio instantáneo, sin reconstruir el árbol. Importa en un juego que se
  reinicia constantemente.
- La transición `GAME_OVER → READY` de la ADR-0005 pasa a ser el camino real
  del juego, no código muerto.
- Resultado del test: **21 nodos antes y 21 después**, 1 timer antes y 1
  después, 0 huérfanos antes y después, y sigue jugable.
- Encontró un bug de verdad por el camino: en `READY`, Flapo se iba girando
  solo hasta ~25°, porque el ángulo objetivo para velocidad 0 no es 0° (el
  cero cae dentro del rango impulso..caída máxima). A ojo, en la primera
  partida, es invisible; tras un reinicio, Flapo esperaba torcido. La
  rotación ya no se toca en `READY`.
- Cuando llegue el audio (**Fase 5**) esta decisión se agradece: los sonidos
  no se cortan al reiniciar.
- Si en el futuro un sistema nuevo guarda estado de partida, **tiene que
  reiniciarlo en `READY`** y añadir su comprobación al test de 50 reinicios.
  Es la contrapartida de no recargar la escena.
