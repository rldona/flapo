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
| Tope de caída (px/s) | 500 | | mentira física al servicio del control (ADR-0006) |
| Alto del suelo (px) | 64 | | altura jugable = 448 |

### Qué significan esos números al jugar

Medido con `tools/medir_feel.gd`, que es lo que hay que volver a ejecutar tras
cada cambio de la tabla:

| Magnitud percibida | Con los valores actuales |
|---|---|
| Cuánto sube un aleteo | 57 px, o **2,4 alturas de Flapo** |
| Cuánto tarda en subir | 0,32 s (ida y vuelta: 0,63 s) |
| Desde que la tubería entra hasta que llega a Flapo | 2,16 s |
| Tiempo entre dos tuberías | 1,60 s — caben **4,6 aleteos** |
| Margen libre al cruzar el hueco | 84 px, 42 arriba y 42 abajo |
| Caída libre desde el inicio hasta el suelo | 0,57 s |

Lo que hay que mirar al tunear (T-040):

- **Si el aleteo sube más de ~3 alturas de Flapo**, el salto deja de leerse:
  el jugador no puede estimar dónde va a acabar.
- **Si caben menos de 3 aleteos entre tuberías**, no da tiempo a corregir y el
  juego pasa de difícil a injusto.
- **El margen del hueco son 42 px por lado** porque la hitbox (radio 8) es más
  pequeña que el dibujo (24 px): Flapo sobresale 4 px por lado sin morir. Eso
  es deliberado y hace el juego generoso.

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
288×512 vertical, pixel art, paleta propia de 16 colores (ver `docs/art-guide.md`). Flapo 24×24 px (hitbox: círculo de radio 8, más generosa que el dibujo).

## Fuera de alcance en v1
Skins, ranking online, power-ups, anuncios, compras, modos de juego.
