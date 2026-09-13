extends SceneTree
## T-070 — Guardado del récord.

const MAIN := "res://scenes/Main.tscn"
const RUTA := "user://save.cfg"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-070 · Guardado ---")
	await _sin_fichero_arranca_a_cero()
	await _guarda_y_recupera_el_record()
	await _fichero_corrupto_no_rompe_nada()
	await _fichero_con_tipos_raros_no_rompe_nada()
	await _la_partida_registra_record_y_cuenta()
	SaveManager.clear()
	quit(h.resumen("T-070"))


func _escribir_basura(contenido: String) -> void:
	SaveManager.clear()
	var f: FileAccess = FileAccess.open(RUTA, FileAccess.WRITE)
	f.store_string(contenido)
	f.close()
	SaveManager.forget_cache()


## Criterio: un fichero ausente no rompe el juego.
func _sin_fichero_arranca_a_cero() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	h.check(
		"sin guardado el récord es 0",
		SaveManager.get_high_score() == 0,
		"récord: %d" % SaveManager.get_high_score()
	)
	h.check(
		"sin guardado las partidas son 0",
		SaveManager.get_games_played() == 0,
		"partidas: %d" % SaveManager.get_games_played()
	)


## Sobrevivir a cerrar y abrir es lo único que hace útil un récord.
func _guarda_y_recupera_el_record() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	h.check("la primera partida es récord", SaveManager.record_game(7), "")
	h.check("no es récord puntuar menos", not SaveManager.record_game(3), "")
	h.check("sí lo es puntuar más", SaveManager.record_game(12), "")

	# Simula cerrar y volver a abrir el juego.
	SaveManager.forget_cache()
	h.check(
		"el récord sobrevive a reabrir el juego",
		SaveManager.get_high_score() == 12,
		"récord tras releer del disco: %d" % SaveManager.get_high_score()
	)
	h.check(
		"y la cuenta de partidas también",
		SaveManager.get_games_played() == 3,
		"partidas: %d" % SaveManager.get_games_played()
	)


## Criterio: un fichero corrupto no rompe el juego.
func _fichero_corrupto_no_rompe_nada() -> void:
	_escribir_basura("esto no es un ConfigFile {{{ [[[ ")
	h.check(
		"un guardado corrupto devuelve valores por defecto",
		SaveManager.get_high_score() == 0 and SaveManager.get_games_played() == 0,
		"récord %d, partidas %d" % [SaveManager.get_high_score(), SaveManager.get_games_played()]
	)
	h.check("y se puede volver a guardar encima", SaveManager.record_game(5), "")
	SaveManager.forget_cache()
	h.check(
		"y lo nuevo persiste",
		SaveManager.get_high_score() == 5,
		"récord: %d" % SaveManager.get_high_score()
	)


## El fichero es texto plano y editable a mano: puede traer cualquier cosa.
func _fichero_con_tipos_raros_no_rompe_nada() -> void:
	var basura: String = "[progreso]"
	basura += "\n" + "high_score=" + '"muchos"'
	basura += "\n" + "games_played=-40" + "\n"
	_escribir_basura(basura)
	h.check(
		"un récord con texto en vez de número devuelve 0",
		SaveManager.get_high_score() == 0,
		"récord: %d" % SaveManager.get_high_score()
	)
	h.check(
		"una cuenta negativa se corrige a 0",
		SaveManager.get_games_played() == 0,
		"partidas: %d" % SaveManager.get_games_played()
	)


## Y todo esto conectado a una partida real.
func _la_partida_registra_record_y_cuenta() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 5
	h.jugar(main)
	main._on_scored()
	main._on_scored()
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	h.check(
		"al morir se guarda el récord",
		main.get_high_score() == 2,
		"récord en Main: %d, en disco: %d" % [main.get_high_score(), SaveManager.get_high_score()]
	)
	h.check("y se marca como récord nuevo", main.is_new_high_score(), "")
	h.check(
		"y cuenta la partida",
		SaveManager.get_games_played() == 1,
		"partidas: %d" % SaveManager.get_games_played()
	)

	main.restart()
	h.check("al reiniciar deja de marcar récord nuevo", not main.is_new_high_score(), "")
	h.check(
		"pero el récord se conserva",
		main.get_high_score() == 2,
		"récord: %d" % main.get_high_score()
	)
	main.free()
