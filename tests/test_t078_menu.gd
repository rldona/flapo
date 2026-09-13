extends SceneTree
## T-078 — Pantalla de inicio y modos de dificultad.
##
## Lo que se prueba: que el juego arranca en MENU, que la máquina de estados
## nueva solo permite lo que debe, que cada modo produce los números
## esperados a puntuación 0, que la elección se recuerda entre sesiones y
## —lo más importante— que **ningún modo rompe el invariante de ADR-0018**
## de no bajar de 3 aleteos entre tuberías.

const MAIN := "res://scenes/Main.tscn"
const MODOS: Array = [
	GameConfig.Difficulty.FACIL, GameConfig.Difficulty.NORMAL, GameConfig.Difficulty.DIFICIL
]

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-078 · Menú y dificultad ---")
	_los_modos_escalan_la_curva()
	_ningun_modo_baja_de_tres_aleteos()
	_el_modo_se_recuerda_entre_sesiones()
	await _el_juego_arranca_en_el_menu()
	await _la_maquina_de_estados_nueva()
	await _elegir_modo_cambia_el_mundo()
	SaveManager.clear()
	quit(h.resumen("T-078"))


## Criterio: cada modo da los valores esperados a puntuación 0.
func _los_modos_escalan_la_curva() -> void:
	var base_hueco: float = GameConfig.PIPE_GAP
	var base_vel: float = GameConfig.SCROLL_SPEED
	h.check(
		"normal es el juego de siempre, sin tocar nada",
		(
			is_equal_approx(GameConfig.pipe_gap_for(0, GameConfig.Difficulty.NORMAL), base_hueco)
			and is_equal_approx(
				GameConfig.scroll_speed_for(0, GameConfig.Difficulty.NORMAL), base_vel
			)
		),
		(
			"hueco %.1f, velocidad %.1f"
			% [
				GameConfig.pipe_gap_for(0, GameConfig.Difficulty.NORMAL),
				GameConfig.scroll_speed_for(0, GameConfig.Difficulty.NORMAL)
			]
		)
	)
	h.check(
		"fácil tiene el hueco más ancho y va más lento",
		(
			GameConfig.pipe_gap_for(0, GameConfig.Difficulty.FACIL) > base_hueco
			and GameConfig.scroll_speed_for(0, GameConfig.Difficulty.FACIL) < base_vel
		),
		(
			"hueco %.1f, velocidad %.1f"
			% [
				GameConfig.pipe_gap_for(0, GameConfig.Difficulty.FACIL),
				GameConfig.scroll_speed_for(0, GameConfig.Difficulty.FACIL)
			]
		)
	)
	h.check(
		"difícil lo contrario",
		(
			GameConfig.pipe_gap_for(0, GameConfig.Difficulty.DIFICIL) < base_hueco
			and GameConfig.scroll_speed_for(0, GameConfig.Difficulty.DIFICIL) > base_vel
		),
		(
			"hueco %.1f, velocidad %.1f"
			% [
				GameConfig.pipe_gap_for(0, GameConfig.Difficulty.DIFICIL),
				GameConfig.scroll_speed_for(0, GameConfig.Difficulty.DIFICIL)
			]
		)
	)
	# Sin argumento tiene que seguir siendo NORMAL: hay código y tests
	# anteriores a T-078 que llaman a estas funciones con un solo parámetro.
	h.check(
		"sin decir modo, se juega en normal",
		is_equal_approx(
			GameConfig.pipe_gap_for(7), GameConfig.pipe_gap_for(7, GameConfig.Difficulty.NORMAL)
		),
		""
	)
	# Y difícil tiene que ser más duro que fácil TAMBIÉN en el tope de la
	# curva: si solo cambiara el arranque, elegir difícil no serviría de nada
	# para quien pasa de 30 puntos.
	var cap: int = GameConfig.DIFFICULTY_CAP
	h.check(
		"la diferencia entre modos se mantiene en el tope de la curva",
		(
			GameConfig.pipe_gap_for(cap, GameConfig.Difficulty.DIFICIL)
			< GameConfig.pipe_gap_for(cap, GameConfig.Difficulty.FACIL)
		),
		(
			"difícil %.1f vs fácil %.1f a %d puntos"
			% [
				GameConfig.pipe_gap_for(cap, GameConfig.Difficulty.DIFICIL),
				GameConfig.pipe_gap_for(cap, GameConfig.Difficulty.FACIL),
				cap
			]
		)
	)


## La regla que ningún modo puede saltarse: por debajo de 3 aleteos entre
## tuberías el juego pasa de difícil a injusto (ADR-0018).
func _ningun_modo_baja_de_tres_aleteos() -> void:
	for modo in MODOS:
		var aleteos: float = GameConfig.flaps_between_pipes(GameConfig.DIFFICULTY_CAP, modo)
		h.check(
			"el modo %s no baja de 3 aleteos entre tuberías" % GameConfig.difficulty_name(modo),
			aleteos > 3.0,
			"%.2f aleteos" % aleteos
		)
	# Y son exactamente los mismos en los tres, porque la separación escala
	# con la velocidad. Es lo que hace que la dificultad cambie el margen y
	# no el ritmo.
	var normal: float = GameConfig.flaps_between_pipes(0, GameConfig.Difficulty.NORMAL)
	for modo in MODOS:
		h.check(
			"y el ritmo es el mismo en %s" % GameConfig.difficulty_name(modo),
			is_equal_approx(GameConfig.flaps_between_pipes(0, modo), normal),
			"%.3f vs %.3f" % [GameConfig.flaps_between_pipes(0, modo), normal]
		)


