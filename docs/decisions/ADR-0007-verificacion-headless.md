# ADR-0007 — Verificación headless desde el día uno

Fecha: 2026-09-07 · Estado: aceptada · Sustituye en la práctica a una nota de `CLAUDE.md`

## Contexto
El proyecto arrancó suponiendo que el asistente no podía ejecutar el juego:
`CLAUDE.md` decía "No puedes ejecutar el juego" y el protocolo era que el
asistente describiera qué probar y Raúl lo comprobara en el editor.

Ese supuesto era falso. Godot 4 admite `--headless`, que arranca sin ventana
ni GPU, y `-s script.gd`, que ejecuta un script que extiende `SceneTree`.
Con eso se puede montar `Main.tscn`, avanzar ticks de física, inyectar
entrada y leer estado.

Se descubrió resolviendo un bug real de T-023: `Main.bird` quedaba en `null`
porque el `.tscn` escrito a mano no declaraba `node_paths`. Con el protocolo
anterior habrían hecho falta varias rondas de "prueba esto y pégame la
consola"; en headless el diagnóstico fue una ejecución.

## Opciones
- **Mantener el protocolo manual**: cada criterio de aceptación cuesta una
  ronda de ida y vuelta, y lo que se verifica es lo que una persona *cree*
  haber visto. Los bugs silenciosos (un `null`, una señal sin conectar) se
  escapan porque no se ven.
- **Esperar a T-080** e instalar GUT/gdUnit4 en la Fase 7. Correcto a largo
  plazo, pero deja las fases 2 y 3 —justo las que meten la lógica— sin red.
- **Un arnés mínimo propio ahora**, migrable a GUT/gdUnit4 en T-080.

## Decisión
Arnés mínimo en `tests/`, con `harness.gd` (unas 60 líneas: montar escena,
inyectar entrada, contar fallos), un fichero por ticket y `tests/run.sh` como
punto de entrada. Documentado en `docs/testing.md`.

Cambia el reparto de responsabilidades:

| Verifica | Qué |
|---|---|
| El asistente, en headless | física, máquina de estados, señales, colisiones, puntuación, persistencia, fugas de nodos |
| Raúl, en el editor | escalado y píxeles, arte y animación, audio, y **cómo se siente** el juego |

`CLAUDE.md` se actualiza en consecuencia.

## Consecuencias
- Cada ticket de código se cierra con evidencia ejecutable en vez de con una
  descripción. Los criterios de aceptación dejan de ser prosa.
- Criterios que antes eran incomprobables pasan a serlo automáticamente:
  "no quedan nodos huérfanos tras 5 minutos" (T-024) y "reiniciar 50 veces no
  acumula nodos ni timers" (T-028) son bucles, no paciencia.
- Los tests corren en segundos y sin GPU, así que **T-091** puede ejecutarlos
  en CI dentro del contenedor `godot-ci` antes de exportar. Queda anotado
  ahí; no se cablea en esta ADR para no tocar el workflow sin poder probarlo.
- Coste: código de test que habrá que migrar en **T-080**. Se asume; el
  arnés es deliberadamente pequeño para que migrarlo sea barato.
- Riesgo: confundir "los tests pasan" con "el juego es bueno". Headless no
  ve nada y no juega. El tuning de la Fase 3 sigue siendo humano, y esta ADR
  no cambia eso.
- El hallazgo de fondo, aplicable más allá de Godot: **una limitación heredada
  del enunciado debe verificarse antes de organizar el trabajo alrededor de
  ella.** Aquí costó tres tickets de rondas manuales innecesarias.
