extends SceneTree
## T-064 — Ráfagas de viento.
##
## Los dos criterios del ticket, y los dos se comprueban aquí:
##
## 1. **El viento nunca saca el scroll del sobre de la curva**, combinado con
##    la dificultad ya existente y en los tres modos.
## 2. **Siempre avisa antes**, y el factor **se deshace solo** al terminar.

const MAIN := "res://scenes/Main.tscn"
const MODOS: Array = [
	GameConfig.Difficulty.FACIL, GameConfig.Difficulty.NORMAL, GameConfig.Difficulty.DIFICIL
]

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-064 · Viento ---")
	_nunca_saca_el_scroll_del_sobre()
	_sopla_hacia_donde_hay_margen()
	await _siempre_avisa_antes_de_soplar()
	await _el_factor_se_deshace_solo()
	await _fuera_de_partida_no_hay_viento()
	SaveManager.clear()
	quit(h.resumen("T-064"))


## Criterio 1: ni por arriba ni por abajo, en toda la curva y los tres modos.
func _nunca_saca_el_scroll_del_sobre() -> void:
	var fuera: Array = []
	var casos: int = 0
	for modo in MODOS:
		var suelo: float = GameConfig.scroll_speed_for(0, modo)
		var techo: float = GameConfig.scroll_speed_for(GameConfig.DIFFICULTY_CAP, modo)
		for punto in [0, 5, 10, 15, 22, GameConfig.DIFFICULTY_CAP, 60, 200]:
			for a_favor in [true, false]:
				var f: float = GameConfig.wind_factor_for(punto, modo, a_favor)
				var v: float = GameConfig.wind_speed_for(punto, modo, f)
				casos += 1
				if v < suelo - 0.001 or v > techo + 0.001:
					fuera.append("%s p%d %s -> %.1f" % [modo, punto, a_favor, v])
	h.check(
		"en %d combinaciones el scroll se queda dentro del sobre" % casos,
		fuera.is_empty(),
		"fuera: %s" % str(fuera)
	)
	# Y la fruta violeta SIGUE pudiendo bajar del mínimo: es su efecto, y el
	# criterio del viento no debía llevárselo por delante.
	var e := Effects.new()
	e.apply(Effects.Kind.LENTO)
	var con_fruta: float = (
		GameConfig.scroll_speed_for(0, GameConfig.Difficulty.NORMAL) * e.speed_mult()
	)
	h.check(
		"pero la fruta violeta sigue bajando del mínimo",
		con_fruta < GameConfig.SCROLL_SPEED,
		"%.1f frente al mínimo %.1f" % [con_fruta, GameConfig.SCROLL_SPEED]
	)
	e.free()


## La consecuencia fea de acotar, resuelta: una ráfaga siempre se nota.
func _sopla_hacia_donde_hay_margen() -> void:
	var sin_efecto: Array = []
	for modo in MODOS:
		for punto in [0, 5, 15, GameConfig.DIFFICULTY_CAP, 100]:
			for a_favor in [true, false]:
				var f: float = GameConfig.wind_factor_for(punto, modo, a_favor)
				if is_equal_approx(f, 1.0):
					sin_efecto.append("%s p%d %s" % [modo, punto, a_favor])
	h.check(
		"ninguna ráfaga se queda en nada", sin_efecto.is_empty(), "sin efecto: %s" % str(sin_efecto)
	)
	# En el extremo de abajo solo cabe a favor, y en el de arriba en contra.
	var m: GameConfig.Difficulty = GameConfig.Difficulty.NORMAL
	h.check(
		"a 0 puntos, pedir viento en contra sopla a favor",
		GameConfig.wind_factor_for(0, m, false) > 1.0,
		"%.3f" % GameConfig.wind_factor_for(0, m, false)
	)
	h.check(
		"y en el tope, pedir a favor sopla en contra",
		GameConfig.wind_factor_for(GameConfig.DIFFICULTY_CAP, m, true) < 1.0,
		"%.3f" % GameConfig.wind_factor_for(GameConfig.DIFFICULTY_CAP, m, true)
	)


