# Guía de arte

- Resolución base: 288×512 (vertical). Stretch `viewport` + `integer`.
- Paleta: 16 colores, propia. En `assets/sprites/src/palette.hex` y `.gpl`.

| Uso | Hex | | Uso | Hex |
|---|---|---|---|---|
| Outline | `#263B46` | | Ojo | `#18262D` |
| Cuerpo | `#3F7188` | | Brillo del ojo | `#FFF4D6` |
| Cuerpo sombra | `#31596C` | | Mejillas | `#D98972` |
| Ala | `#4F8298` | | Cielo | `#7CB3D7` |
| Tripa | `#F2D9A7` | | Nubes | `#BFD9EC` |
| Tripa sombra | `#D5B87D` | | Edificios | `#506982` |
| Pico y patas | `#E6B84A` | | Suelo | `#D0AE62` |
| Pico sombra | `#B88632` | | Patas sombra | `#D49A3A` |

**El sprite de Flapo usa solo 7**: outline, cuerpo, cuerpo sombra, tripa,
tripa sombra, pico/patas y ojo. Cuantos menos colores, más legible a tamaño
pequeño, que es lo que importa.

**Por qué azul petróleo y no azul eléctrico**: el cielo es `#7CB3D7`. Un Flapo
de azul saturado compite con su propio fondo y parece pegado de otro juego.
El `#3F7188` contrasta lo justo sin romper la armonía, y la tripa crema con el
pico mostaza es lo que hace a Flapo reconocible de un vistazo.
- Tamaños: Flapo 16×12 · tubería 26 px ancho · tile de suelo 32 px · botones ≥ 48 px tras escalado.
- Reglas: outline 1 px oscuro, sin anti-aliasing fuera de la paleta, siluetas legibles a 1x.
- Importación en Godot: filtro `Nearest`, sin mipmaps.
- Fuentes `.pxo` en `assets/sprites/src/`, PNG exportados en `assets/sprites/`.
