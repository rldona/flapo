# ADR-0010 — Suelo: scroll infinito y colisión quieta

Fecha: 2026-09-07 · Estado: aceptada

## Contexto
El suelo tiene que dar sensación de avance continuo y matar a Flapo al
tocarlo. Es la superficie con la que más veces choca el jugador, así que una
costura visible o un hueco de colisión se notan enseguida.

## Opciones

### Cómo se recicla el dibujo
- **Un tile enorme** que se mueve y se recoloca: barato, pero cuanto más
  larga la partida, más grande el número, y antes o después la coma flotante
  empieza a perder precisión.
- **Dos tiles con "si te has salido, súmate el ancho"**: es el patrón que sale
  en todos los tutoriales. Funciona, pero el error de redondeo se **acumula**
  suma tras suma, y acaba dejando una costura de una fracción de píxel.
- **Dos tiles colocados desde un offset con `fmod`**: el offset nunca crece,
  vive siempre en `[0, ancho)`. Los tiles se colocan por construcción pegados,
  no "se recolocan cuando toca".
- **`ParallaxLayer` con `motion_mirroring`**: lo idiomático de Godot y sería
  razonable. Se reserva para el fondo (**T-043**), pero para el suelo hace
  falta además una colisión, que un `ParallaxLayer` no aporta; mezclarlo
  complicaría el nodo sin ganar nada.

### La colisión
- **Que se mueva con los tiles**: obliga a que también se recicle, y en el
  frame del reciclado puede quedar una costura por la que Flapo se cuele.
- **Un `StaticBody2D` quieto** que cubra todo el ancho: el suelo se ve mover
  porque el dibujo se mueve; la colisión no necesita enterarse.

## Decisión
Dos tiles colocados desde un offset con `fmod`, y **una sola colisión quieta**
(`StaticBody2D`, capa `obstaculos`) más ancha que la pantalla.

- El offset se calcula con `fmod(offset + velocidad * delta, ancho)`: no
  acumula error por larga que sea la partida.
- La colisión mide tres pantallas de ancho, para que ningún borde caiga
  dentro del área jugable ni con márgenes raros en pantallas altas (**T-073**).
- `GameConfig.GROUND_HEIGHT` y `GameConfig.playable_height()` son compartidos:
  el suelo los usa para su colisión y las tuberías para sortear el hueco.
  `Pipe.playable_height` desaparece como `@export`; era geometría del mundo
  disfrazada de ajuste de la tubería.
- El suelo **sigue moviéndose en `READY`**. Un mundo parado mientras Flapo
  espera parece un juego colgado; moviéndose, parece un juego esperándote.

## Consecuencias
- El criterio "sin salto visible al reciclar" pasa a ser comprobable: en 30 s
  simulados (10 reciclados) el peor hueco descubierto es **0,000000 px** y el
  peor desajuste entre tiles **0,00001 px**. Antes habría sido "míralo y dime
  si ves algo raro".
- Flapo ya muere por **colisión real** contra el suelo, no por la red de
  seguridad `fall_death_y` de la ADR-0006: muere a y=443 con la superficie en
  448 y la red en 512. La red se queda como seguro para casos imposibles.
- El suelo y las tuberías comparten `GameConfig.SCROLL_SPEED`, así que no
  pueden desincronizarse al tunear en **T-040**.
- Los dos tiles placeholder tienen colores ligeramente distintos **a
  propósito**: hace visible el reciclado mientras se prueba a ojo. En **T-052**
  pasan a ser el mismo tile y el criterio de "tiles sin costura" se comprueba
  con arte real.
- Queda pendiente decidir si activar
  `rendering/2d/snap/snap_2d_transforms_to_pixel`. Con scroll a 100 px/s el
  avance es de 1,667 px por frame: sin snap puede aparecer una costura de un
  píxel con filtro Nearest, y con snap el movimiento puede dar un tirón
  perceptible. No se decide a ciegas: se mira con arte real en **T-052**.
