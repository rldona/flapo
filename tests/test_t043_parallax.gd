extends SceneTree
## T-043 — Parallax de fondo.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-043 · Parallax ---")
	await _dos_capas_a_distinta_velocidad()
	await _mas_lento_que_el_suelo()
	await _se_para_en_game_over()
	await _se_reinicia_al_volver_a_ready()
	quit(h.resumen("T-043"))


func _partida() -> Node:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 11
	return main


func _idle(n: int) -> void:
	for i in n:
		await process_frame


## Lo que hace que un parallax sea un parallax: las capas NO van igual.
func _dos_capas_a_distinta_velocidad() -> void:
	var main: Node = await _partida()
	var bg: Node = main.background
	h.jugar(main)
	await _idle(60)
	var lejos: float = absf(bg.layer_offset(0))
	var cerca: float = absf(bg.layer_offset(1))
	h.check(
		"las dos capas se mueven",
		lejos > 0.0 and cerca > 0.0,
		"lejos %.1f, cerca %.1f" % [lejos, cerca]
	)
	h.check(
		"la capa lejana se mueve menos que la cercana",
		lejos < cerca,
		"lejos %.1f px < cerca %.1f px" % [lejos, cerca]
	)
	var ratio: float = lejos / cerca if cerca > 0.0 else 0.0
	var esperado: float = bg.layer_speeds[0] / bg.layer_speeds[1]
	h.check(
		"la proporción es la configurada",
		absf(ratio - esperado) < 0.02,
		"ratio %.3f (esperado %.3f)" % [ratio, esperado]
	)
	main.free()


## El fondo es fondo: si fuera a la velocidad del suelo, no habría
## profundidad, solo dos suelos.
func _mas_lento_que_el_suelo() -> void:
	var main: Node = await _partida()
	# Sin gravedad: si Flapo muere a mitad de la medición, el suelo se para
	# (correctamente) y lo que se compara es basura.
	main.bird.gravity = 0.0
	h.jugar(main)
	var t0: Node2D = main.ground.get_node("Tile0")
	var x_ini: float = t0.position.x
	var bg_ini: float = main.background.layer_offset(1)
	await h.ticks(60)
	var cerca: float = absf(main.background.layer_offset(1) - bg_ini)
	var suelo: float = absf(t0.position.x - x_ini)
	h.check(
		"el fondo va más lento que el suelo",
		cerca < suelo,
		"fondo %.1f px/s vs suelo %.1f px/s" % [cerca, suelo]
	)
	main.free()


## Criterio: se detiene en GAME_OVER.
func _se_para_en_game_over() -> void:
	var main: Node = await _partida()
	h.jugar(main)
	await _idle(30)
	main.change_state(GameState.State.GAME_OVER)
	await _idle(2)
	var antes: Array[float] = [main.background.layer_offset(0), main.background.layer_offset(1)]
	await _idle(120)
	h.check(
		"el parallax se para en GAME_OVER",
		(
			is_equal_approx(main.background.layer_offset(0), antes[0])
			and is_equal_approx(main.background.layer_offset(1), antes[1])
		),
		(
			"lejos %.3f -> %.3f, cerca %.3f -> %.3f"
			% [antes[0], main.background.layer_offset(0), antes[1], main.background.layer_offset(1)]
		)
	)
	main.free()


func _se_reinicia_al_volver_a_ready() -> void:
	var main: Node = await _partida()
	h.jugar(main)
	await _idle(120)
	main.change_state(GameState.State.GAME_OVER)
	main.restart()
	# Se mide SIN esperar: en READY el fondo vuelve a moverse enseguida, a
	# propósito (mundo vivo mientras Flapo espera, igual que el suelo).
	h.check(
		"al reiniciar el fondo vuelve al origen",
		(
			is_zero_approx(main.background.layer_offset(0))
			and is_zero_approx(main.background.layer_offset(1))
		),
		(
			"lejos %.3f, cerca %.3f"
			% [main.background.layer_offset(0), main.background.layer_offset(1)]
		)
	)
	await _idle(30)
	h.check(
		"y vuelve a moverse",
		absf(main.background.layer_offset(1)) > 0.0,
		"cerca %.3f tras 0,5 s" % main.background.layer_offset(1)
	)
	main.free()
