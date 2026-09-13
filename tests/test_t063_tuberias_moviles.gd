extends SceneTree
## T-063 — Tuberías con movimiento vertical.
##
## Las dos garantías del ticket, y las dos se comprueban aquí:
##
## 1. **El hueco completo nunca se sale de la zona jugable**, en ninguna
##    puntuación y en ningún modo de dificultad. No basta con el centro: un
##    hueco medio fuera de pantalla es una muerte que el jugador no ve venir.
## 2. **A puntuación baja no aparecen nunca**, para no romper la rampa de
##    entrada (T-046).

const MAIN := "res://scenes/Main.tscn"
const PIPE := "res://scenes/Pipe.tscn"
const MODOS: Array = [
	GameConfig.Difficulty.FACIL, GameConfig.Difficulty.NORMAL, GameConfig.Difficulty.DIFICIL
]

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-063 · Tuberías móviles ---")
	_la_probabilidad_es_funcion_pura_de_la_puntuacion()
	_la_amplitud_nunca_saca_el_hueco_de_la_pantalla()
	await _la_tuberia_nunca_corre_mas_que_flapo()
	await _una_tuberia_oscila_de_verdad_y_dentro_de_limites()
	await _en_partida_no_salen_antes_del_minimo()
	await _y_a_puntuacion_alta_si_salen()
	SaveManager.clear()
	quit(h.resumen("T-063"))


## Criterio: probabilidad como función pura de la puntuación (T-045).
func _la_probabilidad_es_funcion_pura_de_la_puntuacion() -> void:
	h.check(
		"a 0 puntos la probabilidad es exactamente 0",
		is_zero_approx(GameConfig.moving_pipe_chance(0)),
		"%.3f" % GameConfig.moving_pipe_chance(0)
	)
	h.check(
		"justo antes del mínimo sigue siendo 0",
		is_zero_approx(GameConfig.moving_pipe_chance(GameConfig.MOVING_PIPE_MIN_SCORE - 1)),
		"%.3f" % GameConfig.moving_pipe_chance(GameConfig.MOVING_PIPE_MIN_SCORE - 1)
	)
	h.check(
		"en el mínimo arranca",
		GameConfig.moving_pipe_chance(GameConfig.MOVING_PIPE_MIN_SCORE) > 0.0,
		"%.3f" % GameConfig.moving_pipe_chance(GameConfig.MOVING_PIPE_MIN_SCORE)
	)
	# Monótona: nunca baja al subir la puntuación.
	var anterior: float = -1.0
	var monotona: bool = true
	for punto in 60:
		var actual: float = GameConfig.moving_pipe_chance(punto)
		if actual < anterior - 0.0001:
			monotona = false
		anterior = actual
	h.check("y no baja nunca al subir la puntuación", monotona, "")
	h.check(
		"con tope: nunca es certeza",
		GameConfig.moving_pipe_chance(1000) < 1.0,
		"%.3f a 1000 puntos" % GameConfig.moving_pipe_chance(1000)
	)


## Criterio: el rango de oscilación nunca saca el hueco de la zona jugable,
## **en toda la curva de dificultad** y en los tres modos.
func _la_amplitud_nunca_saca_el_hueco_de_la_pantalla() -> void:
	var alto: float = GameConfig.playable_height()
	var peor_arriba: float = INF
	var peor_abajo: float = INF
	var casos: int = 0
	for modo in MODOS:
		for punto in [0, 7, 15, 22, GameConfig.DIFFICULTY_CAP, 60]:
			var gap: float = GameConfig.pipe_gap_for(punto, modo)
			# Se barre todo el rango de alturas donde puede caer un hueco.
			for paso in 21:
				var ratio: float = lerpf(0.20, 0.80, float(paso) / 20.0)
				var centro: float = ratio * alto
				var amp: float = GameConfig.moving_pipe_amplitude(gap, centro)
				peor_arriba = minf(peor_arriba, centro - gap * 0.5 - amp)
				peor_abajo = minf(peor_abajo, alto - (centro + gap * 0.5 + amp))
				casos += 1
	h.check(
		"el borde de arriba del hueco nunca pasa del techo (%d casos)" % casos,
		peor_arriba >= -0.001,
		"peor margen arriba: %.3f px" % peor_arriba
	)
	h.check(
		"ni el de abajo del suelo", peor_abajo >= -0.001, "peor margen abajo: %.3f px" % peor_abajo
	)
	# Y donde no cabe margen, la tubería sale quieta en vez de a medias.
	h.check(
		"sin margen, amplitud 0 en vez de un hueco fuera de pantalla",
		is_zero_approx(GameConfig.moving_pipe_amplitude(alto, alto * 0.5)),
		"%.3f" % GameConfig.moving_pipe_amplitude(alto, alto * 0.5)
	)


## Una tubería que sube más rápido de lo que Flapo puede subir no es
## exigente, es inevitable.
func _la_tuberia_nunca_corre_mas_que_flapo() -> void:
	var punta: float = GameConfig.moving_pipe_peak_speed(GameConfig.MOVING_PIPE_AMPLITUDE)
	# El impulso sale del propio Flapo, no de un número copiado aquí: si
	# alguien lo tunea en T-040, este test se entera.
	var bird: Bird = (load("res://scenes/Bird.tscn") as PackedScene).instantiate()
	root.add_child(bird)
	await process_frame
	var aleteo: float = absf(bird.flap_impulse)
	bird.free()
	h.check(
		"la oscilación va muy por debajo de lo que sube un aleteo",
		punta < aleteo * 0.25,
		"%.1f px/s de punta frente a %.1f px/s de aleteo" % [punta, aleteo]
	)


