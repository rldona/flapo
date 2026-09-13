# Aprendizajes reutilizables

Lo que este proyecto ha enseñado y sirve para el siguiente (el metroidvania).
Es la parte de la retrospectiva (**T-110**) que no depende de horas ni de
sensaciones: sale de las diecisiete ADRs y, sobre todo, de los cinco agujeros
que fue necesario tapar.

## Lo que más valor dio, por orden

### 1. Verificar los supuestos del enunciado antes de organizarse alrededor de ellos
El proyecto arrancó con "el asistente no puede ejecutar el juego" escrito en
`CLAUDE.md`. Era falso: Godot tiene `--headless`. Se descubrió por casualidad
en el ticket T-023, después de tres tickets de rondas manuales innecesarias, y
cambió por completo la forma de trabajar (ADR-0007).

**Para la próxima**: la primera tarea de cualquier proyecto es comprobar qué
se puede automatizar de verdad, no dar por buena la restricción heredada.

### 2. Una afirmación dentro de una ADR es una hipótesis hasta que se ejecuta
La ADR-0003 justificaba usar un autoload diciendo que "se carga también en el
editor, así que las herramientas y los tests lo tienen disponible". Nadie lo
comprobó. Dos tickets después, `--check-only` fallaba y los tests tenían que
buscar el autoload en el árbol con un rodeo. La ADR-0009 lo corrigió.

**Para la próxima**: si una ADR afirma algo técnico, se ejecuta el comando y
se pega el resultado en la propia ADR.

### 3. Un test verde solo dice que lo ejecutado funciona
Tres agujeros distintos, el mismo patrón:

| Se escapó | Lo tapó |
|---|---|
| Un refactor borró `Main._on_scored()` y dejó un `connect` colgando. CI verde. | Fase que compila todos los `.gd` antes de ejecutar nada. |
| Un `Label` pasó a `TextureRect` y el test dio `Invalid access`… y el resumen dijo "0 fallos". | El runner falla ante cualquier `SCRIPT ERROR`. |
| Un lambda capturaba una local **por valor**, así que un test pasaba sin comprobar nada. | El flag pasa a ser miembro de la clase. |

**Para la próxima**: cada red de seguridad hay que probarla **rompiendo algo a
propósito**. Si no, solo sabes que no ha saltado, no que funcione.

### 4. Lo que se mide se puede decidir; lo que no, se discute
Criterios como "no quedan nodos huérfanos tras 5 minutos" o "sin salto visible
al reciclar" parecían cosa de mirar con paciencia. Convertidos en medidas son
un bucle de 18.000 ticks en 0,36 s, y un "peor hueco descubierto: 0,000000 px".

Lo mismo con el *game feel*: `tools/medir_feel.gd` no decide el tuning, pero
convierte "se siente pesado" en "un aleteo sube 2,4 alturas de Flapo y entre
tuberías caben 4,6 aleteos". Se sigue decidiendo a ojo, pero sabiendo qué.

### 5. El editor es el dueño de sus ficheros
`project.godot`, los `.tscn` y los `.import` los reescribe Godot con su propio
formato: borra los valores que coinciden con el defecto, añade `uid` y
`unique_id`, y normaliza la serialización de los eventos de entrada. Escribirlos
a mano vale para expresar la intención; la forma final la impone el editor y es
la que se commitea.

Y hay detalles que **solo** funcionan en la forma canónica: un `@export` tipado
como nodo necesita `node_paths=PackedStringArray("...")` en la cabecera, o
queda en `null` **en silencio**.

## Cosas concretas de Godot que costaron tiempo

- `Input.action_press()` no sirve para simular entrada en tests: no cuadra los
  contadores de frame de `is_action_just_pressed()`. Hay que inyectar un
  `InputEventKey` con `Input.parse_input_event()` — **y soltar la tecla**.
- Sin `--fixed-fps`, headless sincroniza con el reloj de pared: simular 5
  minutos tarda 5 minutos. Con él, 0,36 s.
- Un `await` está atado a la vida del nodo. Un hit-stop que ponía
  `Engine.time_scale = 0` y lo restauraba tras un `await` congelaba el motor
  **para siempre** si la escena se liberaba antes. Se cuenta en frames.
- Los sub-recursos de un `.tscn` se **comparten** entre instancias: una forma
  de colisión guardada en la escena es el mismo objeto en las 188 tuberías de
  una partida.
- Un `ColorRect` a pantalla completa se come todos los clicks:
  `mouse_filter` por defecto es `Stop`.
- `lerp(a, b, 0.2)` por frame depende de los fps. La forma correcta es
  `1.0 - exp(-velocidad * delta)`.
- `get_display_safe_area()` devuelve píxeles **reales**, no de juego: en un
  móvil de 2400 de alto, un notch de 100 px son 21 px de juego.
- Los autoloads no existen en `--check-only` ni en los scripts `-s`. Si no
  tiene estado, un `class_name` es mejor.

## Sobre el proceso

- **Una ADR por decisión, escrita en el momento**, no al final. Diecisiete
  ADRs y todas se han consultado o corregido después. Dos se sustituyeron.
- **Un fichero de test por ticket**, con el criterio de aceptación como
  docstring. Cerrar un ticket deja de ser una opinión.
- **El arte y el audio generados por código** (ADR-0016, ADR-0017) hacen que
  cambiar la paleta sea regenerar en vez de repintar. Cuando la paleta cambió
  —y cambió— costó un comando.
- **Distinguir "placeholder en calidad" de "placeholder en integración"**. El
  arte generado está montado, importado y probado; sustituirlo es cambiar un
  PNG. Eso permitió cerrar la Fase 4 sin bloquear en el dibujo.

## Lo que haría distinto desde el principio

1. Comprobar qué se puede ejecutar y automatizar **antes** del primer ticket.
2. Montar el arnés de tests en la Fase 0, no en la 2.
3. Poner `gdformat` y `gdlint` desde el primer commit, no con 17 problemas ya
   acumulados.
4. Fijar la paleta **antes** de escribir un solo color en una escena.
5. No escribir tamaños de sprite en el GDD antes de ver un dibujo: los 16×12
   iniciales resultaron ser un número inventado, y el arte real pedía 24×24.
