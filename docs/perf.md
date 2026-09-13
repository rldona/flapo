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

Línea base del 9 de septiembre de 2026, con `GameConfig` tal y como está hoy —
ya con térmicas (T-203), rebufo (T-204), tramo especial (T-067) y el nido
(T-209) dentro del juego. 200 partidas, semillas 1000-1199:

| Medida | Valor |
|---|---|
| Media | **13,35** |
| Mediana | **12** |
| Peor / mejor | 1 / 53 |

Muertes por índice de tubería:

```
    2 | ################################ 12
    3 | ############# 5
    4 | ######################################## 15
    5 | ################### 7
    6 | ################### 7
    7 | ##################### 8
    8 | ########################### 10
    9 | ################### 7
   10 | ############################# 11
   11 | ########################### 10
   12 | ######## 3
   13 | ##################### 8
   14 | ##################### 8
   15 | ######## 3
   16 | ########### 4
   17 | ############# 5
   18 | ######################## 9
   19 | ##################### 8
   20 | ############# 5
   21 | ########################### 10
   22 | ##################### 8
   23 | ################ 6
   24 | ################ 6
   25 | ### 1
   26 | ##################### 8
   27 | ########### 4
   28 | ##### 2
   29 | ##### 2
   31 | ### 1
   32 | ##### 2
   34 | ### 1
   35 | ##### 2
   38 | ### 1
   54 | ### 1
```

Muertes por causa:

```
  TUBERIA         200  (100 %)
WARNING: 41 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2536)
ERROR: 6 resources still in use at exit (run with --verbose for details).
   at: clear (core/io/resource.cpp:822)
```

**Lectura 1: no hay pico, hay una meseta.** Ninguna tubería mata
desproporcionadamente. Es lo que se espera de una curva sin escalones: si una
tuviera algo que las de al lado no tienen, su barra sobresaldría.

**Lectura 2: el bot muere siempre contra una tubería, nunca contra el suelo.**
El 100 % es un dato sobre el bot antes que sobre el juego —su política aletea
en cuanto se ve por debajo del objetivo, así que no toca el suelo jamás— pero
la columna sirve igual, y sirve **para lo que venga**: el día que un cambio en
`GameConfig` empiece a producir muertes por suelo, esa cifra dejará de ser 100
y lo dirá antes de que nadie lo note jugando. Un pico por tubería en el índice
12 dice "ese hueco está mal colocado"; el mismo pico por suelo diría "a esa
altura de la curva ya no se llega arriba". Son dos diagnósticos distintos y
antes se veían iguales.

El número no es una nota. **Sirve para compararlo consigo mismo** después de
tocar una constante, que es para lo que existe.

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
