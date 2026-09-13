# ADR-0036 — Un replay es la semilla, las entradas **y el perfil del jugador**

Fecha: 2026-09-08 · Estado: aceptada · Depende de [ADR-0030](ADR-0030-semilla-determinista.md) · Convive con [ADR-0032](ADR-0032-fantasma-del-record.md)

> **Nota de numeración.** T-261 no pedía ADR, pero esta decisión cambia una
> regla —qué hace falta para que una partida sea reproducible— y el repo dice
> que eso lleva ADR. Toma el siguiente número libre; ver el desfase de
> numeración anotado en ADR-0035.

## Contexto
Un bug de física a 60 Hz es casi imposible de reportar bien. "Me he muerto sin
tocar nada" no se reproduce, y pedirle al jugador que active una grabación y
repita lo que hacía es pedirle justo lo que no va a hacer.

Con la semilla determinista (T-240) se puede volcar la partida y volver a
jugarla en CI.

## Decisión
El fichero `.replay` lleva **cuatro cosas**, no dos:

1. La **semilla** (T-240).
2. Los **flancos del botón**: en qué frame de física se pulsó y en cuál se
   soltó.
3. El **modo de dificultad** (T-078).
4. La **confianza** del jugador (T-074).

Las dos últimas son las que se olvidan, y son las que hacen que un replay
funcione en la máquina de otro.

**El modo cambia el mundo**: hueco, velocidad y separación salen de él. El
replay de un bug en difícil, reproducido en normal, no enseña el bug.

**La confianza cambia la física de Flapo**: alarga la barra de aliento, o sea
cuánto se puede planear. El mismo fichero jugado por un perfil nuevo y por uno
veterano son dos partidas distintas. Es la más traicionera de las cuatro
porque no se nota casi nunca — el replay de referencia de `tests/fixtures/` es
de un bot que jamás planea, así que darle más aire no le cambia nada. Que un
caso concreto no lo note no quiere decir que no importe.

## Por qué entradas y no posiciones (al revés que el fantasma)
El fantasma (T-243) graba **posiciones** porque tiene que sobrevivir a que
cambien las constantes: es un adorno que vuela, y lo que se le pide es que sea
fiel a lo que pasó aunque el juego cambie debajo (ADR-0032).

Un replay quiere justo lo contrario. Graba **entradas** porque tiene que
reproducir la partida **entera** —muertes, frutas, viento, puntuación— y
porque su gracia es precisamente **romperse** cuando el juego cambia: si el
replay deja de cuadrar tras tocar `GameConfig`, eso es información, no un
fallo. Es la alarma.

Por eso son dos ficheros distintos y no se pueden fusionar: uno tiene que
sobrevivir al cambio y el otro tiene que detectarlo.

## Lo que hace el juego y lo que no
El juego **graba**: `ReplayRecorder` escucha el botón y vuelca a
`user://last.replay` en cada muerte, siempre, sin que nadie lo active. Un
replay solo sirve si ya estaba grabado cuando apareció el bug.

El juego **no sabe reproducirse**. `ReplayPlayer` vive en `tools/`, que no
viaja en el export: sería enviar a cada jugador código que solo usamos
nosotros. El reproductor inyecta las pulsaciones por la puerta de siempre
(`Input.parse_input_event`) y deja que el juego haga el resto; no fuerza
posiciones ni estados, así que si un replay no cuadra es porque algo ha
cambiado de verdad.

## Un frame de desfase
`Input.parse_input_event` **no lo ve el juego hasta el frame siguiente**. El
grabador anota cuándo se *vio* la pulsación, así que para que se vea en el
frame N hay que soltarla en el N-1.

Se midió antes de entenderlo: sin la corrección, el replay de referencia
terminaba con 17 puntos en vez de 22. **Un frame de 16 ms cambia la partida
entera** — que es exactamente lo que hace útil un replay y lo que lo hace
delicado.

## Límites conocidos
- Un toque que empiece y acabe **dentro del mismo frame** (menos de 16 ms) no
  deja flanco y se pierde. Con la física a 60 Hz fijos no hay forma de
  distinguirlo de no haber tocado.
- El determinismo **no sobrevive a cambiar `GameConfig`** (ADR-0030). Aquí eso
  es una función, no un defecto: un replay que deja de cuadrar tras un cambio
  de constantes está diciendo que el cambio ha alterado el juego.
- El fichero no lleva versión del juego. Cuando exista (T-271), debería ir
  dentro, para poder decir "esto se grabó con la 0.3.1" en vez de adivinarlo.

## Consecuencias
- `tests/fixtures/referencia.replay` se versiona y **no se toca nunca**: es la
  partida contra la que se compara para siempre. Si algún día deja de cuadrar,
  el test lo dice y hay que decidir si el cambio era querido.
- La plantilla de bug (T-005) pide adjuntar `user://last.replay`.
- `tests/replay.gd` sale con código 1 si no cuadra, así que se puede meter en
  CI (T-091) tal cual.
