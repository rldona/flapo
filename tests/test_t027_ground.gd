extends SceneTree
## T-027 — Suelo con scroll infinito.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-027 · Suelo ---")
	await _cubre_la_pantalla_siempre()
	await _avanza_a_velocidad_de_scroll()
	await _flapo_muere_en_el_suelo()
	await _se_para_en_game_over()
	_el_suelo_llega_al_borde_de_cualquier_pantalla()
	quit(h.resumen("T-027"))


## Criterio: sin salto visible al reciclar.
##
## Traducido a algo comprobable: en NINGÚN frame puede quedar un hueco sin
## cubrir entre 0 y el ancho de pantalla, y los dos tiles deben estar siempre
## pegados exactamente. Un hueco de medio píxel es la costura que se ve.
func _cubre_la_pantalla_siempre() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	var ground: Node = main.ground
	var ancho: float = float(GameConfig.VIEWPORT_SIZE.x)
	var peor_hueco: float = 0.0
	var peor_separacion: float = 0.0
	var reciclados: int = 0
	var x0_anterior: float = 0.0

	# 30 s: sobra para reciclar muchas veces (a 100 px/s, cada 2,88 s).
	for tick in 1800:
		await physics_frame
		var t0: Node2D = ground.get_node("Tile0")
		var t1: Node2D = ground.get_node("Tile1")
		var izq: float = minf(t0.position.x, t1.position.x)
		var der: float = maxf(t0.position.x, t1.position.x) + ancho
		peor_hueco = maxf(peor_hueco, maxf(izq - 0.0, 0.0) + maxf(ancho - der, 0.0))
		peor_separacion = maxf(peor_separacion, absf(absf(t0.position.x - t1.position.x) - ancho))
		if t0.position.x > x0_anterior:
			reciclados += 1
		x0_anterior = t0.position.x

	h.check(
		"el suelo cubre la pantalla en todos los frames",
		is_zero_approx(peor_hueco),
		"peor hueco descubierto: %.6f px en 30 s" % peor_hueco
	)
	h.check(
		"los dos tiles van siempre pegados",
		peor_separacion < 0.0001,
		"peor desajuste entre tiles: %.6f px tras %d reciclados" % [peor_separacion, reciclados]
	)
	h.check("el suelo recicla de verdad", reciclados >= 9, "reciclados en 30 s: %d" % reciclados)
	main.free()


## El suelo va a la misma velocidad que las tuberías: si no, el mundo se
## deshace en dos capas que no cuadran.
func _avanza_a_velocidad_de_scroll() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	var t0: Node2D = main.ground.get_node("Tile0")
	var x_ini: float = t0.position.x
	await h.ticks(30)
	var recorrido: float = x_ini - t0.position.x
	var esperado: float = GameConfig.SCROLL_SPEED * 0.5
	h.check(
		"avanza a la velocidad de scroll",
		absf(recorrido - esperado) < 2.0,
		"%.2f px en 0,5 s (esperado %.2f)" % [recorrido, esperado]
	)
	main.free()


## Criterio arrastrado de T-023: al caer, muere en el suelo. Ahora de verdad,
## por colisión, y no por la red de seguridad `fall_death_y`.
func _flapo_muere_en_el_suelo() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	var bird: Node = main.bird
	h.jugar(main)
	for tick in 300:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	h.check(
		"Flapo muere al tocar el suelo",
		main.get_state() == GameState.State.GAME_OVER,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	h.check(
		"muere por colisión, no por la red de seguridad",
		bird.position.y < bird.fall_death_y,
		(
			"y al morir: %.1f (superficie %.1f, red %.1f)"
			% [bird.position.y, main.ground.surface_y(), bird.fall_death_y]
		)
	)
	# Y se queda encima del suelo, no lo atraviesa.
	await h.ticks(120)
	h.check(
		"Flapo se queda sobre el suelo",
		bird.position.y <= main.ground.surface_y() + 1.0,
		"y tras 2 s muerto: %.1f (superficie %.1f)" % [bird.position.y, main.ground.surface_y()]
	)
	main.free()


## En GAME_OVER el mundo se para entero: tuberías (T-025) y suelo.
func _se_para_en_game_over() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	await h.ticks(30)
	main.change_state(GameState.State.GAME_OVER)
	var t0: Node2D = main.ground.get_node("Tile0")
	var x_antes: float = t0.position.x
	await h.ticks(120)
	h.check(
		"el suelo se para en GAME_OVER",
		is_equal_approx(t0.position.x, x_antes),
		"x %.3f -> %.3f" % [x_antes, t0.position.x]
	)
	main.free()


## El suelo se dibuja hasta abajo, sea cual sea la pantalla (ADR-0042).
##
## Con el viewport más alto que los 512 del diseño, un suelo de la altura de
## la constante deja **cielo por debajo del suelo**. Se vio jugando en el
## móvil, no en un test: por eso la regla vive ahora en una función pura.
func _el_suelo_llega_al_borde_de_cualquier_pantalla() -> void:
	var superficie: float = GameConfig.playable_height()
	var casos: Array = [512.0, 624.0, 700.0, 1024.0]
	var cortos: Array = []
	for alto in casos:
		var dibujo: float = (
			GameConfig.ground_fill_height(alto, superficie) + GameConfig.GROUND_HEIGHT
		)
		if superficie + dibujo < alto:
			cortos.append("%.0f de pantalla → %.0f de suelo" % [alto, dibujo])
	h.check(
		"el suelo llega al borde inferior en cualquier alto de pantalla",
		cortos.is_empty(),
		"%s" % str(cortos)
	)
	h.check(
		"en una pantalla del alto de diseño no hace falta relleno",
		is_zero_approx(GameConfig.ground_fill_height(512.0, superficie)),
		"%.1f" % GameConfig.ground_fill_height(512.0, superficie)
	)
	# La colisión NO crece con la pantalla: si lo hiciera, morir contra el
	# suelo dependería del móvil que tengas.
	h.check(
		"pero la colisión sigue siendo la de siempre",
		is_equal_approx(GameConfig.GROUND_HEIGHT, 64.0),
		"%.1f" % GameConfig.GROUND_HEIGHT
	)
