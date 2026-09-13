# ADR-0002 — Escalado de pantalla y método de renderizado

Fecha: 2026-09-07 · Estado: aceptada

## Contexto
Flapo es pixel art a 288×512 lógicos y tiene que verse igual en un monitor de
escritorio, en un iframe de itch.io y en un móvil Android de 1080×2400. Un
juego de píxeles perdona muy poco: basta un escalado no entero para que unos
píxeles midan 2 y otros 3, y la imagen "hierve" al hacer scroll.

Además hay que elegir método de render antes de escribir escenas, porque
cambiarlo después obliga a revisar materiales y ajustes.

## Opciones

### Modo de stretch
- **`disabled`**: el viewport crece con la ventana. Ves más mundo en pantallas
  grandes → rompe el diseño (la dificultad depende de cuánto campo ves).
- **`canvas_items`** (lo que puso el asistente por defecto): escala el dibujo
  en coordenadas reales, con decimales. Es lo correcto para UI y para arte de
  alta resolución, pero en pixel art produce píxeles de tamaño desigual.
- **`viewport`**: se renderiza a un buffer de 288×512 reales y ese buffer se
  estira a la ventana. Todo el juego ocurre en la retícula de píxeles.

### Ratio de aspecto
- **`expand`**: mantiene el tamaño del píxel pero muestra más mundo a lo ancho
  o a lo alto según la pantalla. Otra vez, campo de visión variable.
- **`keep`**: mantiene 288×512 exactos y pone barras negras. Encuadre idéntico
  en todas las pantallas.
- **`keep_height`**: fija el alto y deja crecer el ancho.

### Escalado (`scale_mode`, Godot 4.2+)
- **`fractional`**: permite 2,37x. Píxeles desiguales.
- **`integer`**: solo 1x, 2x, 3x… El resto es barra negra.

### Método de renderizado
- **Forward+**: Vulkan/RenderingDevice. **No exporta a Web.** Descartado.
- **Mobile**: también RenderingDevice. Tampoco da WebGL. Descartado.
- **Compatibility**: OpenGL ES 3 / WebGL 2.

## Decisión
`stretch/mode = "viewport"`, `stretch/aspect = "keep"`,
`stretch/scale_mode = "integer"`, `handheld/orientation = "portrait"`,
filtro de textura por defecto `Nearest`, física a 60 Hz y renderizado
**Compatibility**.

La ventana del editor arranca a 576×1024 (`window_width_override`) para que
2x sea el tamaño por defecto y no haya que jugar en un sello de correos; eso
no cambia la resolución lógica.

## Consecuencias
- Píxeles perfectamente cuadrados y encuadre idéntico en todas las pantallas.
- Precio: barras negras. En un móvil 20:9 la barra es notable. Se acepta en
  v1; **T-073** revisará pasar a `keep_height` (fondo que cubre el hueco) una
  vez exista arte de fondo real.
- El filtro `Nearest` global evita tener que acordarse de configurarlo import
  a import (**T-055** solo tendrá que confirmarlo, no arreglarlo).
- 60 Hz de física fija hace el juego determinista y hace que las constantes
  del GDD (px/s) signifiquen siempre lo mismo. Obliga a usar `delta` en
  `_physics_process`, nunca en `_process`, para la física de Flapo.
- Renunciamos a GI, SDFGI, volumétricos y glow avanzado. Para un 2D de 16
  colores no se pierde nada, y el binario web es más pequeño y arranca antes.
- Nadie debe cambiar el renderizador más adelante sin escribir una ADR nueva:
  romperia el export a Web, que es la plataforma principal.
