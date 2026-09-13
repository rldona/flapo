extends SceneTree
## T-087 — Menú de opciones.
##
## Dos cosas que comprobar. Una es que **el menú principal ha adelgazado de
## verdad**: si los ajustes se hubieran duplicado en vez de mudarse, el
## ticket no habría servido para nada y todo lo demás pasaría igual.
##
## La otra es que cada ajuste **llega a donde tiene que llegar**: tocar el
## botón cambia el juego y sobrevive a cerrar y abrir. Un panel bonito que
## no persiste es peor que no tener panel.

const MAIN := "res://scenes/Main.tscn"
const CODIGO := "00abc"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-087 · Menú de opciones ---")
	await _el_menu_ha_adelgazado()
	await _se_abre_y_se_cierra_sin_ser_un_estado()
	await _ensena_el_estado_real_al_abrirse()
	await _el_nombre_y_el_modo_siguen_funcionando()
	await _el_sonido_se_toca_desde_opciones()
	await _esconder_el_fantasma_lo_esconde_de_verdad()
	await _salir_del_menu_cierra_el_panel()
	# Los botones de opciones suenan. Si se sale del test con el clic aún
	# sonando, el reproductor se queda vivo y Godot avisa de una fuga que no
	# es del juego, sino de haber apagado la luz mientras hablaba alguien.
	await h.ticks(40)
	GhostRecord.borrar()
	SaveManager.clear()
	Settings.clear()
	quit(h.resumen("T-087"))


## Los ajustes se han MUDADO, no copiado. Si siguieran en los dos sitios, el
## menú no habría adelgazado y habría dos sitios que mantener sincronizados.
func _el_menu_ha_adelgazado() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	var en_el_menu: Array = []
	for hijo in main.menu_panel.get_node("Root/Box").get_children():
		en_el_menu.append(str(hijo.name))
	for ajuste in ["Name", "Difficulty", "Sound", "Ghost"]:
		h.check(
			"'%s' ya no está en el menú principal" % ajuste,
			not en_el_menu.has(ajuste),
			"el menú tiene: %s" % str(en_el_menu)
		)
	h.check("y ahora hay un botón de opciones", en_el_menu.has("Options"), "%s" % str(en_el_menu))
	# Lo que aprieta la columna de 288 px son los elementos que se tocan, no
	# las etiquetas: cada uno se lleva sus 48 dp de alto mínimo (T-030).
	var tocables: Array = []
	for hijo in main.menu_panel.get_node("Root/Box").get_children():
		if hijo is Button or hijo is LineEdit:
			tocables.append(str(hijo.name))
	h.check(
		"el menú baja de siete elementos tocables a seis",
		tocables.size() == 6,
		"%d: %s" % [tocables.size(), str(tocables)]
	)
	main.free()