## Y en movimiento real: oscila, y no se sale.
func _una_tuberia_oscila_de_verdad_y_dentro_de_limites() -> void:
	var escena: PackedScene = load(PIPE)
	var pipe: Pipe = escena.instantiate()
	root.add_child(pipe)
	await process_frame
	pipe.scroll_speed = 0.0  # Aísla la vertical: aquí no interesa el scroll.
	pipe.gap = GameConfig.PIPE_GAP
	var centro: float = GameConfig.playable_height() * 0.5
	pipe.set_gap_center(centro)
	var amp: float = GameConfig.moving_pipe_amplitude(pipe.gap, centro)
	h.check("la del centro tiene margen de sobra para oscilar", amp > 0.0, "%.1f px" % amp)
	pipe.oscillation_amplitude = amp
	h.check("y se declara oscilante", pipe.is_oscillating(), "")

	var minimo: float = INF
	var maximo: float = -INF
	# Un periodo y medio, para pillar seguro las dos puntas.
	var ticks: int = int(GameConfig.MOVING_PIPE_PERIOD * 1.5 * 60.0)
	for i in ticks:
		await physics_frame
		minimo = minf(minimo, pipe.get_gap_center())
		maximo = maxf(maximo, pipe.get_gap_center())

	h.check(
		"se mueve de verdad, no se queda quieta",
		maximo - minimo > amp,
		"recorrido %.1f px (amplitud %.1f)" % [maximo - minimo, amp]
	)
	h.check(
		"y no se pasa de la amplitud pedida",
		minimo >= centro - amp - 0.5 and maximo <= centro + amp + 0.5,
		"entre %.1f y %.1f (centro %.1f ± %.1f)" % [minimo, maximo, centro, amp]
	)
	h.check(
		"el hueco entero se queda dentro de la pantalla",
		minimo - pipe.gap * 0.5 >= 0.0 and maximo + pipe.gap * 0.5 <= GameConfig.playable_height(),
		(
			"borde arriba %.1f, borde abajo %.1f (jugable %.1f)"
			% [minimo - pipe.gap * 0.5, maximo + pipe.gap * 0.5, GameConfig.playable_height()]
		)
	)
	# La altura de reposo no se mueve con la oscilación: T-067 la necesitará.
	h.check(
		"la altura de reposo no se desplaza",
		is_equal_approx(pipe.get_base_gap_center(), centro),
		"%.2f" % pipe.get_base_gap_center()
	)
	pipe.free()


## Criterio: a puntuación baja no aparecen (no rompe la rampa de T-046).
func _en_partida_no_salen_antes_del_minimo() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.fruit_spawner.chance = 0.0
	main.pipe_spawner.random_seed = 11
	h.jugar(main)
	# El aislamiento va DESPUÉS de arrancar: entrar en READY le devuelve a
	# Flapo la máscara de colisión, así que hacerlo antes no sirve de nada.
	# Sin esto la partida se acaba en 3 s y lo que se mide no es nada.
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0

	var moviles: int = 0
	var vistas: int = 0
	for tick in 900:
		await physics_frame
		for hijo in main.pipe_spawner.get_children():
			if hijo is Pipe:
				vistas += 1
				if (hijo as Pipe).is_oscillating():
					moviles += 1
	h.check(
		"premisa: la partida sigue viva",
		main.get_state() == GameState.State.PLAYING,
		"estado: %d" % main.get_state()
	)
	h.check("premisa: han salido tuberías", vistas > 0, "%d observaciones" % vistas)
	h.check(
		"a 0 puntos no oscila ninguna",
		moviles == 0,
		"%d observaciones oscilantes de %d" % [moviles, vistas]
	)
	main.free()


## Y por encima del mínimo sí salen: si no, la mecánica no existiría.
func _y_a_puntuacion_alta_si_salen() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.fruit_spawner.chance = 0.0
	main.pipe_spawner.random_seed = 11
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	# Se sube el marcador al tope de la curva, donde la probabilidad es máxima.
	for punto in GameConfig.DIFFICULTY_CAP:
		main._on_scored()
	await h.ticks(2)
	h.check(
		"premisa: la probabilidad ahí es alta",
		main.pipe_spawner.moving_chance >= GameConfig.MOVING_PIPE_CHANCE_MAX - 0.001,
		"%.3f" % main.pipe_spawner.moving_chance
	)

	var moviles: int = 0
	var alto: float = GameConfig.playable_height()
	var peor: float = INF
	for tick in 1800:
		await physics_frame
		for hijo in main.pipe_spawner.get_children():
			if hijo is Pipe:
				var p: Pipe = hijo
				if p.is_oscillating():
					moviles += 1
				# Y ninguna, oscile o no, saca su hueco de la pantalla.
				peor = minf(peor, p.get_gap_center() - p.gap * 0.5)
				peor = minf(peor, alto - (p.get_gap_center() + p.gap * 0.5))
	h.check(
		"premisa: la partida sigue viva",
		main.get_state() == GameState.State.PLAYING,
		"estado: %d" % main.get_state()
	)
	h.check("en el tope de la curva sí salen móviles", moviles > 0, "%d observaciones" % moviles)
	h.check(
		"y en toda la partida ningún hueco se sale de la pantalla",
		peor >= -0.001,
		"peor margen: %.2f px" % peor
	)
	main.free()
