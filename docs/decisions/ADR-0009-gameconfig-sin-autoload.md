# ADR-0009 — `GameConfig` deja de ser autoload

Fecha: 2026-09-07 · Estado: aceptada · Sustituye el mecanismo de [ADR-0003](ADR-0003-gameconfig.md)

## Contexto
La ADR-0003 decidió que las constantes compartidas vivieran en un autoload
`GameConfig`. La regla que estableció —lo compartido aquí, lo que se tunea a
ojo como `@export` en su nodo, lo derivado como función— ha funcionado bien y
**no cambia**. Lo que falla es el mecanismo.

Un autoload solo se registra cuando arranca el juego. Fuera de ese arranque no
existe, y eso rompió dos cosas seguidas:

1. `godot --headless --check-only --script scripts/pipe_spawner.gd` falla con
   `Identifier not found: GameConfig`, así que no se puede comprobar que un
   script compila sin lanzar el juego entero.
2. Un script lanzado con `-s` (todos los tests, ADR-0007) se compila antes de
   registrar autoloads: nombrar `GameConfig` impedía que el test arrancara.
   Hubo que añadir al arnés un `config()` que lo buscaba en el árbol después
   del primer frame. Un rodeo para leer una constante.

La ADR-0003 argumentaba que el autoload "se carga también en el editor, así
que las herramientas y los tests headless lo tienen disponible sin montar
nada". Era falso, y no se comprobó al escribirla.

## Opciones
- **Seguir con el autoload y rodearlo** con `get_node("/root/GameConfig")` en
  tests y herramientas. Funciona, pero pierde el tipado, obliga a esperar al
  primer frame y deja `--check-only` inservible.
- **Duplicar las constantes** en un fichero para el juego y otro para tests:
  absurdo, es exactamente lo que la ADR-0003 quería evitar.
- **Convertirlo en `class_name GameConfig extends RefCounted`**, con las
  constantes como `const` y lo derivado como `static func`. Un `class_name` se
  resuelve **en tiempo de compilación** desde el registro global de clases, y
  está disponible en el juego, en el editor, en `--check-only` y en `-s`.

## Decisión
`class_name GameConfig extends RefCounted`. Se elimina la entrada de
`[autoload]` en `project.godot` y `Harness.config()` desaparece.

El fondo del asunto: `GameConfig` **no tiene estado**. Un autoload es un nodo
vivo en el árbol, y eso solo hace falta si algo tiene que existir, recordar o
recibir señales. Para un puñado de constantes es la herramienta equivocada.
`SaveManager` (**T-070**) sí será autoload, y con motivo: guarda estado y debe
sobrevivir a los reinicios de escena.

## Consecuencias
- `GameConfig.SCROLL_SPEED` se resuelve en compilación: un error de nombre lo
  detecta `--check-only` en vez de aparecer al ejecutar.
- Los tests lo usan directamente, sin rodeos ni esperas.
- El registro de `class_name` vive en `.godot/global_script_class_cache.cfg`,
  que **está ignorado por git**. Tras clonar, o al añadir un `class_name`
  nuevo sin abrir el editor, hay que regenerarlo:
  `godot --headless --path . --import`. Está en `docs/testing.md`.
- La regla de la ADR-0003 sobre dónde vive cada constante sigue vigente; lo
  único que cambia es que `GameConfig` ya no es un nodo.
- Lección repetida, la segunda en este proyecto tras la de ADR-0007: **una
  afirmación técnica dentro de una ADR es una hipótesis hasta que se ejecuta.**
  Aquí la hipótesis "el autoload está disponible en tooling" se escribió sin
  comprobarla y costó dos rodeos.
