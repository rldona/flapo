# Guía de arte

- Resolución base: 288×512 (vertical). Stretch `viewport` + `integer`.
- Paleta: 16 colores. Elegir en https://lospec.com/palette-list y guardar en `assets/sprites/src/palette.hex`.
- Tamaños: Flapo 16×12 · tubería 26 px ancho · tile de suelo 32 px · botones ≥ 48 px tras escalado.
- Reglas: outline 1 px oscuro, sin anti-aliasing fuera de la paleta, siluetas legibles a 1x.
- Importación en Godot: filtro `Nearest`, sin mipmaps.
- Fuentes `.pxo` en `assets/sprites/src/`, PNG exportados en `assets/sprites/`.
