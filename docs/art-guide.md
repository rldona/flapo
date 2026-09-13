# Guía de arte

- Resolución base: 288×512 (vertical). Stretch `viewport` + `integer`.
- Paleta: **20 colores** (16 del mundo + 4 de frutas), propia. En `assets/sprites/src/palette.hex` y `.gpl`.

| Uso | Hex | | Uso | Hex |
|---|---|---|---|---|
| Outline | `#263B46` | | Ojo | `#18262D` |
| Cuerpo | `#3F7188` | | Brillo del ojo | `#FFF4D6` |
| Cuerpo sombra | `#31596C` | | Mejillas | `#D98972` |
| Ala | `#4F8298` | | Cielo | `#7CB3D7` |
| Tripa | `#F2D9A7` | | Nubes | `#BFD9EC` |
| Tripa sombra | `#D5B87D` | | Tubería | `#3A5468` |
| Pico y patas | `#E6B84A` | | Suelo | `#D0AE62` |
| Pico sombra | `#B88632` | | Patas sombra | `#D49A3A` |
| | | | Edificios lejanos | `#7C9AB5` |

### Colores de fruta (T-047)

| Fruta | Hex | Efecto |
|---|---|---|
| Azul | `#4FA3C7` | inmunidad a un toque |
| Roja | `#C4553F` | pesa el doble |
| Verde | `#6E9E4F` | el doble de ligero |
| Naranja | `#E6B84A` (mostaza, ya en paleta) | el doble de tamaño |
| Violeta | `#8A6FA8` | el mundo va más lento |

Las frutas miden **16×16**. Empezaron en 12×12 y se subieron tras verlas en
pantalla: a 12 px se perdían contra el fondo mientras el jugador está pendiente
de las tuberías.

Rompen los 16 colores a propósito: son **tonos que el escenario no usa**, y eso
es justo lo que hace que se lean como objetos ajenos al mundo y no como
decorado. Un rojo o un violeta en un fondo de azules y arenas se ve de
inmediato, que es lo que necesita algo que hay que decidir coger o esquivar en
menos de un segundo.

**El sprite de Flapo usa solo 7**: outline, cuerpo, cuerpo sombra, tripa,
tripa sombra, pico/patas y ojo. Cuantos menos colores, más legible a tamaño
pequeño, que es lo que importa.

**Por qué azul petróleo y no azul eléctrico**: el cielo es `#7CB3D7`. Un Flapo
de azul saturado compite con su propio fondo y parece pegado de otro juego.
El `#3F7188` contrasta lo justo sin romper la armonía, y la tripa crema con el
pico mostaza es lo que hace a Flapo reconocible de un vistazo.
**Tubería blandita (T-066)**: se dibuja con el mismo sprite teñido de
`#7FA37B`, un verde apagado que no usa ni el escenario ni las frutas. Tiene
que leerse como "esta es distinta" **en cuanto entra en pantalla**, no al
chocar: por eso es un cambio de color y no un detalle pequeño.

**Tuberías**: `#506982`, el mismo gris azulado de los edificios. Contrasta con
el cielo claro por arriba y con la arena del suelo por abajo, sin meter un
verde que no pega con el resto. Los edificios del parallax van en
`#7C9AB5`, más claros por perspectiva atmosférica, para que no compitan con
las tuberías, que sí son obstáculo.

- Tamaños: **Flapo 24×24** · tubería 26 px ancho · tile de suelo 32 px · botones ≥ 48 px tras escalado.
  El GDD decía 16×12; se subió en T-050 porque a ese tamaño se perdían la
  tripa y el pico, que es lo que hace a Flapo reconocible. 24×24 deja el
  mismo alto que el pájaro del Flappy original (34×24) sobre la misma
  pantalla, así que el hueco de 100 px sigue siendo el correcto.
- Reglas: outline 1 px oscuro, sin anti-aliasing fuera de la paleta, siluetas legibles a 1x.
- Importación en Godot: filtro `Nearest` (por defecto de proyecto, ver
  ADR-0002), sin mipmaps y sin compresión con pérdida. Se comprueba en T-055
  recorriendo los `.import`.
- El cielo es un color plano (`ColorRect`), no una textura: a 288×512 un PNG
  de cielo liso serían 147 KB para no aportar nada.
- El arte que no es Flapo se genera con `tools/generar_arte.py`, para que
  cambiar la paleta sea regenerar y no repintar.
- Fuentes `.pxo` en `assets/sprites/src/`, PNG exportados en `assets/sprites/`.
