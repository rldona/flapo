extends SceneTree
## T-200 — Descubrir el planeo en un segundo.
##
## El criterio que más importa es el primero: **nunca bloquea la entrada**.
## Un tutorial que se come un toque en un juego de un botón es peor que no
## tener tutorial, así que hay un caso dedicado a comprobar que con el cartel
## puesto se juega exactamente igual.

const MAIN := "res://scenes/Main.tscn"
const RUTA := "user://save.cfg"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-200 · Descubrir el planeo ---")
	_la_regla_es_pura_y_se_apaga_para_siempre()
	_un_guardado_ausente_o_corrupto_cuenta_como_primera_vez()
	await _el_pictograma_sale_en_ready_y_no_bloquea_nada()
	await _el_aviso_sale_tras_tres_huecos_sin_planear()
	await _planear_una_vez_lo_apaga_y_lo_guarda()
	SaveManager.clear()
	quit(h.resumen("T-200"))


func _escribir_basura(contenido: String) -> void:
	SaveManager.clear()
	var f: FileAccess = FileAccess.open(RUTA, FileAccess.WRITE)
	f.store_string(contenido)
	f.close()
	SaveManager.forget_cache()


## Criterio: como mucho en las GLIDE_HINT_MAX_GAMES primeras partidas, y
## desaparece para siempre tras el primer planeo.
func _la_regla_es_pura_y_se_apaga_para_siempre() -> void:
	var tope: int = GameConfig.GLIDE_HINT_MAX_GAMES
	h.check("en la primera partida se enseña", GameConfig.show_glide_pictogram(false, 0), "")
	h.check(
		"en la última partida del margen todavía",
		GameConfig.show_glide_pictogram(false, tope - 1),
		""
	)
	h.check(
		"pasado el margen ya no", not GameConfig.show_glide_pictogram(false, tope), "tope %d" % tope
	)
	# Y lo que lo apaga de verdad: haber planeado. Da igual la partida.
	var sale_alguna: bool = false
	for partidas in 50:
		if GameConfig.show_glide_pictogram(true, partidas):
			sale_alguna = true
	h.check("tras planear una vez no sale en ninguna partida", not sale_alguna, "")

	# El aviso de dentro de partida pide además huecos sin planear.
	var huecos: int = GameConfig.GLIDE_HINT_AFTER_GAPS
	h.check(
		"el aviso no sale antes de %d huecos" % huecos,
		not GameConfig.show_glide_hint(false, 0, huecos - 1),
		""
	)
	h.check("y sí a partir de ahí", GameConfig.show_glide_hint(false, 0, huecos), "")
	h.check("pero nunca si ya se ha planeado", not GameConfig.show_glide_hint(true, 0, 99), "")


## Criterio: un guardado ausente o corrupto cuenta como "primera vez".
func _un_guardado_ausente_o_corrupto_cuenta_como_primera_vez() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	h.check("sin guardado, no ha planeado nunca", not SaveManager.get_has_glided(), "")
	h.check(
		"y por tanto se enseña",
		GameConfig.show_glide_pictogram(
			SaveManager.get_has_glided(), SaveManager.get_games_played()
		),
		""
	)
	_escribir_basura("[progreso\nhas_glided=??? }}}")
	h.check("con guardado corrupto, tampoco", not SaveManager.get_has_glided(), "")
	h.check(
		"y se sigue enseñando: ante la duda, se enseña",
		GameConfig.show_glide_pictogram(
			SaveManager.get_has_glided(), SaveManager.get_games_played()
		),
		""
	)
	# Y guardarlo funciona y sobrevive a reabrir.
	SaveManager.clear()
	SaveManager.forget_cache()
	SaveManager.set_has_glided()
	SaveManager.forget_cache()
	h.check("una vez marcado, sobrevive a reabrir el juego", SaveManager.get_has_glided(), "")


## Criterio: nunca bloquea la entrada. Aletear en READY sigue empezando.
func _el_pictograma_sale_en_ready_y_no_bloquea_nada() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.change_state(GameState.State.READY)
	await h.ticks(2)
	h.check("en READY sale el pictograma", main.glide_hint.visible, "")
	h.check(
		"y dice qué hacer",
		main.glide_hint.texto().to_lower().contains("mantén"),
		"'%s'" % main.glide_hint.texto()
	)

	# EL criterio: con el cartel puesto, aletear arranca la partida igual.
	h.pulsa(KEY_SPACE)
	await h.ticks(2)
	h.pulsa(KEY_SPACE, false)
	h.check(
		"aletear con el cartel puesto empieza la partida igual",
		main.get_state() == GameState.State.PLAYING,
		"estado: %d" % main.get_state()
	)
	# Y no ha pausado el árbol: un tutorial que congela el juego estorba.
	h.check("y no ha pausado el juego", not main.get_tree().paused, "")
	h.check(
		"al empezar a jugar el pictograma se retira",
		not main.glide_hint.visible or main.glide_hint.texto() != main.glide_hint.texto_pictograma,
		"'%s'" % main.glide_hint.texto()
	)
	main.free()


## Criterio: en la primera partida, si a los 3 huecos no se ha planeado.
func _el_aviso_sale_tras_tres_huecos_sin_planear() -> void:
	var main: Node = await _partida()
	h.check(
		"al empezar no hay aviso", not main.glide_hint.visible, "'%s'" % main.glide_hint.texto()
	)
	for hueco in GameConfig.GLIDE_HINT_AFTER_GAPS - 1:
		main._on_scored()
		await h.ticks(1)
	h.check(
		"a falta de un hueco, todavía no",
		not main.glide_hint.visible,
		"'%s'" % main.glide_hint.texto()
	)
	main._on_scored()
	await h.ticks(1)
	h.check("al tercer hueco sin planear, sale", main.glide_hint.visible, "")
	# Y no pausa ni bloquea: la partida sigue corriendo.
	h.check(
		"y la partida sigue en marcha",
		main.get_state() == GameState.State.PLAYING and not main.get_tree().paused,
		"estado: %d" % main.get_state()
	)
	main.free()


## Criterio: se apaga solo en cuanto el jugador planea una vez.
func _planear_una_vez_lo_apaga_y_lo_guarda() -> void:
	var main: Node = await _partida()
	for hueco in GameConfig.GLIDE_HINT_AFTER_GAPS:
		main._on_scored()
	await h.ticks(1)
	h.check("premisa: el aviso está puesto", main.glide_hint.visible, "")

	# Planear de verdad: mantener pulsado más de glide_hold_time.
	h.pulsa(KEY_SPACE)
	var ticks: int = int(main.bird.glide_hold_time * 60.0) + 6
	for i in ticks:
		await physics_frame
	h.pulsa(KEY_SPACE, false)
	h.check("premisa: Flapo ha planeado", main.bird.is_gliding() or main.get_has_glided(), "")
	await h.ticks(2)

	h.check(
		"el aviso desaparece en cuanto planea",
		not main.glide_hint.visible,
		"'%s'" % main.glide_hint.texto()
	)
	h.check("y queda guardado", SaveManager.get_has_glided(), "")

	# Y en una partida nueva no vuelve, ni siquiera en READY.
	main.change_state(GameState.State.GAME_OVER)
	main.restart()
	await h.ticks(2)
	h.check(
		"en la partida siguiente no vuelve a salir",
		not main.glide_hint.visible,
		"'%s'" % main.glide_hint.texto()
	)
	main.free()


func _partida() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.fruit_spawner.chance = 0.0
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	await h.ticks(1)
	return main
