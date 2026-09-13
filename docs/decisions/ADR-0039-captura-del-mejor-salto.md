# ADR-0039 — La captura se compone, no se fotografía

Fecha: 2026-09-09 · Estado: aceptada · Depende de [ADR-0002](ADR-0002-pixel-perfect.md)

## Contexto
T-077 quiere que al batir el récord se genere una imagen de los últimos
segundos de vuelo, para compartir. El ticket propone `Viewport.get_texture()`
y añade: "documentar en ADR si se necesita algo no trivial en Godot 4".

Se necesita. Pero no en la dirección que sugiere el ticket.

## Decisión
La imagen **se compone a mano**: cielo del escenario de esa partida (T-057),
siluetas de las tuberías del último instante y **Flapo repetido seis veces** a
lo largo de su arco, del más transparente al más opaco.

Una cronofotografía, no una foto fija.

## Por qué no `Viewport.get_texture()`
Dos motivos, y el primero es el que decide:

**1. En headless no hay render.** `get_texture().get_image()` no devuelve nada
sin ventana. El criterio de aceptación del propio ticket —"test en `tests/`
que compruebe que la captura solo se dispara al superar récord"— sería
inverificable, y con él todo lo demás. Un ticket cuya única prueba posible es
que Raúl mire la imagen no es un ticket verificable.

**2. En Web, leer el framebuffer es asíncrono** y depende del navegador. Hay
que esperar al final del frame, y aun así el resultado varía. Una captura que
a veces sale negra es peor que no tener captura.

Componiendo la imagen, lo que sale es **idéntico** en el navegador, en Android
y en un test sin ventana. Y es determinista, así que se puede comprobar píxel
a píxel.

## Y encima queda mejor
Una captura de pantalla enseña el frame en el que te estrellaste. Esta enseña
**cómo volabas**: el arco entero de los últimos dos segundos, con Flapo
desvaneciéndose hacia atrás. Es lo que uno quiere enseñar de un récord.

Que el diseño técnico honesto coincida con el mejor resultado no siempre pasa;
aquí ha pasado.

## Lo que cuesta
- **`blend_rect` no acepta un tinte**, así que las siluetas transparentes hay
  que fabricarlas píxel a píxel. Son 16×12 píxeles seis veces: cuesta menos
  que discutirlo.
- Las tuberías se dibujan como **rectángulos**, no con su sprite. La captura
  cuenta un vuelo, no enseña arte, y una silueta se lee mejor a tamaño de red
  social.
- Solo se dibujan las tuberías **del último instante**. Dibujar las de cada
  muestra dejaría la imagen llena de rayas y no se entendería por dónde se
  pasó.

## Detalles que importan
- **La estela es un anillo** de seis muestras. Si creciera con la partida, una
  partida larga se llevaría por delante la memoria de un móvil de gama baja.
  Se vacía al empezar cada partida: la captura es de **esta**.
- **La imagen sale a x3** (864×1536). A 1x, cualquier red social la reescala y
  la emborrona. Escala **entera** y `INTERPOLATE_NEAREST`, por lo de siempre
  (ADR-0002): media escala convierte el pixel art en papilla.
- **En un Game Over normal no se pide siquiera.** Componer una imagen que
  nadie va a compartir es trabajo tirado, y en un móvil eso se nota.

## Una trampa del test que hubo que arreglar
La primera versión comprobaba el tamaño de la imagen contra
`GameConfig.SNAPSHOT_SCALE`. Eso no comprueba nada: al cambiar la constante se
mueven los dos lados de la comparación. Se verificó rompiéndolo —bajando la
escala a 1— y el test seguía en verde.

Ahora se compara contra lo que de verdad importa: que la imagen sea **al menos
el doble** que el playfield, múltiplo entero y con la proporción intacta.

## Consecuencias
- La captura vive en `user://mejor_salto.png` y se pisa en cada récord nuevo.
  Es la del mejor salto, no un álbum.
- **Falta engancharla al botón de compartir.** Hoy se genera el fichero y no
  se ofrece: en Web, compartir una imagen necesita `navigator.share` con
  ficheros vía `JavaScriptBridge`, que es justo lo que trae T-280. Se deja
  anotado ahí en vez de hacer media integración ahora.
