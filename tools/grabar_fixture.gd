extends SceneTree
## Genera el replay de referencia de `tests/fixtures/` (T-261).
##
##     godot --headless --fixed-fps 60 --path . -s tools/grabar_fixture.gd
##
## Usa el bot de T-260 como jugador para que la partida sea reproducible sin
## que nadie tenga que jugarla a mano. El fichero que sale se versiona: es el
## que el test compara para siempre.

const MAIN := "res://scenes/Main.tscn"
const DESTINO := "res://tests/fixtures/referencia.replay"
const SEMILLA: int = 1000


func _init() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = load(MAIN).instantiate()
	main.log_transitions = false
	root.add_child(main)
	await process_frame
	var r: Dictionary = await BotPilot.new().jugar(self, main, SEMILLA)
	var rep: Replay = main.replay_recorder.replay()
	rep.score = int(r["score"])
	var ok: bool = rep.guardar(DESTINO)
	print(
		(
			"semilla %d · %d puntos · %d flancos · guardado: %s"
			% [rep.semilla, rep.score, rep.eventos(), ok]
		)
	)
	SaveManager.clear()
	main.free()
	quit(0)
