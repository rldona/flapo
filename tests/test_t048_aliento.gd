extends SceneTree
## T-048 — Aliento: recurso de vuelo.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-048 · Aliento ---")
	_constantes_en_gameconfig()
	await _aletear_gasta_aliento()
	await _mantener_pulsado_planea_y_gasta_menos()
	await _el_aliento_nunca_se_sale_del_rango()
	await _sin_aliento_el_planeo_no_frena_pero_el_aleteo_sigue()
	await _cruzar_por_el_centro_recupera()
	await _el_hud_no_tapa_la_puntuacion()
	await _reiniciar_devuelve_el_aliento_lleno()
	SaveManager.clear()
	Settings.clear()
	quit(h.resumen("T-048"))


func _partida() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 55
	main.fruit_spawner.chance = 0.0  # Las frutas son otro ticket.
	# Se sale del menú antes de quitarle la máscara: entrar en READY se la
	# devuelve, así que al revés no serviría de nada (T-078).
	main.change_state(GameState.State.READY)
	main.bird.collision_mask = 0
	return main


## Criterio: las cuatro constantes viven en GameConfig.
func _constantes_en_gameconfig() -> void:
	h.check(
		"MAX_BREATH definido y positivo",
		GameConfig.MAX_BREATH > 0.0,
		"%.0f" % GameConfig.MAX_BREATH
	)
	h.check(
		"aletear cuesta más que planear un segundo",
		GameConfig.BREATH_DRAIN_FLAP * 2.5 > GameConfig.BREATH_DRAIN_GLIDE,
		(
			"2,5 aleteos/s = %.1f/s frente a planear %.1f/s"
			% [GameConfig.BREATH_DRAIN_FLAP * 2.5, GameConfig.BREATH_DRAIN_GLIDE]
		)
	)
	h.check(
		"cruzar un hueco no llena la barra de golpe",
		GameConfig.BREATH_RECOVER_ON_GAP < GameConfig.MAX_BREATH * 0.5,
		"recupera %.0f de %.0f" % [GameConfig.BREATH_RECOVER_ON_GAP, GameConfig.MAX_BREATH]
	)
	h.check(
		"solo la franja central del hueco recupera",
		GameConfig.BREATH_BAND_RATIO > 0.0 and GameConfig.BREATH_BAND_RATIO < 1.0,
		"%.2f del hueco" % GameConfig.BREATH_BAND_RATIO
	)


func _aletear_gasta_aliento() -> void:
	var main: Node = await _partida()
	h.jugar(main)
	var antes: float = main.bird.breath()
	h.pulsa(KEY_SPACE)
	await h.ticks(3)
	h.pulsa(KEY_SPACE, false)
	await h.ticks(2)
	h.check(
		"aletear gasta aliento",
		main.bird.breath() < antes,
		"%.1f -> %.1f" % [antes, main.bird.breath()]
	)
	main.free()


## Criterio del ticket: mantener pulsado planea, y planear cuesta menos.
func _mantener_pulsado_planea_y_gasta_menos() -> void:
	var main: Node = await _partida()
	var bird: Node = main.bird
	h.jugar(main)

	# Un segundo pulsado: un aleteo inicial y el resto planeando.
	h.pulsa(KEY_SPACE)
	await h.ticks(60)
	h.check("mantener pulsado activa el planeo", bird.is_gliding(), "")
	var gastado_planeando: float = GameConfig.MAX_BREATH - bird.breath()
	var y_planeando: float = bird.velocity.y
	h.pulsa(KEY_SPACE, false)
	await h.ticks(2)
	h.check("soltar corta el planeo", not bird.is_gliding(), "")

	h.check(
		"planeando cae mucho más despacio",
		y_planeando <= bird.glide_max_fall_speed + 1.0,
		(
			"velocity.y planeando %.1f (tope planeo %.1f, tope normal %.1f)"
			% [y_planeando, bird.glide_max_fall_speed, bird.max_fall_speed]
		)
	)
	h.check(
		"un segundo planeando cuesta menos que un segundo aleteando",
		gastado_planeando < GameConfig.BREATH_DRAIN_FLAP * 2.5,
		"%.1f frente a %.1f" % [gastado_planeando, GameConfig.BREATH_DRAIN_FLAP * 2.5]
	)
	main.free()


## Criterio: el aliento se mantiene dentro de [0, MAX_BREATH] siempre.
func _el_aliento_nunca_se_sale_del_rango() -> void:
	var main: Node = await _partida()
	var bird: Node = main.bird
	h.jugar(main)
	# Sin gravedad, para que Flapo no se estrelle a mitad de la medida: al
	# morir se sale de PLAYING y el planeo deja de gastar, así que el mínimo
	# observado era 16 y no 0.
	bird.gravity = 0.0
	var minimo: float = INF
	var maximo: float = -INF

	# Fase 1: mantener pulsado hasta agotarlo del todo.
	h.pulsa(KEY_SPACE)
	for i in 600:
		await physics_frame
		minimo = minf(minimo, bird.breath())
		maximo = maxf(maximo, bird.breath())
	h.pulsa(KEY_SPACE, false)

	# Fase 2: recuperar MÁS de la cuenta, para probar el tope por arriba.
	for i in 10:
		bird.recover_breath(GameConfig.BREATH_RECOVER_ON_GAP)
		await physics_frame
		minimo = minf(minimo, bird.breath())
		maximo = maxf(maximo, bird.breath())

	h.check(
		"el aliento nunca baja de 0 ni pasa del máximo",
		minimo >= 0.0 and maximo <= GameConfig.MAX_BREATH,
		"rango recorrido [%.1f, %.1f] sobre [0, %.0f]" % [minimo, maximo, GameConfig.MAX_BREATH]
	)
	# Sin esto el test pasaría aunque el aliento no se moviera: midiendo solo
	# después de recuperar, el rango observado era [100, 100] y no comprobaba
	# nada (docs/testing.md, "preguntar lo que importa").
	h.check(
		"y toca los dos extremos, no se queda en el medio",
		is_zero_approx(minimo) and is_equal_approx(maximo, GameConfig.MAX_BREATH),
		"mínimo %.2f, máximo %.2f" % [minimo, maximo]
	)
	main.free()


