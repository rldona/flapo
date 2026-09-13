# ADR-0013 — Persistencia: `SaveManager` sin autoload

Fecha: 2026-09-08 · Estado: aceptada

## Contexto
El récord y la cuenta de partidas tienen que sobrevivir a cerrar el juego.
El ticket T-070 pide "`SaveManager` autoload con `ConfigFile` en
`user://save.cfg`", y las ADR-0003 y 0009 daban por hecho que este sí sería
autoload "con motivo: guarda estado y debe sobrevivir a los reinicios de
escena".

Ese motivo dejó de existir con la ADR-0011: el reinicio es **en sitio**, no
recarga la escena. Nada tiene que sobrevivir a nada dentro del proceso.

Y el motivo en contra sigue vigente: un autoload solo se registra al arrancar
el juego, así que no existe en `--check-only` ni en los scripts `-s` de los
tests. Nombrarlo desde `main.gd` habría vuelto a romper la compilación, que
es exactamente lo que costó dos rodeos en T-024 y T-025.

## Decisión
`class_name SaveManager extends RefCounted`, con miembros `static`. El estado
de verdad es el fichero; la copia en memoria es solo una caché.

Regla explícita del fichero: **nunca reventar**. Ausente, corrupto, de otra
versión o con tipos raros devuelve valores por defecto. Perder el récord es
molesto; no poder abrir el juego es un desastre. `user://save.cfg` es texto
plano y editable a mano, así que "tipos raros" no es hipotético: hay un test
que le mete `high_score="muchos"` y `games_played=-40`.

## Consecuencias
- Se resuelve en compilación, como `GameConfig`. Ningún rodeo en los tests.
- `forget_cache()` existe solo para las pruebas: permite simular "cerrar y
  volver a abrir el juego" sin reiniciar el proceso. Es la única forma de
  comprobar de verdad que el récord persiste.
- Un fallo al escribir (disco lleno, permisos) emite `push_warning` y deja
  seguir jugando con los datos en memoria. No se propaga como error.
- Si algún día hace falta estado global vivo de verdad —un gestor de audio
  con buses, por ejemplo (**T-061**)—, ese sí será autoload, y sus tests
  tendrán que pedirlo al árbol tras el primer frame.

## Apéndice: un agujero en la red de seguridad, encontrado aquí

Al escribir esto salió que el refactor de **T-083** había borrado
`Main._on_scored()` dejando un `pipe_spawner.scored.connect(_on_scored)`
apuntando a nada. Llegó a `main` y **el CI lo dio por verde**: los tests solo
ejecutan los caminos que tocan, y el export tampoco lo detectó.

`godot --headless --check-only --script <fichero>` sí lo detecta. Así que
`tests/run.sh` tiene ahora una **fase previa que compila todos los `.gd`** de
`scripts/` y `tests/` antes de ejecutar nada, y falla si alguno no compila.
Se ha comprobado volviendo a borrar la función: la fase la caza.

La lección, que ya es la tercera de este tipo en el proyecto: **un test verde
solo dice que lo ejecutado funciona.** Lo que no se ejecuta necesita otra red
—compilación, lint, export—, y esas redes hay que probarlas rompiendo algo a
propósito.
