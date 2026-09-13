# Rendimiento

Objetivo del ROADMAP: **60 fps estables en un Android de gama baja y sin fugas
de nodos.**

## Qué se mide automáticamente

`tests/test_t082_perf.gd` corre en cada push (T-091) y comprueba tres cosas:

| Medida | Resultado | Umbral |
|---|---|---|
| Nodos tras 5 min de partida continua | 76 → **76**, pico 76 | no crecer |
| Coste de un frame de física con el mundo lleno | **~75 µs** | < 1000 µs |
| Huérfanos y tamaño del árbol tras 30 partidas completas | **0 huérfanos**, 54 → 54 nodos | idéntico |

Los 75 µs son sobre un M1 Pro en headless y **no son una medida de fps**: no
hay render. Sirven como alarma de regresión, no como cifra de rendimiento.
Un frame a 60 fps dispone de 16.667 µs, así que la lógica del juego ocupa hoy
un 0,45 % del presupuesto: todo lo demás será dibujado.

## Por qué no crece el número de nodos

- Las tuberías se liberan solas al salir de pantalla (ADR-0008). El pico
  simultáneo es de 3.
- El suelo son dos tiles que se recolocan con `fmod`, no nodos nuevos
  (ADR-0010).
- El reinicio es en sitio y cada sistema se limpia al recibir `READY`
  (ADR-0011); no se reconstruye el árbol.

## Qué NO cubre esto

Headless no dibuja. Queda fuera y hay que medirlo en un dispositivo real:

- **fps reales** en un Android de gama baja, que es el objetivo del ROADMAP.
- Coste de render: relleno de píxeles, cambios de textura, el parallax.
- Tiempo de arranque y de carga del `.pck` en Web.
- Memoria y consumo de batería.

Para eso: exportar a Android (T-092), ejecutar en un dispositivo con el
monitor de rendimiento del editor conectado por depuración remota, y anotar
aquí los resultados. **Sigue pendiente y no puede automatizarse.**

## Presupuesto de tamaño

| Artefacto | Tamaño |
|---|---|
| `index.pck` (Web) | ~800 KB |
| `index.wasm` | ~38 MB (sin comprimir; el servidor lo sirve con gzip) |
| Audio (5 `.wav`) | ~40 KB |

El `.wasm` es el runtime de Godot y no depende de nuestro contenido. Si el
`.pck` se acerca a los 5 MB conviene revisar: hoy el 90 % es arte y audio
generados, que son diminutos.