## Criterio: a 0 el planeo deja de frenar, pero el aleteo sigue funcionando.
func _sin_aliento_el_planeo_no_frena_pero_el_aleteo_sigue() -> void:
	var main: Node = await _partida()
	var bird: Node = main.bird
	h.jugar(main)
	bird.recover_breath(-GameConfig.MAX_BREATH)
	h.check("se puede llegar a 0 de aliento", is_zero_approx(bird.breath()), "%.2f" % bird.breath())

	h.pulsa(KEY_SPACE)
	await h.ticks(60)
	h.check("sin aliento no se planea", not bird.is_gliding(), "")
	h.check(
		"y la caída vuelve a ser la normal",
		bird.velocity.y > bird.glide_max_fall_speed,
		"velocity.y %.1f (tope planeo %.1f)" % [bird.velocity.y, bird.glide_max_fall_speed]
	)
	h.pulsa(KEY_SPACE, false)
	await h.ticks(2)

	# Y el aleteo corto sigue dando el impulso completo: Flapo nunca se queda
	# sin poder aletear, que es la regla que hace el recurso justo.
	h.pulsa(KEY_SPACE)
	var v_min: float = INF
	for i in 5:
		await physics_frame
		v_min = minf(v_min, bird.velocity.y)
	h.pulsa(KEY_SPACE, false)
	h.check(
		"sin aliento el aleteo sigue dando el impulso completo",
		is_equal_approx(v_min, bird.flap_impulse),
		"velocity.y mínima %.1f (impulso %.1f)" % [v_min, bird.flap_impulse]
	)
	main.free()


## Recuperar exige pasar por el CENTRO del hueco, no por cualquier sitio.
func _cruzar_por_el_centro_recupera() -> void:
	for caso in [{"centrado": true}, {"centrado": false}]:
		var mundo := Node2D.new()
		root.add_child(mundo)
		var pipe: Node = load("res://scenes/Pipe.tscn").instantiate()
		pipe.moving = false
		pipe.position = Vector2(120.0, 0.0)
		mundo.add_child(pipe)
		var bird: Node = load("res://scenes/Bird.tscn").instantiate()
		bird.gravity = 0.0
		mundo.add_child(bird)
		await process_frame
		pipe.set_gap_center(256.0)
		# Centrado, o justo por dentro del hueco pero fuera de la franja.
		var borde: float = pipe.gap * GameConfig.BREATH_BAND_RATIO * 0.5
		bird.position = Vector2(40.0, 256.0 if caso["centrado"] else 256.0 + borde + 12.0)
		bird._state = GameState.State.PLAYING

		# Array y no bool: los lambdas capturan las locales por valor
		# (docs/testing.md), así que un bool suelto nunca cambiaría.
		var centrado_local: Array[bool] = [false]
		pipe.centered.connect(func() -> void: centrado_local[0] = true)
		for i in 120:
			bird.velocity = Vector2(120.0, 0.0)
			await physics_frame
			if bird.position.x > 200.0:
				break
		h.check(
			(
				"cruzar %s recupera aliento"
				% ("por el centro" if caso["centrado"] else "de refilón NO")
			),
			centrado_local[0] == caso["centrado"],
			"y de paso %.0f, franja +-%.0f px" % [bird.position.y, borde]
		)
		mundo.free()


## Criterio: el HUD muestra el aliento sin tapar la puntuación.
func _el_hud_no_tapa_la_puntuacion() -> void:
	var main: Node = await _partida()
	var marcador: Control = main.hud.get_node("Score")
	var barra: Control = main.hud.get_node("Breath")
	h.jugar(main)
	await h.ticks(2)

	var r_marcador := Rect2(marcador.global_position, marcador.size)
	var r_barra := Rect2(barra.global_position, barra.size)
	h.check(
		"la barra de aliento no se solapa con la puntuación",
		not r_marcador.intersects(r_barra),
		"marcador %s, barra %s" % [r_marcador, r_barra]
	)

	var relleno: ColorRect = main.hud.get_node("Breath/Fill")
	var lleno: float = relleno.offset_right
	main.bird.recover_breath(-GameConfig.MAX_BREATH * 0.5)
	await h.ticks(1)
	h.check(
		"la barra se encoge al gastar aliento",
		relleno.offset_right < lleno,
		"%.1f px -> %.1f px" % [lleno, relleno.offset_right]
	)
	main.free()


func _reiniciar_devuelve_el_aliento_lleno() -> void:
	var main: Node = await _partida()
	h.jugar(main)
	main.bird.recover_breath(-GameConfig.MAX_BREATH)
	main.bird.collision_mask = Bird.OBSTACULOS
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	main.restart()
	await h.ticks(2)
	h.check(
		"reiniciar devuelve el aliento lleno",
		is_equal_approx(main.bird.breath(), GameConfig.MAX_BREATH),
		"%.1f de %.0f" % [main.bird.breath(), GameConfig.MAX_BREATH]
	)
	main.free()
