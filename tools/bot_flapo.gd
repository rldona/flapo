extends SceneTree
## Corre el bot muchas veces y saca la métrica de justicia (T-260).
##
##     /Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 \
##       --path . -s tools/bot_flapo.gd -- 200
##
## No es un test: no afirma nada ni falla. `tests/run.sh` no lo ejecuta porque
## 200 partidas tardan minutos, y porque lo que devuelve es una medida, no un
## veredicto. La línea base vive en `docs/perf.md`; lo que importa es cómo se
## mueve al tocar `GameConfig`.
##
## Qué NO mide: si el juego es divertido. Un bot que juega perfecto puede
## sacar una curva perfectamente plana y perfectamente aburrida. Ver ADR-0035.

const MAIN := "res://scenes/Main.tscn"
const PARTIDAS: int = 200

## Semilla de la primera partida. Las demás son consecutivas: así la tanda
## entera se puede repetir tal cual después de tocar una constante, que es lo
## único que hace comparables dos medidas.
const SEMILLA_BASE: int = 1000


func _init() -> void:
	var partidas: int = PARTIDAS
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		partidas = maxi(int(args[0]), 1)

	var main: Node = load(MAIN).instantiate()
	main.log_transitions = false
	root.add_child(main)
	await process_frame

	print("=== Bot de justicia · T-260 ===")
	print("%d partidas, semillas %d..%d\n" % [partidas, SEMILLA_BASE, SEMILLA_BASE + partidas - 1])

	var bot := BotPilot.new()
	var resultados: Array = []
	for i in partidas:
		var r: Dictionary = await bot.jugar(self, main, SEMILLA_BASE + i)
		resultados.append(r)
		if (i + 1) % 25 == 0:
			print("  ... %d/%d" % [i + 1, partidas])

	print("")
	print(BotPilot.informe(resultados))
	SaveManager.clear()
	main.free()
	quit(0)
