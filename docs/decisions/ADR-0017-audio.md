# ADR-0017 — Audio: efectos generados, buses y silencio

Fecha: 2026-09-08 · Estado: aceptada

## Contexto
La Fase 5 pide cinco efectos (aleteo, punto, golpe, caída, botón), buses de
SFX y música separados, y un botón de silencio que sobreviva a cerrar el
juego. La música es opcional y el Flappy original no la tenía.

## Decisión

### Los efectos se sintetizan por código
`tools/generar_audio.py` produce los cinco `.wav` con ondas simples estilo
jsfxr. Mismo criterio que el arte (ADR-0016): reproducible, ajustable
cambiando un número, y sin licencias de terceros que rastrear —lo que importa
en un proyecto público que va a tiendas.

Detalle que no es obvio: **todos llevan envolvente de ataque y caída**. Sin
ella, cada sonido empieza y acaba con un salto brusco de amplitud que se oye
como un chasquido, y con cinco efectos solapándose el resultado es un juego
que "crepita".

Los sonidos siguen la intención del GDD: el aleteo es grave y con cuerpo
porque Flapo pesa, el punto es lo único que **sube** porque es lo único que
premia, y el golpe es ruido con caída de tono, el batacazo.

### `AudioDirector` es un nodo de la escena, no un autoload
Con el reinicio en sitio (ADR-0011) la escena no se recarga, así que nada
tiene que sobrevivirle. Y un `class_name` se resuelve en compilación mientras
que un autoload no (ADR-0009). Tercera vez que se aplica el mismo criterio,
y ya es norma: **autoload solo si algo tiene que existir fuera del árbol.**

**Un `AudioStreamPlayer` por efecto.** Compartir uno haría que un aleteo
cortase el sonido del punto, y es justo cuando más se solapan: se puntúa
aleteando.

### Los sonidos cuelgan de eventos, no de la entrada
`Bird` emite `flapped` y `Main` lo conecta a `AudioDirector.play_flap`. Si el
sonido colgara de la acción `flap`, sonaría también cuando pulsar no hace
nada. Es "signal up" otra vez (ADR-0005).

### El silencio va en `Settings`, aparte del progreso
`user://settings.cfg` frente a `user://save.cfg`: borrar la partida no debería
desactivar el mute, ni al revés. Misma regla de oro que `SaveManager`: nunca
reventar (ADR-0013).

Silenciar apaga los **buses**, no baja el volumen de cada reproductor: así al
quitar el mute todo vuelve exactamente como estaba, sin recordar valores.

## Consecuencias
- Cero audio de terceros. `assets/audio/CREDITS.md` lo dice explícitamente y
  queda listo para anotar licencias si algún día entra algo de fuera.
- El mute persiste entre sesiones y **no lo toca el reinicio**: es un ajuste,
  no estado de partida. Hay test para las dos cosas.
- **T-062 (música) se deja sin hacer**, y no por falta de tiempo: el Flappy
  original no tiene música, el GDD la marca opcional, y un loop mediocre
  cansa más que el silencio en un juego de partidas de veinte segundos. Si
  se añade, el bus `Music` ya existe y está a −6 dB.
- Los `.wav` sin comprimir pesan 40 KB en total. En Web se descargan con el
  `.pck`, así que no compensa pasarlos a OGG todavía; se revisará si el
  paquete crece.
