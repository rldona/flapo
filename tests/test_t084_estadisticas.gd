extends SceneTree
## T-084 — Pantalla de estadísticas.
##
## El contador nuevo es uno solo (`total_score`); todo lo demás se deriva.
## Lo que se comprueba: que acumula bien entre partidas, que la media sale de
## él sin dividir por cero, que un guardado ausente o corrupto no rompe la
## pantalla, y que el panel enseña de verdad lo que dice el guardado.

const MAIN := "res://scenes/Main.tscn"
const RUTA := "user://save.cfg"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-084 · Estadísticas ---")
	_acumula_entre_partidas()
	_la_media_no_divide_por_cero()
	_guardado_ausente_o_corrupto()
	await _el_panel_ensena_lo_que_dice_el_guardado()
	await _abrir_y_cerrar_desde_el_menu()
	SaveManager.clear()
	quit(h.resumen("T-084"))


func _escribir_basura(contenido: String) -> void:
	SaveManager.clear()
	var f: FileAccess = FileAccess.open(RUTA, FileAccess.WRITE)
	f.store_string(contenido)
	f.close()
	SaveManager.forget_cache()


## Criterio: los contadores se acumulan bien entre partidas.
func _acumula_entre_partidas() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	h.check("sin jugar, 0 tuberías cruzadas", SaveManager.get_total_score() == 0, "")
	SaveManager.record_game(3)
	SaveManager.record_game(5)
	SaveManager.record_game(0)
	h.check(
		"suma las puntuaciones de todas las partidas",
		SaveManager.get_total_score() == 8,
		"total: %d" % SaveManager.get_total_score()
	)
	h.check(
		"y la media sale de ahí",
		is_equal_approx(SaveManager.get_average_score(), 8.0 / 3.0),
		"media: %.3f" % SaveManager.get_average_score()
	)
	# Y sobrevive a cerrar y abrir, como el récord.
	SaveManager.forget_cache()
	h.check(
		"el total sobrevive a reabrir el juego",
		SaveManager.get_total_score() == 8,
		"total: %d" % SaveManager.get_total_score()
	)
	# El total no es el récord: una partida peor también suma.
	h.check(
		"el récord se queda en la mejor, el total suma todas",
		SaveManager.get_high_score() == 5 and SaveManager.get_total_score() == 8,
		"récord %d, total %d" % [SaveManager.get_high_score(), SaveManager.get_total_score()]
	)


## Sin partidas no hay media, y dividir por cero reventaría la pantalla.
func _la_media_no_divide_por_cero() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	h.check(
		"sin partidas la media es 0, no un error",
		is_equal_approx(SaveManager.get_average_score(), 0.0),
		"media: %f" % SaveManager.get_average_score()
	)


## Criterio: guardado ausente o corrupto, igual que T-070 y T-074.
func _guardado_ausente_o_corrupto() -> void:
	_escribir_basura("[progreso\ntotal_score=??? }}}")
	h.check(
		"con guardado corrupto el total es 0",
		SaveManager.get_total_score() == 0,
		"total: %d" % SaveManager.get_total_score()
	)
	var basura: String = "[progreso]"
	basura += "\n" + "games_played=4"
	basura += "\n" + "total_score=" + '"muchas"' + "\n"
	_escribir_basura(basura)
	h.check(
		"un total con texto en vez de número no rompe la media",
		is_equal_approx(SaveManager.get_average_score(), 0.0),
		"media: %f" % SaveManager.get_average_score()
	)


## Y lo que se ve en pantalla es lo que dice el guardado.
func _el_panel_ensena_lo_que_dice_el_guardado() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	# Una marca por encima del umbral de plata, para que la medalla no sea la
	# de "ninguna" y el test compruebe algo.
	SaveManager.record_game(GameConfig.MEDAL_SILVER)
	SaveManager.record_game(2)

	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	var filas: Array = main.stats_rows()
	h.check("hay cinco estadísticas", filas.size() == 5, "%d filas" % filas.size())

	main.menu_panel.stats_pressed.emit()
	await h.ticks(2)
	h.check("el panel se abre", main.stats_panel.visible, "")

	var texto: String = " · ".join(main.stats_panel.lines_text())
	h.check("enseña las partidas jugadas", texto.contains("Partidas: 2"), texto)
	h.check("enseña el récord", texto.contains("Mejor marca: %d" % GameConfig.MEDAL_SILVER), texto)
	h.check(
		"enseña la medalla que toca por ese récord",
		texto.contains(GameConfig.medal_name(GameConfig.medal_for(GameConfig.MEDAL_SILVER))),
		texto
	)
	h.check(
		"y el total de tuberías, que no es el récord",
		texto.contains("Tuberías cruzadas: %d" % (GameConfig.MEDAL_SILVER + 2)),
		texto
	)
	main.free()


## El panel es un panel, no un estado: se abre sobre el menú y se cierra sin
## que el juego cambie de sitio.
func _abrir_y_cerrar_desde_el_menu() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})

	main.menu_panel.stats_pressed.emit()
	await h.ticks(2)
	h.check(
		"abrirlas no cambia el estado del juego",
		main.get_state() == GameState.State.MENU,
		"estado: %d" % main.get_state()
	)
	h.check("y el menú sigue detrás", main.menu_panel.visible, "")

	main.stats_panel.back_pressed.emit()
	await h.ticks(2)
	h.check("Volver las cierra", not main.stats_panel.visible, "")

	# Y si se sale al juego con ellas abiertas, no se quedan encima.
	main.menu_panel.stats_pressed.emit()
	await h.ticks(2)
	h.check("premisa: están abiertas", main.stats_panel.visible, "")
	h.jugar(main)
	await h.ticks(2)
	h.check("empezar a jugar las cierra", not main.stats_panel.visible, "")
	main.free()
