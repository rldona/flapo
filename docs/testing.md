# Verificación headless

Godot se puede ejecutar sin ventana ni GPU. Eso permite comprobar el juego
desde la terminal —y por tanto desde un asistente o desde CI— en lugar de
depender de que una persona mire la pantalla y describa lo que ve.

Es la referencia técnica de cómo se verifica Flapo. La decisión y sus
motivos están en [ADR-0007](decisions/ADR-0007-verificacion-headless.md).

## Ejecutar

```bash
./tests/run.sh
```

Sale con 0 solo si todas las comprobaciones pasan. El binario se toma de la
variable `GODOT`, con el valor por defecto de macOS:

```bash
GODOT=/ruta/a/godot ./tests/run.sh
```

Un solo fichero:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/test_t023_bird.gd
```

## Comandos útiles

| Qué | Comando |
|---|---|
| Comprobar que un script compila | `godot --headless --path . --check-only --script scripts/bird.gd` |
| Importar assets sin abrir el editor | `godot --headless --path . --import` |
| Ejecutar un script de `SceneTree` | `godot --headless --path . -s tests/test_x.gd` |
| Exportar | `godot --headless --path . --export-release Web export/Web/index.html` |

En macOS el binario está dentro del `.app` y no en el `PATH`:
`/Applications/Godot.app/Contents/MacOS/Godot`. Ver `docs/environment.md`.

## Cómo se escribe una comprobación

Cada fichero `tests/test_*.gd` extiende `SceneTree` y usa `tests/harness.gd`:

```gdscript
extends SceneTree

var h: Harness

func _init() -> void:
	h = Harness.new(self)
	var main: Node = await h.montar("res://scenes/Main.tscn", {"log_transitions": false})
	main.change_state(GameState.State.PLAYING)
	await h.ticks(60)
	h.check("Flapo cae", main.bird.position.y > 256.0, "y = %.2f" % main.bird.position.y)
	quit(h.resumen("T-0NN"))
```

Convenciones:

- Un fichero por ticket: `tests/test_t023_bird.gd`.
- Una función por criterio de aceptación, con el criterio en el docstring.
- `check()` siempre con los **números reales** en `detalle`. Un "FALLO" sin
  cifras obliga a volver a instrumentar a mano.
- Liberar la escena (`main.free()`) al final de cada caso: los tests de fugas
  de nodos (T-024, T-028) dependen de que los casos no se contaminen.

## Trampas conocidas

Las tres cuestan una tarde si se descubren solas:

1. **`Input.action_press()` no simula entrada.** No cuadra los contadores de
   frame que usa `is_action_just_pressed()`, así que la pulsación se pierde
   dentro de `_physics_process`. Hay que inyectar un evento real con
   `Input.parse_input_event()` — es lo que hace `Harness.pulsa()`.
2. **Hay que soltar la tecla.** Si un caso deja el espacio pulsado, el
   siguiente no genera flanco de subida y falla por un motivo que no es el que
   se está probando.
3. **`_ready()` no corre al hacer `add_child()` desde `_init()`** de un
   `SceneTree`: se difiere al primer frame de proceso. Por eso `montar()`
   hace `await process_frame`, y por eso las propiedades se asignan **antes**
   de entrar al árbol.

## Qué NO cubre esto

Headless no tiene ventana ni renderiza. Queda fuera, y lo comprueba Raúl en
el editor:

- Escalado entero y píxeles cuadrados (T-020).
- Que el arte se vea bien, la animación y el parallax.
- **Cómo se siente el juego**: peso del salto, legibilidad, dificultad. Es lo
  que se tunea en T-040 y ningún test puede juzgar.

## Relación con T-080

Esto no es un framework de tests: es lo mínimo para comprobar criterios de
aceptación desde el día uno. En **T-080** (Fase 7) se instala GUT o gdUnit4 y
estos ficheros se migran a su formato. El `harness.gd` desaparecerá entonces.
