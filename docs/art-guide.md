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
| | | | Edificios lejanos | `#7C9AB5` |

**El sprite de Flapo usa solo 7**: outline, cuerpo, cuerpo sombra, tripa,
tripa sombra, pico/patas y ojo. Cuantos menos colores, más legible a tamaño
pequeño, que es lo que importa.

**Por qué azul petróleo y no azul eléctrico**: el cielo es `#7CB3D7`. Un Flapo
de azul saturado compite con su propio fondo y parece pegado de otro juego.
El `#3F7188` contrasta lo justo sin romper la armonía, y la tripa crema con el
pico mostaza es lo que hace a Flapo reconocible de un vistazo.
**Tuberías**: `#506982`, el mismo gris azulado de los edificios. Contrasta con
el cielo claro por arriba y con la arena del suelo por abajo, sin meter un
verde que no pega con el resto. Los edificios del parallax van en
`#7C9AB5`, más claros por perspectiva atmosférica, para que no compitan con
las tuberías, que sí son obstáculo.

- Tamaños: Flapo 16×12 · tubería 26 px ancho · tile de suelo 32 px · botones ≥ 48 px tras escalado.
- Reglas: outline 1 px oscuro, sin anti-aliasing fuera de la paleta, siluetas legibles a 1x.
- Importación en Godot: filtro `Nearest`, sin mipmaps.
- Fuentes `.pxo` en `assets/sprites/src/`, PNG exportados en `assets/sprites/`.