## Criterio: es un panel encima del menú, no un quinto estado.
func _se_abre_y_se_cierra_sin_ser_un_estado() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.check("las opciones arrancan cerradas", not main.options_panel.is_open(), "")
	main.menu_panel.options_pressed.emit()
	h.check("el botón de opciones las abre", main.options_panel.is_open(), "")
	h.check(
		"y el juego sigue en MENU: no es un estado nuevo",
		main.get_state() == GameState.State.MENU,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	h.check("el menú sigue detrás", main.menu_panel.visible, "")
	main.options_panel.back_pressed.emit()
	h.check("'Volver' las cierra", not main.options_panel.is_open(), "")
	main.free()


## Al abrirse tiene que decir cómo está la cosa AHORA, no lo que le contaron
## una vez: el silencio se puede cambiar desde la pausa y desde el Game Over.
func _ensena_el_estado_real_al_abrirse() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	Settings.clear()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	# Se silencia por fuera de las opciones, como haría el botón de la pausa.
	main.audio.toggle_muted()
	Settings.set_ghost_hidden(true)
	main.menu_panel.options_pressed.emit()
	var textos: PackedStringArray = main.options_panel.lines_text()
	h.check(
		"al abrirse enseña el silencio de verdad",
		textos[1] == "Sonido: apagado",
		"'%s'" % textos[1]
	)
	h.check("y el estado real del fantasma", textos[2] == "Fantasma: oculto", "'%s'" % textos[2])
	h.check(
		"los botones dicen cómo está la cosa, no qué hacen",
		textos[0].begins_with("Modo: "),
		"'%s'" % textos[0]
	)
	main.audio.toggle_muted()
	Settings.set_ghost_hidden(false)
	main.free()


## Nombre y modo cambiaron de sitio, no de comportamiento (T-078, T-079).
func _el_nombre_y_el_modo_siguen_funcionando() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.options_panel._on_name_changed("Raúl")
	main.options_panel._on_difficulty_pressed()
	var modo: GameConfig.Difficulty = main.options_panel.difficulty()
	h.check(
		"el nombre escrito en opciones llega a la sesión",
		main.session().player_name() == "Raúl",
		"'%s'" % main.session().player_name()
	)
	h.check(
		"y el modo elegido también",
		main.session().difficulty() == modo,
		"panel %d, sesión %d" % [modo, main.session().difficulty()]
	)
	main.free()

	SaveManager.forget_cache()
	var otro: Node = await h.montar(MAIN, {"log_transitions": false})
	otro.menu_panel.options_pressed.emit()
	h.check(
		"y sobreviven a reabrir el juego",
		otro.options_panel.player_name() == "Raúl" and otro.options_panel.difficulty() == modo,
		"'%s', modo %d" % [otro.options_panel.player_name(), otro.options_panel.difficulty()]
	)
	otro.free()


## El silencio se puede tocar desde tres sitios; los tres tienen que acabar
## en el mismo bus de audio y en el mismo fichero.
func _el_sonido_se_toca_desde_opciones() -> void:
	Settings.clear()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.menu_panel.options_pressed.emit()
	h.check("premisa: se arranca con sonido", not main.audio.is_muted(), "")
	main.options_panel.sound_toggled.emit()
	h.check("tocar el sonido en opciones silencia el juego", main.audio.is_muted(), "")
	h.check(
		"y el botón lo refleja",
		main.options_panel.lines_text()[1] == "Sonido: apagado",
		"'%s'" % main.options_panel.lines_text()[1]
	)
	main.free()
	Settings.forget_cache()
	h.check("y queda guardado al cerrar el juego", Settings.is_muted(), "")
	Settings.clear()


## Lo que pidió Raúl: poder esconder el fantasma. Y esconderlo de verdad, no
## solo dejar de dibujarlo: si siguiera reproduciendo no se vería, pero
## seguiría gastando trabajo por nada.
func _esconder_el_fantasma_lo_esconde_de_verdad() -> void:
	Settings.clear()
	SaveManager.clear()
	SaveManager.forget_cache()
	await _grabar_un_fantasma()

	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.check("premisa: hay un fantasma guardado", main.ghost.registro() != null, "")
	main.start_code(CODIGO)
	main.change_state(GameState.State.PLAYING)
	h.check(
		"premisa: con el ajuste por defecto, el fantasma sale", main.ghost.esta_reproduciendo(), ""
	)
	main.free()

	# Se esconde por la ruta del jugador: el botón de opciones.
	var menu: Node = await h.montar(MAIN, {"log_transitions": false})
	menu.menu_panel.options_pressed.emit()
	menu.options_panel.ghost_toggled.emit()
	h.check("el botón esconde el fantasma", Settings.is_ghost_hidden(), "")
	h.check(
		"y lo dice",
		menu.options_panel.lines_text()[2] == "Fantasma: oculto",
		"'%s'" % menu.options_panel.lines_text()[2]
	)
	menu.start_code(CODIGO)
	menu.change_state(GameState.State.PLAYING)
	await h.ticks(20)
	h.check("escondido, el fantasma no sale", not menu.ghost.esta_reproduciendo(), "")
	h.check("ni se ve", not menu.ghost.visible, "")
	menu.free()

	# Y sobrevive a cerrar el juego.
	Settings.forget_cache()
	var otro: Node = await h.montar(MAIN, {"log_transitions": false})
	otro.start_code(CODIGO)
	otro.change_state(GameState.State.PLAYING)
	h.check("sigue escondido tras reabrir el juego", not otro.ghost.esta_reproduciendo(), "")
	otro.free()

	# Volver a enseñarlo lo devuelve.
	var vuelta: Node = await h.montar(MAIN, {"log_transitions": false})
	vuelta.menu_panel.options_pressed.emit()
	vuelta.options_panel.ghost_toggled.emit()
	h.check("volver a tocarlo lo enseña otra vez", not Settings.is_ghost_hidden(), "")
	vuelta.start_code(CODIGO)
	vuelta.change_state(GameState.State.PLAYING)
	h.check("y el fantasma vuelve a salir", vuelta.ghost.esta_reproduciendo(), "")
	vuelta.free()
	Settings.clear()


## Empezar a jugar con las opciones abiertas las dejaría delante del juego.
func _salir_del_menu_cierra_el_panel() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.menu_panel.options_pressed.emit()
	h.check("premisa: las opciones están abiertas", main.options_panel.is_open(), "")
	h.jugar(main)
	h.check("empezar a jugar cierra las opciones", not main.options_panel.is_open(), "")
	main.free()


## Deja un fantasma en el disco para la semilla de `CODIGO`.
func _grabar_un_fantasma() -> void:
	GhostRecord.borrar()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.start_code(CODIGO)
	main.change_state(GameState.State.PLAYING)
	main.bird.collision_mask = 0
	for tick in 300:
		if tick % 22 == 0:
			h.pulsa(KEY_SPACE)
		elif tick % 22 == 1:
			h.pulsa(KEY_SPACE, false)
		await physics_frame
	h.check(
		"premisa: la partida grabada ha puntuado", main.get_score() >= 1, "%d" % main.get_score()
	)
	main._on_bird_died(Bird.DeathCause.SUELO, false)
	main.free()
