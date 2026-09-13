# ADR-0012 — Game feel: dónde vive el jugo y cómo se mide

Fecha: 2026-09-08 · Estado: aceptada

## Contexto
La Fase 3 añade cosas que, por definición, existen para que el juego *se
sienta* bien: animación de aleteo, flash y sacudida al morir, hit-stop,
parallax y transiciones. Nada de eso cambia las reglas: si se quitara todo, el
juego seguiría funcionando igual y puntuando igual.

Eso plantea un problema con la ADR-0007: si el criterio de estas piezas es
"que mole", ¿qué se puede verificar en headless?

## Decisión

### Un solo nodo `Juice` para el golpe
Flash, sacudida, hit-stop y el reinicio de todo ello viven juntos en
`scripts/juice.gd`, con las intensidades como `@export`. Son un mismo golpe:
si cada efecto viviera en su nodo, ajustar "cuánto duele morir" obligaría a
tocar cinco sitios y a acertar con cinco duraciones que deben cuadrar entre sí.
El rebote sí vive en `Bird`, porque es física suya y tiene que ocurrir en el
mismo tick del golpe, sin un frame de retraso.

### `Parallax2D`, no `ParallaxBackground`
`ParallaxBackground` + `ParallaxLayer` es el patrón clásico y el que sale en
casi toda la documentación antigua; `Parallax2D` (Godot 4.3+) lo sustituye y
es más simple. Además el offset se lleva a mano y no con `autoscroll`: así el
fondo comparte reloj con el suelo y las tuberías —no puede desincronizarse al
tunear en T-040— y pararlo en `GAME_OVER` es dejar de sumar, no manipular una
propiedad del nodo.

### Qué se verifica y qué no
Lo que headless **sí** puede afirmar de un efecto:

| Se verifica | No se verifica |
|---|---|
| que ocurre (el flash sube, la cámara se mueve) | si el flash es demasiado fuerte |
| que **se deshace** (vuelve a cero solo) | si la sacudida marea |
| que respeta un número del GDD (0,5 s) | si 0,5 s es el número correcto |
| que no sobrevive a un reinicio | si la muerte es divertida |
| que no bloquea la entrada más de 1 s | si el ritmo es agradable |

La columna izquierda es la que se rompe sola con el tiempo, y es la que tiene
test. La derecha es T-040 y es de Raúl.

## Consecuencias
- Encontró un bug grave que a ojo habría sido casi imposible de diagnosticar:
  el hit-stop ponía `Engine.time_scale = 0` y lo restauraba tras un `await`
  sobre un temporizador. **Un `await` está atado a la vida del nodo**: si la
  escena se libera antes de que venza —cambio de escena, cierre, o el
  `free()` de un test— la corrutina no se reanuda y el motor entero se queda
  congelado, sin nada que el jugador pueda hacer. Ahora la congelación se
  cuenta en frames de dibujo, que siguen corriendo con el reloj parado, y hay
  además una red de seguridad en `_exit_tree()`.
- El patrón "todo efecto debe deshacerse solo" es ahora una regla del
  proyecto: cada uno tiene un test que comprueba que vuelve a su estado de
  reposo y que no sobrevive a un reinicio. Un efecto pegado (flash a medias,
  cámara descentrada, velo opaco) es un bug visual permanente.
- La rotación de Flapo pasa a actualizarse **solo en `PLAYING`**: en
  `GAME_OVER` manda el giro de aturdimiento. Si los dos escribieran
  `rotation`, se pelearían y el giro no se vería.
- Los frames de aleteo son **placeholder generados por código** (16×12, con
  outline de 1 px según `docs/art-guide.md`). Se sustituyen en T-050. El
  criterio de T-055 (`grep` de "placeholder" en `scenes/`) los encontrará,
  que es lo que se quiere.
- Queda fuera **T-040**, el tuning: Raúl decidió mantener los valores
  actuales por ahora. Las constantes están todas expuestas, así que cuando se
  aborde no hará falta tocar código.
