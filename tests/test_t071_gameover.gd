extends SceneTree
## T-071 — Panel de Game Over completo.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-071 · Panel de Game Over ---")
	_umbrales_en_gameconfig()
	await _el_panel_ensena_el_resultado()
	await _marca_el_record_nuevo_solo_cuando_toca()
	await _animacion_de_entrada()
	await _el_boton_de_compartir_solo_en_android()
	SaveManager.clear()
	quit(h.resumen("T-071"))


func _partida() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 8
	return main


func _morir(main: Node) -> void:
	main.change_state(GameState.State.PLAYING)
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			return


func _esperar_panel(main: Node) -> void:
	for i in 180:
		await process_frame
		if main.game_over_panel.is_ready_for_input():
			return


## Criterio: umbrales de medalla en GameConfig.
func _umbrales_en_gameconfig() -> void:
	var casos: Array = [
		[0, GameConfig.Medal.NINGUNA],
		[GameConfig.MEDAL_BRONZE - 1, GameConfig.Medal.NINGUNA],
		[GameConfig.MEDAL_BRONZE, GameConfig.Medal.CROQUETA],
		[GameConfig.MEDAL_SILVER - 1, GameConfig.Medal.CROQUETA],
		[GameConfig.MEDAL_SILVER, GameConfig.Medal.TORTILLA],
		[GameConfig.MEDAL_GOLD - 1, GameConfig.Medal.TORTILLA],
		[GameConfig.MEDAL_GOLD, GameConfig.Medal.JAMON],
		[999, GameConfig.Medal.JAMON],
	]
	var todos: bool = true
	for caso in casos:
		if GameConfig.medal_for(caso[0]) != caso[1]:
			todos = false
	h.check(
		"las medallas salen de los umbrales de GameConfig",
		todos,
		(
			"%d/%d/%d -> croqueta/tortilla/jamón"
			% [GameConfig.MEDAL_BRONZE, GameConfig.MEDAL_SILVER, GameConfig.MEDAL_GOLD]
		)
	)
	h.check(
		"y tienen nombre de comida (GDD)",
		(
			GameConfig.medal_name(GameConfig.Medal.CROQUETA) == "Croqueta"
			and GameConfig.medal_name(GameConfig.Medal.JAMON) == "Jamón"
		),
		""
	)


func _el_panel_ensena_el_resultado() -> void:
	var main: Node = await _partida()
	main.change_state(GameState.State.PLAYING)
	for punto in GameConfig.MEDAL_SILVER:
		main._on_scored()
	await _morir(main)
	await _esperar_panel(main)
	var panel: Node = main.game_over_panel
	h.check(
		"el panel enseña la puntuación",
		panel.get_node("Root/Box/Score").text == str(GameConfig.MEDAL_SILVER),
		"texto: '%s'" % panel.get_node("Root/Box/Score").text
	)
	h.check(
		"el panel enseña el récord",
		panel.get_node("Root/Box/HighScore").text == "Récord %d" % GameConfig.MEDAL_SILVER,
		"texto: '%s'" % panel.get_node("Root/Box/HighScore").text
	)
	h.check(
		"el panel enseña la medalla que toca",
		(
			panel.get_node("Root/Box/Medal").visible
			and panel.get_node("Root/Box/Medal").text == "Tortilla"
		),
		"texto: '%s'" % panel.get_node("Root/Box/Medal").text
	)
	main.free()


func _marca_el_record_nuevo_solo_cuando_toca() -> void:
	var main: Node = await _partida()
	var panel: Node = main.game_over_panel
	main.change_state(GameState.State.PLAYING)
	main._on_scored()
	main._on_scored()
	main._on_scored()
	await _morir(main)
	await _esperar_panel(main)
	h.check(
		"la primera partida marca récord nuevo", panel.get_node("Root/Box/NewRecord").visible, ""
	)
	h.check(
		"y sin medalla si no llega al umbral",
		not panel.get_node("Root/Box/Medal").visible,
		"3 puntos, umbral de croqueta %d" % GameConfig.MEDAL_BRONZE
	)

	# Segunda partida, peor: no debe marcar récord.
	main.restart()
	await h.ticks(1)
	main.change_state(GameState.State.PLAYING)
	main._on_scored()
	await _morir(main)
	await _esperar_panel(main)
	h.check(
		"una partida peor no marca récord",
		not panel.get_node("Root/Box/NewRecord").visible,
		"puntuación 1, récord %d" % main.get_high_score()
	)
	h.check(
		"y el récord sigue siendo el bueno",
		panel.get_node("Root/Box/HighScore").text == "Récord 3",
		"texto: '%s'" % panel.get_node("Root/Box/HighScore").text
	)
	main.free()


## La animación de entrada no debe dejar el panel a medio escalar.
func _animacion_de_entrada() -> void:
	var main: Node = await _partida()
	var caja: Control = main.game_over_panel.get_node("Root/Box")
	await _morir(main)
	# En cuanto se hace visible, debe estar más pequeño que su tamaño final.
	var escala_min: float = 1.0
	for i in 180:
		await process_frame
		if main.game_over_panel.visible:
			escala_min = minf(escala_min, caja.scale.x)
		if main.game_over_panel.is_ready_for_input():
			break
	h.check(
		"el panel entra creciendo",
		escala_min < 1.0,
		"escala mínima: %.3f (pop %.2f)" % [escala_min, main.game_over_panel.pop_scale]
	)
	h.check(
		"y termina a tamaño natural",
		is_equal_approx(caja.scale.x, 1.0),
		"escala final: %.3f" % caja.scale.x
	)
	main.restart()
	await h.ticks(1)
	h.check(
		"y el reinicio no deja escala pegada",
		is_equal_approx(caja.scale.x, 1.0),
		"escala tras reiniciar: %.3f" % caja.scale.x
	)
	main.free()


func _el_boton_de_compartir_solo_en_android() -> void:
	var main: Node = await _partida()
	var boton: Button = main.game_over_panel.get_node("Root/Box/ShareButton")
	h.check(
		"el botón de compartir se oculta fuera de Android",
		boton.visible == OS.has_feature("android"),
		"visible=%s, android=%s" % [boton.visible, OS.has_feature("android")]
	)
	# Y el texto que compartiría es correcto, se pueda pulsar o no.
	var recibido: Array[String] = []
	main.game_over_panel.share_pressed.connect(func(t: String) -> void: recibido.append(t))
	main.change_state(GameState.State.PLAYING)
	main._on_scored()
	await _morir(main)
	main.game_over_panel._on_share_pressed()
	h.check(
		"compartir lleva la puntuación de la partida",
		not recibido.is_empty() and recibido[0] == "He cruzado 1 tubería con Flapo.",
		"texto: '%s'" % ("" if recibido.is_empty() else recibido[0])
	)
	main.free()