## Criterio: la dificultad elegida se persiste.
func _el_modo_se_recuerda_entre_sesiones() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	h.check(
		"sin guardado se juega en normal, no en el modo 0",
		SaveManager.get_difficulty() == GameConfig.Difficulty.NORMAL,
		"modo: %d" % SaveManager.get_difficulty()
	)
	SaveManager.set_difficulty(GameConfig.Difficulty.DIFICIL)
	SaveManager.forget_cache()
	h.check(
		"el modo elegido sobrevive a reabrir el juego",
		SaveManager.get_difficulty() == GameConfig.Difficulty.DIFICIL,
		"modo: %d" % SaveManager.get_difficulty()
	)
	# Un guardado a mano con un número imposible no puede dejar al jugador en
	# un modo que no existe.
	var cfg := ConfigFile.new()
	cfg.set_value("progreso", "difficulty", 99)
	cfg.save("user://save.cfg")
	SaveManager.forget_cache()
	h.check(
		"un modo imposible cae en normal",
		SaveManager.get_difficulty() == GameConfig.Difficulty.NORMAL,
		"modo: %d" % SaveManager.get_difficulty()
	)


## Criterio: el estado inicial del juego es MENU.
func _el_juego_arranca_en_el_menu() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.check(
		"el juego arranca en MENU",
		main.get_state() == GameState.State.MENU,
		"estado: %d" % main.get_state()
	)
	h.check("y el panel del menú se ve", main.menu_panel.visible, "")
	# Y en el menú no se juega: un aleteo no puede arrancar la partida a
	# espaldas del botón.
	h.pulsa(KEY_SPACE)
	await h.ticks(5)
	h.pulsa(KEY_SPACE, false)
	h.check(
		"y aletear en el menú no empieza la partida",
		main.get_state() == GameState.State.MENU,
		"estado: %d" % main.get_state()
	)
	# El botón sí.
	main.menu_panel.play_pressed.emit()
	await h.ticks(2)
	h.check(
		"pero el botón Jugar sí lleva a READY",
		main.get_state() == GameState.State.READY,
		"estado: %d" % main.get_state()
	)
	h.check("y el panel se esconde", not main.menu_panel.visible, "")
	main.free()


## Criterio: MENU → READY → PLAYING → GAME_OVER, y vuelta a MENU.
func _la_maquina_de_estados_nueva() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})

	# Del menú no se salta directo a jugar.
	main.change_state(GameState.State.PLAYING)
	h.check(
		"del menú no se salta directo a PLAYING",
		main.get_state() == GameState.State.MENU,
		"estado: %d" % main.get_state()
	)
	h.jugar(main)
	h.check("MENU → READY → PLAYING funciona", main.get_state() == GameState.State.PLAYING, "")

	# Y desde una partida en marcha tampoco se vuelve al menú de golpe.
	main.to_menu()
	h.check(
		"jugando no se vuelve al menú",
		main.get_state() == GameState.State.PLAYING,
		"estado: %d" % main.get_state()
	)

	main.change_state(GameState.State.GAME_OVER)
	main.to_menu()
	await h.ticks(2)
	h.check(
		"desde el Game Over sí se vuelve al menú",
		main.get_state() == GameState.State.MENU,
		"estado: %d" % main.get_state()
	)
	h.check("y el panel vuelve a verse", main.menu_panel.visible, "")
	main.free()


## Y el modo elegido llega de verdad al mundo, no se queda en el guardado.
func _elegir_modo_cambia_el_mundo() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})

	main.options_panel.difficulty_selected.emit(GameConfig.Difficulty.DIFICIL)
	h.check(
		"el spawner recibe el hueco del modo difícil",
		is_equal_approx(
			main.pipe_spawner.gap, GameConfig.pipe_gap_for(0, GameConfig.Difficulty.DIFICIL)
		),
		"hueco en el spawner: %.1f" % main.pipe_spawner.gap
	)
	h.check(
		"y el suelo la velocidad",
		is_equal_approx(
			main.ground.scroll_speed, GameConfig.scroll_speed_for(0, GameConfig.Difficulty.DIFICIL)
		),
		"velocidad del suelo: %.1f" % main.ground.scroll_speed
	)

	# El menú refleja lo elegido, y el ciclo del botón recorre los tres modos.
	h.check(
		"el menú enseña el modo activo",
		main.options_panel.difficulty() == GameConfig.Difficulty.DIFICIL,
		"modo en el menú: %d" % main.options_panel.difficulty()
	)
	var vistos: Dictionary = {}
	for toque in 3:
		main.options_panel._on_difficulty_pressed()
		await h.ticks(1)
		vistos[int(main.session().difficulty())] = true
	h.check(
		"el botón recorre los tres modos", vistos.size() == 3, "%d modos distintos" % vistos.size()
	)

	# Y no se puede cambiar en mitad de una partida: movería las tuberías que
	# ya están en pantalla.
	main.options_panel.difficulty_selected.emit(GameConfig.Difficulty.NORMAL)
	h.jugar(main)
	main.options_panel.difficulty_selected.emit(GameConfig.Difficulty.DIFICIL)
	h.check(
		"jugando, el modo no cambia",
		main.session().difficulty() == GameConfig.Difficulty.NORMAL,
		"modo: %d" % main.session().difficulty()
	)
	main.free()
