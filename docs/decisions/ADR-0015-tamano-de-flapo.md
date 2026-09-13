# ADR-0015 — Flapo pasa de 16×12 a 24×24

Fecha: 2026-09-08 · Estado: aceptada

## Contexto
El GDD y la guía de arte fijaban a Flapo en 16×12 px. Ese número se eligió en
la Fase 1, antes de que existiera ningún dibujo, y se justificaba como "lee
mejor a 16×12 que un pájaro estilizado".

Al llegar el arte real, la silueta de Flapo resultó ser prácticamente
cuadrada: cuerpo redondo con tripa por delante. Reducirla a 16×12 —una
proporción 4:3 apaisada— aplastaba el dibujo y se comían la tripa, el pico o
el ojo, que son justo los tres rasgos que lo hacen reconocible.

## Opciones
Se generaron los tres frames a 16×12, 16×16, 24×24 y 32×32 desde el mismo
original, cuantizados a la paleta, y se compararon a 1x sobre el cielo real.

- **16×12**: fiel al GDD y sin tocar nada del juego, pero el ala apenas se
  distingue del cuerpo entre frames: la animación de aleteo deja de leerse.
- **16×16**: cuadrado y casi del tamaño previsto, pero sigue perdiendo detalle.
- **24×24**: mantiene silueta, tripa y pico.
- **32×32**: máximo detalle, pero más grande que el pájaro del juego que
  inspira este, lo que endurecería el juego sin haberlo decidido.

## Decisión
24×24, con hitbox de **círculo de radio 8** desplazado 1 px a la derecha para
centrarlo en el cuerpo y no en el lienzo.

El GDD pide que la hitbox sea algo menor que el dibujo, y aquí lo es de sobra:
16 px de diámetro sobre un dibujo de 24. Rozar con la punta del ala o del
pico no mata.

## Consecuencias
- **El hueco de 100 px NO cambia.** Es lo contrario de lo que avisé antes de
  medirlo: el pájaro del Flappy original es 34×24, o sea **24 px de alto**,
  exactamente como este. La proporción hueco/pájaro queda igual que en el
  juego de referencia. Se corrige aquí para que no quede escrito el error.
- La hitbox pasa de radio 5 a radio 8. Los quince ficheros de test siguen en
  verde sin tocar nada, incluidos los de colisión con tubería y suelo.
- `docs/GDD.md` y `docs/art-guide.md` quedan actualizados con el tamaño y la
  hitbox reales.

## Apéndice: el arte de origen no era pixel art
Los ficheros entregados (`flapo-sprite.png` y `flapo-sprite-cuantizado.png`)
son imágenes de 1448×1086 con decenas de miles de colores y cientos de miles
de píxeles con transparencia parcial. No tienen rejilla recuperable: los
tramos de color constante miden 2, 3, 7, 9 y 26 px, y los tres frames ni
siquiera comparten ancho.

Lo que hay en `assets/sprites/` es una **reconstrucción**: recorte por frame,
alineado por pico y patas (para que entre frames solo se mueva el ala),
reducción y cuantización a los 7 colores del sprite. Es fiel al dibujo, pero
no es el dibujo.

Los cuatro tamaños generados quedan en `assets/sprites/src/candidatos/` para
retocar a mano en Pixelorama. **Ese retoque es el cierre real de T-050**: a
24×24 se corrige píxel a píxel en un rato, y solo entonces el sprite será
pixel art dibujado y no una reducción automática.
