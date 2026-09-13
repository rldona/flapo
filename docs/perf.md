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

## Métrica de justicia del bot (T-260)

Línea base del 8 de septiembre de 2026, con `GameConfig` tal y como está hoy.
200 partidas, semillas 1000-1199:

| Medida | Valor |
|---|---|
| Media | **14,77** |
| Mediana | **14** |
| Peor / mejor | 1 / 40 |

Muertes por índice de tubería:

```
    2 | ###################### 6
    3 | #################################### 10
    4 | ################################# 9
    5 | ############### 4
    6 | ################################# 9
    7 | ######################### 7
    8 | ################################# 9
    9 | #### 1
   10 | ######################################## 11
   11 | ############################# 8
   12 | ############### 4
   13 | ############################# 8
   14 | ######################################## 11
   15 | ################## 5
   16 | ######################### 7
   17 | ######################### 7
   18 | ######################### 7
   19 | #################################### 10
   20 | ################################# 9
   21 | ###################### 6
   22 | ################################# 9
   23 | ###################### 6
   24 | ########### 3
   25 | ############################# 8
   26 | ########### 3
   27 | ####### 2
   28 | ####### 2
   29 | ####### 2
   30 | #### 1
   31 | ####### 2
   32 | ############### 4
   33 | ####### 2
   34 | #### 1
   35 | #### 1
   36 | #### 1
   37 | ####### 2
   39 | #### 1
   40 | #### 1
   41 | #### 1
```

**Lectura: no hay un pico, hay una meseta larga.** Ninguna tubería mata
desproporcionadamente: las barras oscilan entre 1 y 11 muertes sin que ninguna
destaque, y la cola se adelgaza suave a partir de la 25. Eso es lo que se
espera de una curva sin escalones — si una tubería tuviera algo que las de al
lado no tienen, su barra sobresaldría del resto.

Lo único con forma es que **la mortalidad no baja hasta la 24**: el bot muere
casi igual en la tubería 5 que en la 20. Con la curva de T-045 apretando el
hueco a la vez que el bot va mejorando, las dos cosas se compensan. No es un
defecto; es un dato para T-040.

El número no es una nota. **Sirve para compararlo consigo mismo** después de
tocar una constante, que es exactamente para lo que existe.

Reproducir:

```
godot --headless --fixed-fps 60 --path . -s tools/bot_flapo.gd -- 200
```

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
