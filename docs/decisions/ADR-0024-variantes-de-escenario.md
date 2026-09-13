# ADR-0024 — El cielo sale de la semilla, no del generador

Fecha: 2026-09-08 · Estado: aceptada · Depende de [ADR-0030](ADR-0030-semilla-determinista.md)

## Contexto
T-057 quiere variantes cosméticas de escenario —atardecer, noche, lluvia—
elegidas "al azar por partida". Cuando se escribió el ticket, "al azar" quería
decir `randi()`. Desde T-240 no hay `randi()` suelto: toda la aleatoriedad de
una partida sale de un único generador sembrado.

Y ahí está el problema. Si el escenario **le pide un número a ese generador**,
la secuencia entera se desplaza un paso: los códigos compartidos de T-242
dejan de dar la misma partida, el replay de referencia de T-261 deja de
cuadrar y el fantasma de T-243 vuela por huecos que ya no están.

Un adorno no puede permitirse eso.

## Decisión
La variante es **función pura de la semilla**: `posmod(semilla, nº de
variantes)`. No consume nada del generador.

Con eso se consiguen tres cosas de una:

1. **La secuencia de tuberías no se mueve.** El escenario podría no existir y
   la partida sería idéntica. El test lo comprueba jugando la misma semilla
   con dos cielos forzados distintos y exigiendo las mismas tuberías.
2. **El reto del día sale con el mismo cielo para todo el mundo** (T-241). Es
   lo que uno espera de un reto compartido, y sale gratis.
3. **Un código compartido incluye el cielo** (T-242). Dos amigos comparando la
   misma partida la ven igual, no uno de noche y otro al mediodía.

## Un choque entre dos tickets
T-057 pide que "reiniciar pueda cambiarla". **T-240 garantiza lo contrario**:
reiniciar repite la misma partida, semilla incluida, a propósito.

Gana T-240, que es la promesa más fuerte y la más nueva. Reintentar conserva el
cielo —si cambiara, el mismo código daría dos partidas de aspecto distinto— y
lo que sí lo cambia es **empezar una partida nueva**, que es lo que hace el
botón de Jugar. La intención del ticket se cumple: el jugador ve cielos
distintos a lo largo de una sesión.

## Cómo se pintan
El cielo es un `ColorRect`, así que se le da el color exacto que se quiera.

Las nubes y los edificios ya vienen pintados del PNG y solo se pueden
**teñir** con `modulate`, que multiplica, o sea que solo puede oscurecer. No es
una limitación que haya que rodear: es exactamente lo que hace la luz al caer
la tarde. Las tres variantes nuevas son más oscuras que el día, y el día es el
que no tiñe nada.

Esto evita duplicar los PNG por variante, que es lo que habría pedido el
enfoque ingenuo: cuatro juegos de nubes que mantener sincronizados a mano.

## Lo que la variante NO puede tocar
Ni `layer_speeds` ni el offset del parallax. Si una variante cambiara la
velocidad de las capas, dejaría de ser cosmética: el mundo iría distinto según
el cielo que tocara, y la comparabilidad entre partidas con la misma semilla se
acabaría. El test lo comprueba en tres variantes.

La lluvia son `CPUParticles2D` y no `GPUParticles2D` por lo de siempre: las de
GPU no se simulan en headless y no habría forma de comprobarlas.

## Consecuencias
- Cuatro variantes. Añadir una quinta es una entrada más en tres arrays de
  `GameConfig` y nada más; el test exige que las tres tablas midan lo mismo.
- Los colores de escenario amplían la paleta de `docs/art-guide.md`, con el
  mismo criterio con el que ya la ampliaron las frutas (T-047): tonos que el
  resto del mundo no usa, escritos en la guía.
- T-222 (tramos del viaje) puede colgarse de aquí: ya hay un sitio donde el
  fondo cambia entero y un test que exige que no toque la física.
