extends SceneTree
## T-079 — Nombre de jugador.
##
## Lo que se comprueba: que el saneado quita de verdad lo que rompería el
## texto de compartir, que el nombre se guarda y vuelve, y que **jugar sin
## poner nombre nunca se bloquea** — que es la parte que un campo de texto
## obligatorio estropearía.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-079 · Nombre de jugador ---")
	_el_saneado_quita_lo_que_rompe()
	_sin_nombre_no_se_bloquea_nada()
	_se_guarda_y_vuelve()
	await _el_menu_y_el_compartir_lo_usan()
	SaveManager.clear()
	quit(h.resumen("T-079"))


## Criterio: saneado de lo que rompe el texto de compartir.
func _el_saneado_quita_lo_que_rompe() -> void:
	h.check(
		"un salto de línea no sobrevive",
		not GameConfig.sanitize_player_name("Ra\núl").contains("\n"),
		"'%s'" % GameConfig.sanitize_player_name("Ra\núl")
	)
	h.check(
		"ni un tabulador",
		not GameConfig.sanitize_player_name("a\tb").contains("\t"),
		"'%s'" % GameConfig.sanitize_player_name("a\tb")
	)
	h.check(
		"los espacios de los extremos se recortan",
		GameConfig.sanitize_player_name("  Raúl  ") == "Raúl",
		"'%s'" % GameConfig.sanitize_player_name("  Raúl  ")
	)
	h.check(
		"y los de dentro se colapsan",
		GameConfig.sanitize_player_name("a     b") == "a b",
		"'%s'" % GameConfig.sanitize_player_name("a     b")
	)
	# Criterio: el límite vive en GameConfig y se respeta.
	var largo: String = "A".repeat(GameConfig.PLAYER_NAME_MAX_LEN + 20)
	h.check(
		"un nombre larguísimo se corta al límite de GameConfig",
		GameConfig.sanitize_player_name(largo).length() == GameConfig.PLAYER_NAME_MAX_LEN,
		"%d caracteres" % GameConfig.sanitize_player_name(largo).length()
	)
	# Los acentos y la ñ NO son caracteres raros: cortarlos sería un bug.
	h.check(
		"los acentos y la ñ se respetan",
		GameConfig.sanitize_player_name("Muñoz Ávila") == "Muñoz Ávila",
		"'%s'" % GameConfig.sanitize_player_name("Muñoz Ávila")
	)


## Criterio: vacío usa un nombre por defecto sin bloquear la partida.
func _sin_nombre_no_se_bloquea_nada() -> void:
	h.check("el saneado de vacío es vacío", GameConfig.sanitize_player_name("") == "", "")
	h.check(
		"pero lo que se enseña nunca es vacío",
		GameConfig.display_player_name("") == GameConfig.PLAYER_NAME_DEFAULT,
		"'%s'" % GameConfig.display_player_name("")
	)
	h.check(
		"y un nombre de solo espacios cuenta como vacío",
		GameConfig.display_player_name("     ") == GameConfig.PLAYER_NAME_DEFAULT,
		"'%s'" % GameConfig.display_player_name("     ")
	)


## Criterio: persistido en user://save.cfg.
func _se_guarda_y_vuelve() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	h.check("sin guardado no hay nombre", SaveManager.get_player_name() == "", "")
	SaveManager.set_player_name("  Raúl  ")
	SaveManager.forget_cache()
	h.check(
		"el nombre sobrevive a reabrir el juego, ya saneado",
		SaveManager.get_player_name() == "Raúl",
		"'%s'" % SaveManager.get_player_name()
	)
	# El fichero es texto editable a mano: puede traer un nombre imposible.
	var cfg := ConfigFile.new()
	cfg.set_value("progreso", "player_name", "x".repeat(300))
	cfg.save("user://save.cfg")
	SaveManager.forget_cache()
	h.check(
		"un nombre imposible en el fichero se sanea al leerlo",
		SaveManager.get_player_name().length() == GameConfig.PLAYER_NAME_MAX_LEN,
		"%d caracteres" % SaveManager.get_player_name().length()
	)
	cfg.set_value("progreso", "player_name", 42)
	cfg.save("user://save.cfg")
	SaveManager.forget_cache()
	h.check("y un número tampoco rompe nada", SaveManager.get_player_name() == "", "")


## Y todo esto conectado: se escribe en el menú, se firma al compartir.
func _el_menu_y_el_compartir_lo_usan() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.check(
		"sin nombre puesto, se enseña el de siempre",
		(
			GameConfig.display_player_name(main.session().player_name())
			== GameConfig.PLAYER_NAME_DEFAULT
		),
		"'%s'" % GameConfig.display_player_name(main.session().player_name())
	)

	# Escribir en el campo del menú llega hasta el guardado.
	main.options_panel._name.text = "Raúl\n"
	main.options_panel._on_name_changed("Raúl\n")
	await h.ticks(1)
	h.check(
		"lo escrito llega saneado a Main",
		main.session().player_name() == "Raúl",
		"'%s'" % main.session().player_name()
	)
	h.check(
		"y al guardado",
		SaveManager.get_player_name() == "Raúl",
		"'%s'" % SaveManager.get_player_name()
	)
	h.check(
		"y el campo del menú enseña lo saneado, no lo tecleado",
		main.options_panel.player_name() == "Raúl",
		"'%s'" % main.options_panel.player_name()
	)

	# Y sin nombre se puede jugar igual: es lo que no puede romperse.
	main.session().set_player_name("")
	h.jugar(main)
	await h.ticks(2)
	h.check(
		"sin nombre la partida arranca igual",
		main.get_state() == GameState.State.PLAYING,
		"estado: %d" % main.get_state()
	)

	# El texto de compartir se firma con el nombre a enseñar, nunca vacío.
	main.session().set_player_name("Raúl")
	main.change_state(GameState.State.GAME_OVER)
	await h.ticks(2)
	var compartido: Array = []
	main.game_over_panel.share_pressed.connect(func(t: String) -> void: compartido.append(t))
	main.game_over_panel._on_share_pressed()
	h.check("el compartir emite un texto", compartido.size() == 1, "%d textos" % compartido.size())
	if compartido.size() == 1:
		h.check(
			"y va firmado con el nombre",
			(compartido[0] as String).begins_with("Raúl"),
			"'%s'" % compartido[0]
		)

	# Y sin nombre se comparte en primera persona: firmar con el nombre por
	# defecto daría "Flapo ha cruzado 3 tuberías con Flapo".
	main.session().set_player_name("")
	main.game_over_panel.set_player_name("")
	compartido.clear()
	main.game_over_panel._on_share_pressed()
	h.check(
		"sin nombre se comparte sin firmar",
		compartido.size() == 1 and (compartido[0] as String).begins_with("He cruzado"),
		"'%s'" % (compartido[0] if compartido.size() == 1 else "")
	)
	main.free()
