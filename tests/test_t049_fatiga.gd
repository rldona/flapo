extends SceneTree
## T-049 — Fatiga por aleteo sin pausa.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-049 · Fatiga ---")
	_es_funcion_pura_del_historial()
	_no_castiga_el_juego_normal()
	await _una_rafaga_reduce_el_impulso()
	await _planear_descansa()
	await _dejar_de_aletear_tambien_descansa()
	await _reiniciar_borra_la_fatiga()
	SaveManager.clear()
	Settings.clear()
	quit(h.resumen("T-049"))


func _partida() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 61
	main.fruit_spawner.chance = 0.0
	main.bird.gravity = 0.0
	main.bird.collision_mask = 0
	return main


## Criterio: la fatiga es una función pura del historial, en GameConfig.
func _es_funcion_pura_del_historial() -> void:
	var n: int = GameConfig.FATIGUE_FLAP_COUNT
	h.check(
		"justo en el límite no hay fatiga",
		is_equal_approx(GameConfig.fatigue_impulse_mult(n), 1.0),
		"%d aleteos -> x%.2f" % [n, GameConfig.fatigue_impulse_mult(n)]
	)
	h.check(
		"uno más y sí",
		GameConfig.fatigue_impulse_mult(n + 1) < 1.0,
		"%d aleteos -> x%.2f" % [n + 1, GameConfig.fatigue_impulse_mult(n + 1)]
	)
	h.check(
		"la penalización es la configurada",
		is_equal_approx(GameConfig.fatigue_impulse_mult(n + 1), 1.0 - GameConfig.FATIGUE_PENALTY),
		(
			"x%.2f (penalización %.0f%%)"
			% [GameConfig.fatigue_impulse_mult(n + 1), GameConfig.FATIGUE_PENALTY * 100.0]
		)
	)
	h.check(
		"y nunca deja a Flapo sin impulso",
		GameConfig.fatigue_impulse_mult(999) > 0.5,
		"con 999 aleteos sigue en x%.2f" % GameConfig.fatigue_impulse_mult(999)
	)


## Lo que hace justa la mecánica: jugar bien nunca llega a fatigarse.
##
## La curva de dificultad da 3,39 aleteos por hueco en su punto más duro
## (ADR-0018), así que el umbral tiene que quedar por encima con margen.
func _no_castiga_el_juego_normal() -> void:
	var por_hueco: float = GameConfig.flaps_between_pipes(GameConfig.DIFFICULTY_CAP)
	h.check(
		"el ritmo normal de juego no fatiga",
		not GameConfig.is_fatigued(int(ceilf(por_hueco))),
		(
			"%.2f aleteos por hueco en el tope, umbral en %d"
			% [por_hueco, GameConfig.FATIGUE_FLAP_COUNT]
		)
	)


func _machacar(veces: int) -> void:
	for i in veces:
		h.pulsa(KEY_SPACE)
		await h.ticks(2)
		h.pulsa(KEY_SPACE, false)
		await h.ticks(2)


## Criterio: una ráfaga reduce el impulso del siguiente aleteo.
func _una_rafaga_reduce_el_impulso() -> void:
	var main: Node = await _partida()
	var bird: Node = main.bird
	h.jugar(main)

	# Un aleteo aislado da el impulso completo.
	h.pulsa(KEY_SPACE)
	await h.ticks(2)
	var sano: float = bird.velocity.y
	h.pulsa(KEY_SPACE, false)
	await h.ticks(2)
	h.check(
		"un aleteo aislado da el impulso completo",
		is_equal_approx(sano, bird.flap_impulse),
		"%.1f (impulso %.1f)" % [sano, bird.flap_impulse]
	)

	# Ráfaga: los suficientes para pasar del umbral dentro de la ventana.
	await _machacar(GameConfig.FATIGUE_FLAP_COUNT + 2)
	h.check(
		"machacar el botón fatiga",
		bird.is_fatigued(),
		"%d aleteos en la ventana, umbral %d" % [bird.recent_flaps(), GameConfig.FATIGUE_FLAP_COUNT]
	)
	h.check(
		"y el impulso del aleteo baja",
		bird.velocity.y > bird.flap_impulse,
		"%.1f fatigado frente a %.1f sano" % [bird.velocity.y, bird.flap_impulse]
	)
	h.check(
		"pero sigue siendo un impulso hacia arriba",
		bird.velocity.y < 0.0,
		"velocity.y %.1f" % bird.velocity.y
	)
	main.free()


## Criterio: planear descansa. Es la salida deliberada a la fatiga.
func _planear_descansa() -> void:
	var main: Node = await _partida()
	var bird: Node = main.bird
	h.jugar(main)
	await _machacar(GameConfig.FATIGUE_FLAP_COUNT + 2)
	h.check("de partida, fatigado", bird.is_fatigued(), "%d aleteos" % bird.recent_flaps())

	h.pulsa(KEY_SPACE)
	await h.ticks(20)
	h.check("planear activa el planeo", bird.is_gliding(), "")
	h.check(
		"y borra la fatiga de golpe",
		not bird.is_fatigued(),
		"%d aleteos tras planear" % bird.recent_flaps()
	)
	h.pulsa(KEY_SPACE, false)
	await h.ticks(2)
	main.free()


## Y esperar también, sin hacer nada: la ventana se vacía sola.
func _dejar_de_aletear_tambien_descansa() -> void:
	var main: Node = await _partida()
	var bird: Node = main.bird
	h.jugar(main)
	await _machacar(GameConfig.FATIGUE_FLAP_COUNT + 2)
	h.check("de partida, fatigado", bird.is_fatigued(), "%d aleteos" % bird.recent_flaps())

	# Nada más que dejar pasar la ventana entera, sin tocar el botón.
	await h.ticks(int(GameConfig.FATIGUE_WINDOW * 60.0) + 10)
	h.check(
		"dejar de aletear también descansa",
		not bird.is_fatigued(),
		"%d aleteos tras %.1f s parado" % [bird.recent_flaps(), GameConfig.FATIGUE_WINDOW]
	)
	main.free()


func _reiniciar_borra_la_fatiga() -> void:
	var main: Node = await _partida()
	var bird: Node = main.bird
	h.jugar(main)
	await _machacar(GameConfig.FATIGUE_FLAP_COUNT + 2)
	bird.gravity = 1200.0
	bird.collision_mask = Bird.OBSTACULOS
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	main.restart()
	await h.ticks(2)
	h.check(
		"reiniciar borra la fatiga",
		not bird.is_fatigued() and bird.recent_flaps() == 0,
		"%d aleteos" % bird.recent_flaps()
	)
	main.free()
