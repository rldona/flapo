extends SceneTree
## T-045 — Curva de dificultad.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-045 · Dificultad ---")
	_la_curva_es_monotona_y_con_tope()
	_nunca_baja_del_umbral_de_lo_justo()
	await _la_partida_acelera_de_verdad()
	await _reiniciar_devuelve_la_dificultad_inicial()
	SaveManager.clear()
	Settings.clear()
	quit(h.resumen("T-045"))


func _partida() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 77
	# Flapo, inmune: sin gravedad y sin máscara de colisión. Si no, choca con
	# una tubería a mitad de medición, el mundo se para —correctamente— y lo
	# que se acaba midiendo es la velocidad de un juego en GAME_OVER.
	main.bird.gravity = 0.0
	main.bird.collision_mask = 0
	return main


## Con puntuación 0 tiene que salir exactamente lo que dice el GDD, y a partir
## de ahí subir sin pasarse del tope.
func _la_curva_es_monotona_y_con_tope() -> void:
	h.check(
		"con 0 puntos la dificultad es la del GDD",
		(
			is_equal_approx(GameConfig.scroll_speed_for(0), GameConfig.SCROLL_SPEED)
			and is_equal_approx(GameConfig.pipe_gap_for(0), GameConfig.PIPE_GAP)
		),
		"%.0f px/s, hueco %.0f px" % [GameConfig.scroll_speed_for(0), GameConfig.pipe_gap_for(0)]
	)

	var sube: bool = true
	var encoge: bool = true
	for score in range(1, GameConfig.DIFFICULTY_CAP + 1):
		if GameConfig.scroll_speed_for(score) < GameConfig.scroll_speed_for(score - 1):
			sube = false
		if GameConfig.pipe_gap_for(score) > GameConfig.pipe_gap_for(score - 1):
			encoge = false
	h.check("la velocidad nunca baja", sube, "")
	h.check("el hueco nunca crece", encoge, "")

	var cap: int = GameConfig.DIFFICULTY_CAP
	h.check(
		"a partir del tope no sube más",
		(
			is_equal_approx(GameConfig.scroll_speed_for(cap), GameConfig.scroll_speed_for(cap * 10))
			and is_equal_approx(GameConfig.pipe_gap_for(cap), GameConfig.pipe_gap_for(cap * 10))
		),
		(
			"a %d puntos: %.0f px/s, hueco %.0f px"
			% [cap * 10, GameConfig.scroll_speed_for(cap * 10), GameConfig.pipe_gap_for(cap * 10)]
		)
	)


## El umbral que hizo elegir esta forma de curva: por debajo de 3 aleteos
## entre tuberías no da tiempo a corregir, y el juego pasa de difícil a
## injusto (docs/GDD.md). Se comprueba en TODA la curva, no solo en el tope.
func _nunca_baja_del_umbral_de_lo_justo() -> void:
	var peor: float = INF
	var peor_score: int = 0
	for score in range(0, GameConfig.DIFFICULTY_CAP * 2):
		var f: float = GameConfig.flaps_between_pipes(score)
		if f < peor:
			peor = f
			peor_score = score
	h.check(
		"siempre caben más de 3 aleteos entre tuberías",
		peor > 3.0,
		"mínimo %.2f aleteos, con %d puntos" % [peor, peor_score]
	)
	# Y el hueco nunca se acerca a la hitbox: 16 px de diámetro.
	h.check(
		"el hueco nunca baja de 4 veces la hitbox",
		GameConfig.pipe_gap_for(GameConfig.DIFFICULTY_CAP) >= 16.0 * 4.0,
		"hueco mínimo %.0f px" % GameConfig.pipe_gap_for(GameConfig.DIFFICULTY_CAP)
	)


## Que la curva exista en una hoja de cálculo no basta: el mundo tiene que
## moverse más rápido de verdad, y todo a la vez.
func _la_partida_acelera_de_verdad() -> void:
	var main: Node = await _partida()
	main.change_state(GameState.State.PLAYING)
	await h.ticks(30)

	# El suelo recicla con `fmod` (ADR-0010), así que su x da la vuelta cada
	# 288 px: restar posiciones a pelo mide mal en cuanto cruza el salto.
	# `fposmod` sobre el ancho del tile devuelve el avance real.
	var ancho: float = float(GameConfig.VIEWPORT_SIZE.x)
	var suelo: Node2D = main.ground.get_node("Tile0")
	var x0: float = suelo.position.x
	await h.ticks(60)
	var lento: float = fposmod(x0 - suelo.position.x, ancho)

	for punto in GameConfig.DIFFICULTY_CAP:
		main._on_scored()
	await h.ticks(2)

	x0 = suelo.position.x
	await h.ticks(60)
	var rapido: float = fposmod(x0 - suelo.position.x, ancho)

	# La premisa de la medida, comprobada en vez de supuesta: si la partida se
	# hubiera acabado, las cifras de arriba no significan nada.
	h.check(
		"la partida sigue viva durante la medición",
		main.get_state() == GameState.State.PLAYING,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	h.check(
		"el suelo corre más al subir la puntuación",
		rapido > lento * 1.2,
		"%.1f px/s con 0 puntos -> %.1f px/s con %d" % [lento, rapido, GameConfig.DIFFICULTY_CAP]
	)
	h.check(
		"y el spawner acelera con él",
		is_equal_approx(
			main.pipe_spawner.get_node("Timer").wait_time,
			GameConfig.pipe_spawn_interval_for(GameConfig.DIFFICULTY_CAP)
		),
		"intervalo %.3f s" % main.pipe_spawner.get_node("Timer").wait_time
	)
	h.check(
		"y las tuberías nuevas nacen con el hueco reducido",
		is_equal_approx(main.pipe_spawner.gap, GameConfig.pipe_gap_for(GameConfig.DIFFICULTY_CAP)),
		"hueco %.1f px" % main.pipe_spawner.gap
	)

	# Todas las tuberías vivas van a la misma velocidad: si no, la separación
	# entre ellas se deformaría en pantalla.
	var todas_iguales: bool = true
	for hijo in main.pipe_spawner.get_children():
		if hijo is Pipe and not is_equal_approx(hijo.scroll_speed, main.pipe_spawner.scroll_speed):
			todas_iguales = false
	h.check("el mundo se mueve como un bloque", todas_iguales, "")
	main.free()


## La dificultad es función pura de la puntuación, así que reiniciar la
## devuelve al inicio sin código de limpieza. Se comprueba porque si algún
## día deja de serlo, la segunda partida empezaría en modo difícil.
func _reiniciar_devuelve_la_dificultad_inicial() -> void:
	var main: Node = await _partida()
	main.change_state(GameState.State.PLAYING)
	for punto in GameConfig.DIFFICULTY_CAP:
		main._on_scored()
	await h.ticks(2)
	# Aquí sí queremos que muera: se le devuelven gravedad y colisiones.
	main.bird.gravity = 1200.0
	main.bird.collision_mask = 4
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	main.restart()
	await h.ticks(2)
	h.check(
		"al reiniciar vuelve la velocidad inicial",
		is_equal_approx(main.ground.scroll_speed, GameConfig.SCROLL_SPEED),
		"%.1f px/s" % main.ground.scroll_speed
	)
	h.check(
		"y el hueco inicial",
		is_equal_approx(main.pipe_spawner.gap, GameConfig.PIPE_GAP),
		"%.1f px" % main.pipe_spawner.gap
	)
	main.free()