## Criterio 2, primera mitad: nunca sopla sin avisar.
func _siempre_avisa_antes_de_soplar() -> void:
	var main: Node = await _partida()
	var wind: Wind = main.wind
	h.check("premisa: el viento está activo", wind.enabled, "")

	var orden: Array = []
	wind.warning_started.connect(func(_a: bool) -> void: orden.append("aviso"))
	wind.gust_started.connect(func(_a: bool) -> void: orden.append("sopla"))
	wind.gust_ended.connect(func() -> void: orden.append("fin"))

	# Se salta la calma —12 s reales harían el test lento— y se cronometra
	# el aviso frame a frame, que es lo que de verdad importa.
	wind.skip_to_next_phase()
	await physics_frame
	h.check("empieza avisando, no soplando", orden == ["aviso"], "%s" % str(orden))
	h.check("y está en fase de aviso", wind.is_warning() and not wind.is_blowing(), "")

	var frames: int = 0
	while not wind.is_blowing() and frames < 600:
		await physics_frame
		frames += 1
	var segundos: float = float(frames) / 60.0
	h.check(
		"el aviso dura lo que dice GameConfig",
		absf(segundos - GameConfig.WIND_WARNING_TIME) < 0.1,
		"%.2f s (esperado %.2f)" % [segundos, GameConfig.WIND_WARNING_TIME]
	)
	# Y ese aviso es tiempo real para reaccionar: caben varios aleteos.
	var aleteos: float = GameConfig.WIND_WARNING_TIME / GameConfig.FLAP_CYCLE
	h.check(
		"y da para más de tres aleteos, no es una encerrona",
		aleteos > 3.0,
		"%.1f aleteos en el aviso" % aleteos
	)
	h.check("el orden es aviso -> sopla", orden == ["aviso", "sopla"], "%s" % str(orden))
	h.check("y el HUD lo enseña", main.hud._wind_label.visible, "")
	main.free()


## Criterio 2, segunda mitad: se deshace solo.
func _el_factor_se_deshace_solo() -> void:
	var main: Node = await _partida()
	var wind: Wind = main.wind
	var normal: float = main.ground.scroll_speed
	h.check("premisa: en calma la velocidad es la de la curva", normal > 0.0, "%.1f" % normal)

	wind.skip_to_next_phase()  # calma -> aviso
	await physics_frame
	h.check(
		"durante el aviso la velocidad NO cambia todavía",
		is_equal_approx(main.ground.scroll_speed, normal),
		"%.1f -> %.1f" % [normal, main.ground.scroll_speed]
	)

	wind.skip_to_next_phase()  # aviso -> soplando
	await physics_frame
	var soplando: float = main.ground.scroll_speed
	h.check(
		"al soplar la velocidad del mundo cambia de verdad",
		not is_equal_approx(soplando, normal),
		"%.1f -> %.1f" % [normal, soplando]
	)
	# Y le llega a TODO el mundo, no solo al suelo.
	h.check(
		"y le llega también al spawner y al fondo",
		(
			is_equal_approx(main.pipe_spawner.scroll_speed, soplando)
			and is_equal_approx(main.background.scroll_speed, soplando)
		),
		"spawner %.1f, fondo %.1f" % [main.pipe_spawner.scroll_speed, main.background.scroll_speed]
	)

	wind.skip_to_next_phase()  # soplando -> calma
	await physics_frame
	h.check(
		"y al acabar vuelve sola a la de la curva, sin limpiar nada",
		is_equal_approx(main.ground.scroll_speed, normal),
		"%.1f (esperado %.1f)" % [main.ground.scroll_speed, normal]
	)
	h.check("y el cartel desaparece", not main.hud._wind_label.visible, "")
	main.free()


## Fuera de PLAYING no hay viento, ni siquiera contando el tiempo.
func _fuera_de_partida_no_hay_viento() -> void:
	var main: Node = await _partida()
	var wind: Wind = main.wind
	wind.skip_to_next_phase()
	await physics_frame
	h.check("premisa: estaba avisando", wind.is_warning(), "")

	main.change_state(GameState.State.GAME_OVER)
	await h.ticks(2)
	h.check("morir apaga el viento", not wind.enabled, "")
	h.check("y lo devuelve a la calma", not wind.is_warning() and not wind.is_blowing(), "")
	h.check(
		"la velocidad ya no lleva viento",
		is_equal_approx(main._wind_factor(), 1.0),
		"%.3f" % main._wind_factor()
	)
	main.free()


## Una partida ya por encima de WIND_MIN_SCORE, con Flapo aislado.
func _partida() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.fruit_spawner.chance = 0.0
	main.wind.random_seed = 9
	h.jugar(main)
	# Después de arrancar: entrar en READY le devuelve la máscara a Flapo.
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	for punto in GameConfig.WIND_MIN_SCORE:
		main._on_scored()
	await h.ticks(2)
	return main
