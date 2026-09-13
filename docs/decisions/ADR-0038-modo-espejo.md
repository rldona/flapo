# ADR-0038 — El modo espejo: una excepción más a "modos de juego fuera de v1"

Fecha: 2026-09-09 · Estado: aceptada · Reabre el alcance como hizo [ADR-0019](ADR-0019-frutas.md)

> **Nota de numeración.** T-076 pedía ADR-0023, que ya está ocupada por las
> tuberías especiales. Es la cuarta colisión de la tanda; sigue pendiente de
> Raúl decidir si se renumeran los tickets o se acepta el desfase.

## Contexto
El GDD deja **"modos de juego"** fuera de alcance en v1, junto con skins,
ranking online, anuncios y compras. T-076 pide un modo espejo desbloqueable.

Esa lista no es sagrada —los power-ups estaban en ella hasta T-047, y ADR-0019
los sacó a propósito— pero sí es la que impide que el proyecto no se acabe
nunca. Sacar algo de ahí tiene que justificarse.

## Decisión
El modo espejo entra, y la lista se queda igual para lo demás.

La diferencia con skins, ranking o compras es que **el espejo no añade
sistemas**: no hay tienda, ni servidor, ni assets nuevos, ni una segunda
economía que mantener. Es la física de siempre con el signo cambiado, y se
paga una vez.

Se desbloquea con **récord ≥ 25** (`MIRROR_UNLOCK_SCORE`), por encima de la
medalla de plata. Depende del récord y no de las partidas jugadas: es un
premio por jugar bien, no por jugar mucho — para lo segundo ya está la
confianza (T-074).

## Es un espejo, no otro control
El ticket se contradice: el título dice "gravedad y control invertidos" y el
paréntesis dice "mantener para subir, soltar para caer", que es un helicóptero
y no un espejo.

Se implementa el **espejo literal**: la gravedad tira hacia arriba y el aleteo
empuja hacia abajo. Tres razones:

1. Es lo que dice la cláusula principal y el título del ticket.
2. Es lo único que se puede verificar **como inversión**, que es lo que pide
   el criterio de aceptación ("que la inversión sea consistente"). Un
   helicóptero no es la inversión de nada: es otra mecánica.
3. Todo lo demás sigue igual. Un modo que además cambiara los números sería
   otro juego, no el mismo visto en un espejo.

Queda anotado por si Raúl quería el helicóptero: sería otro ticket.

## Un signo, no un `if` por sitio
Toda la inversión pasa por `Bird._signo()`, que devuelve 1 o -1. Gravedad,
aleteo, tope de caída, rebote al morir y ángulo del morro lo usan.

Con `if mirror` repartidos por la física, cualquier ajuste futuro tendría que
acordarse de las dos ramas — y la que menos se juega es la que se rompe sin
que nadie lo vea hasta meses después.

## El techo es el suelo
En espejo, tocar el techo mata, y cuenta como muerte de suelo. Sin eso, Flapo
se quedaría pegado arriba para siempre: la gravedad lo empuja contra el techo
y ahí no hay ningún cuerpo con el que chocar.

Esto costó un test que no probaba nada. La primera versión comprobaba que
"dejarse llevar acaba matando", y pasaba **con y sin** la muerte por techo:
pegado al techo, Flapo choca con la parte alta de la primera tubería y muere
igual. Solo quitándole las colisiones queda el techo como única causa posible.

## Opt-in, y comprobado dos veces
El botón vive en Opciones (T-087), **escondido hasta que se desbloquea**: un
botón apagado que no dice por qué es peor que no tener botón, y cuando aparece
es un premio.

El desbloqueo se comprueba también **al pulsar**, no solo al dibujar. Que un
control esté escondido no es una garantía de nada: quien decide es quien tiene
el récord.

Y se aplica **al empezar la partida, nunca en vuelo**. Darle la vuelta a la
gravedad a media partida sería una muerte gratis.

## Va al replay
El espejo cambia la física, así que entra en el `.replay` (formato v3). Es la
regla que dejó ADR-0036 y esta es su segunda aplicación en dos tickets: cada
vez que algo nuevo mira el guardado para decidir qué pasa en la partida, entra
en el fichero.

## Consecuencias
- El modo normal no cambia **en nada**. El test lo comprueba comparando la
  trayectoria de Flapo frame a frame con el espejo apagado.
- El GDD pasa el espejo de "fuera de alcance" a excepción documentada, como se
  hizo con los power-ups.
- Retrasa la publicación un poco más, y se acepta a sabiendas.
