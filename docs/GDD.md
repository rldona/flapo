# GDD — Flapo

> Una página. Si no cabe, el alcance es demasiado grande.

## Pitch
Toca para que Flapo aletee y cruza tantas tuberías como puedas sin tocar nada.

## Concepto y tono
Flapo es el hermano gordito del pájaro famoso. Quiere volar como él, pero pesa el doble y le cuesta el triple. El juego es el mismo reto de siempre contado con humor: cada muerte es un batacazo cómico, no un drama.

Cómo se traduce al juego:
- **Silueta**: redondo, tripa por delante, alas pequeñas. Lee mejor a 16×12 px que un pájaro estilizado.
- **Física**: caída algo más pesada y aleteo con esfuerzo visible (frames exagerados, un pequeño "uf" de retardo antes del impulso, siempre por debajo de 50 ms para no estropear el control).
- **Muerte**: rebote en el suelo, ojos en espiral, sacudida de cámara más fuerte que en un Flappy normal.
- **UI**: logo con la tripa como letra O, medallas con nombre de comida (croqueta de bronce, tortilla de plata, jamón de oro).
- **Textos**: cortos y con guasa. "Otra vez", no "Game Over".

Lo que NO es: no se ríe del jugador, se ríe con él. Nada de mensajes de burla al morir.

Nota de tienda: en itch.io y Google Play nunca usar el nombre del juego original ni describir Flapo como spin-off. "Inspirado en el clásico de un solo botón" es suficiente.

## Bucle central
Ready → (toque) → Playing: aletear, esquivar, puntuar → (colisión) → Game Over → reintentar.

## Reglas y constantes
| Constante | Valor inicial | Valor final | Notas |
|---|---|---|---|
| Gravedad (px/s²) | 1200 | | |
| Impulso de aleteo (px/s) | -380 | | |
| Velocidad de scroll (px/s) | 100 | | |
| Separación entre tuberías (px) | 160 | | |
| Hueco (px) | 100 | | |
| Rango vertical del hueco | 20 %–80 % | | |
| Tope superior | y = 0 | | |

- Muerte: contacto con tubería o suelo.
- Puntuación: +1 al atravesar el hueco. Una vez por tubería.
- Récord persistente. Medallas: bronce 10, plata 20, oro 40.

## Estados
`READY` (Flapo flota, sin gravedad) · `PLAYING` · `GAME_OVER` (0,5 s de retardo antes del panel).

## Controles
Acción `flap`: toque, click izquierdo, espacio. `restart`, `pause`.

## Feedback
Sonidos: aleteo, punto, golpe, caída, botón. Al morir: flash blanco, sacudida de cámara, hit-stop 60–100 ms. Parallax de fondo en 2 capas.

## Estilo
288×512 vertical, pixel art, paleta de 16 colores (ver `docs/art-guide.md`). Flapo 16×12 px.

## Fuera de alcance en v1
Skins, ranking online, power-ups, anuncios, compras, modos de juego.
