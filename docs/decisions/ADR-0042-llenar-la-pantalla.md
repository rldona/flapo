# ADR-0042 — Llenar la pantalla: se cede el píxel exacto, no el campo de visión

Fecha: 2026-09-09 · Estado: aceptada · Sustituye la elección de aspecto y escala de [ADR-0002](ADR-0002-escalado-y-render.md)

## Contexto
ADR-0002 eligió `aspect = "keep"` y `scale_mode = "integer"`, y **dijo
explícitamente** que eso pone barras negras. Se aceptó a cambio de dos cosas:
píxeles de tamaño exacto y encuadre idéntico en toda pantalla.

En un móvil real eso significa que el juego ocupa **poco más de la mitad de la
pantalla**, rodeado de negro. Raúl lo probó y lo dijo dos veces. Visto en el
teléfono no se lee como una decisión: se lee como que el juego no cabe.

Antes de esta ADR se intentó lo barato: pintar las barras del color del cielo.
No sirve — **Godot dibuja el letterbox en negro y no usa el clear color**, ni
en modo `viewport` ni en `canvas_items`. Se comprobó en el navegador con los
dos modos.

## Decisión
`aspect = "keep_width"` y `scale_mode = "fractional"`.

El juego llena la pantalla entera. No queda una sola barra.

## Qué se cede y qué no
Hay dos cosas que ADR-0002 protegía y **no son igual de importantes**:

**El campo de visión se mantiene, y es lo que importa.** `keep_width` fija el
ancho en 288 px siempre. Cuántas tuberías ves venir —el aviso que tienes para
colocarte— es idéntico en cualquier pantalla. **La dificultad no cambia**, y
esa era la objeción de fondo de ADR-0002 contra `expand`, que sí variaba el
ancho visible.

Lo que crece es el **alto**, y ahí solo aparece más cielo y más suelo: la banda
jugable está entre el techo (`ceiling_y`) y el suelo, que son coordenadas
fijas del mundo. Ver más margen arriba y abajo no cambia ni un hueco.

**El píxel exacto se cede.** Con escala fraccionaria, algunos píxeles del
sprite ocupan 3 píxeles físicos y otros 2. Es real y es el precio.

Lo que hace que el precio sea asumible es **dónde se juega**: un móvil tiene
densidad de 2x o 3x, así que la diferencia entre 2,60x y 3x cae por debajo de
lo que el ojo distingue. En un monitor a 1x se notaría más, y por eso se deja
anotado: si algún día molesta en escritorio, la salida es escalar la ventana a
múltiplos exactos ahí y dejar fraccional solo en táctil.

## El cielo cubre el viewport, no 288×512
Con el viewport más alto que el diseño, por encima del rectángulo del cielo se
veía el color de fondo de la ventana — azul de día **aunque la partida fuera
de noche** (T-057). El `ColorRect` del cielo pasa a anclarse al viewport
completo, así que cubre lo que haya.

## En el navegador hacía falta además CSS
El canvas de la exportación web **no llenaba la ventana**: el shell de Godot
no le da tamaño, así que alrededor se veía el `body`, negro. Se inyecta por
`html/head_include` un `<style>` que pone el canvas a `100vw`/`100vh` y el
fondo del documento al color del cielo.

Va con `!important` y no es capricho: el `head_include` se inserta **antes**
del `<style>` propio de Godot, así que sin él lo pisa `body { background-color:
black; }`. Se descubrió mirando el CSS servido, después de que el arreglo
"funcionara" sin cambiar nada en pantalla.

## Consecuencias
- ADR-0002 sigue vigente en todo lo demás: resolución lógica de 288×512,
  filtro `Nearest`, física a 60 Hz y renderizado Compatibility.
- Las 52 comprobaciones headless siguen en verde: nada del juego depende del
  tamaño de la ventana, que es lo que permitía hacer este cambio sin miedo.
- T-086 (contenido en el espacio sobrante) **se queda sin espacio sobrante**.
  Habrá que replantearlo o cerrarlo.
