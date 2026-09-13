# Flapo — contexto para Claude

Juego de un solo botón en Godot 4 (GDScript), inspirado en Flappy Bird. El juego y el pájaro protagonista se llaman Flapo: el hermano gordito que quiere volar y le cuesta. Humor amable, nunca burla al jugador (ver docs/GDD.md, "Concepto y tono").
Proyecto de aprendizaje E2E, público. Prioridad: hacerlo bien y explicar por qué, no rápido.

## Fuentes de verdad
- ROADMAP.md: fases y entregables
- TICKETS.md: backlog con criterios de aceptación (T-NNN)
- docs/GDD.md: reglas y constantes del juego
- docs/art-guide.md: resolución, paleta, tamaños
- docs/decisions/: ADRs. Toda decisión técnica relevante genera una nueva ADR.
- docs/testing.md: cómo se verifica el juego en headless
- docs/environment.md: versiones y atajos del editor

## Convenciones
- Godot 4.x, GDScript tipado, `@export` para constantes tuneables, señales en vez de acoplamiento directo.
- Escenas en scenes/, scripts en scripts/, un script por escena, PascalCase para escenas y snake_case para ficheros .gd.
- Constantes de juego centralizadas en un autoload `GameConfig`.
- Una rama por ticket (`feat/T-023-bird`), Conventional Commits, `main` siempre exportable.
- Un ticket por vez. Antes de empezar: leer el ticket y sus criterios. Al terminar: repasar los criterios uno a uno y decir cuáles quedan verificados por ti y cuáles necesita comprobar Raúl en el editor.
- Puedes ejecutar Godot en headless: `./tests/run.sh` y `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/test_x.gd`. Ver docs/testing.md.
- Todo criterio de aceptación comprobable sin ventana (física, estados, señales, colisiones, puntuación, persistencia, fugas de nodos) lo verificas tú con un test en `tests/`, un fichero por ticket. No lo delegues en Raúl.
- Lo que headless no ve (escalado y píxeles, arte, audio, y cómo se siente el juego) sí lo comprueba Raúl: di exactamente qué probar y qué debería verse.
- Explica las decisiones de diseño de Godot (por qué CharacterBody2D y no RigidBody2D, etc.); es un proyecto de aprendizaje.
- Responder en español, conciso.
