extends SceneTree
## Reproduce un replay en headless y dice si cuadra (T-261).
##
##     /Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 \
##       --path . -s tests/replay.gd -- user://last.replay
##
## Sin argumento reproduce `user://last.replay`, que es la última partida que
## se jugó. Sale con 0 si la puntuación coincide con la grabada y con 1 si no:
## así se puede meter en CI tal cual.
##
## `tests/run.sh` no lo ejecuta —no empieza por `test_`— porque necesita un
## fichero que le digas. El que sí corre siempre es
## `tests/test_t261_replay.gd`, con el replay de referencia.

const MAIN := "res://scenes/Main.tscn"


func _init() -> void:
	var ruta: String = Replay.RUTA_ULTIMA
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		ruta = args[0]

	var rep: Replay = Replay.cargar(ruta)
	if rep == null:
		print("No se ha podido leer el replay: ", ruta)
		quit(1)
		return

	print("=== Replay · T-261 ===")
	print("Fichero:   ", ruta)
	print("Semilla:   ", rep.semilla)
	print("Modo:      ", GameConfig.difficulty_name(rep.modo))
	print("Confianza: ", rep.confianza)
	print("Flancos:   ", rep.eventos())
	print("Esperado:  ", rep.score, " puntos\n")

	var main: Node = load(MAIN).instantiate()
	main.log_transitions = false
	root.add_child(main)
	await process_frame

	var r: Dictionary = await ReplayPlayer.new().reproducir(self, main, rep)
	print("Obtenido:  ", r["score"], " puntos en ", r["frames"], " frames")
	print("")
	print("CUADRA" if r["cuadra"] else "NO CUADRA: la partida ya no es la misma")
	SaveManager.clear()
	main.free()
	quit(0 if r["cuadra"] else 1)
