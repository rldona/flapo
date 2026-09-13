extends SceneTree
## T-201 — Jadeo visible: el aliento se ve en Flapo.
##
## Los dos criterios que headless sí puede juzgar:
##
## 1. **La hitbox no cambia con ningún estado de jadeo.** Es el que importa:
##    si teñir o sudar movieran el radio, el jugador moriría en un sitio
##    donde ve aire.
## 2. **El estado visual es función pura del aliento**, sin estado propio. La
##    consecuencia comprobable es que al volver el aliento al máximo el jadeo
##    se apaga solo, sin que nadie lo reinicie.

const MAIN := "res://scenes/Main.tscn"
const BIRD := "res://scenes/Bird.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-201 · Jadeo visible ---")
	_los_umbrales_estan_en_gameconfig_y_son_puros()
	_el_rubor_sube_de_forma_continua()
	await _el_jadeo_se_ve_en_el_cuerpo_en_los_umbrales()
	await _la_hitbox_no_cambia_con_ningun_estado()
	await _reiniciar_apaga_el_jadeo_sin_reiniciarlo()
	SaveManager.clear()
	quit(h.resumen("T-201"))


## Criterio: umbrales en GameConfig, y el estado es una función pura.
func _los_umbrales_estan_en_gameconfig_y_son_puros() -> void:
	var maximo: float = GameConfig.MAX_BREATH
	var umbral: float = GameConfig.BREATH_LOW_RATIO * maximo
	h.check(
		"con el aliento lleno no jadea",
		GameConfig.pant_level(maximo, maximo) == GameConfig.Pant.NINGUNO,
		"%d" % GameConfig.pant_level(maximo, maximo)
	)
	h.check(
		"justo en el umbral todavía no jadea",
		GameConfig.pant_level(umbral, maximo) == GameConfig.Pant.NINGUNO,
		"%.1f de %.1f -> %d" % [umbral, maximo, GameConfig.pant_level(umbral, maximo)]
	)
	h.check(
		"justo por debajo, sí",
		GameConfig.pant_level(umbral - 0.1, maximo) == GameConfig.Pant.JADEO,
		"%d" % GameConfig.pant_level(umbral - 0.1, maximo)
	)
	h.check(
		"y a cero está agotado",
		GameConfig.pant_level(0.0, maximo) == GameConfig.Pant.AGOTADO,
		"%d" % GameConfig.pant_level(0.0, maximo)
	)
	# El umbral es una FRACCIÓN, así que sigue valiendo con el aliento
	# ampliado por la confianza de T-074.
	var ampliado: float = GameConfig.max_breath_for(GameConfig.CONFIDENCE_MAX_LEVEL)
	h.check(
		"y el umbral escala con el aliento ampliado de T-074",
		(
			GameConfig.pant_level(umbral, ampliado) == GameConfig.Pant.JADEO
			and (
				GameConfig.pant_level(GameConfig.BREATH_LOW_RATIO * ampliado + 1.0, ampliado)
				== GameConfig.Pant.NINGUNO
			)
		),
		"máximo ampliado: %.1f" % ampliado
	)
	# Máximo 0 no puede reventar ni dejar a Flapo permanentemente rojo.
	h.check(
		"un máximo de 0 no rompe nada",
		GameConfig.pant_level(0.0, 0.0) == GameConfig.Pant.NINGUNO,
		"%d" % GameConfig.pant_level(0.0, 0.0)
	)


## El rubor es continuo: se ve venir el agotamiento, no aparece de golpe.
func _el_rubor_sube_de_forma_continua() -> void:
	var maximo: float = GameConfig.MAX_BREATH
	h.check(
		"con aliento de sobra no hay rubor",
		is_zero_approx(GameConfig.pant_tint_weight(maximo, maximo)),
		"%.3f" % GameConfig.pant_tint_weight(maximo, maximo)
	)
	var anterior: float = -1.0
	var creciente: bool = true
	for paso in 31:
		var aliento: float = maximo * (1.0 - float(paso) / 30.0)
		var peso: float = GameConfig.pant_tint_weight(aliento, maximo)
		if peso < anterior - 0.0001:
			creciente = false
		anterior = peso
	h.check("y sube según baja el aliento, sin saltos hacia atrás", creciente, "")
	# "No baja nunca" lo cumple también un valor constante, así que hay que
	# exigir que HAYA rampa: a media caída, el rubor tiene que estar a medias.
	# Sin este aserto, poner el tinte al tope de golpe pasaba el test.
	var medio: float = GameConfig.pant_tint_weight(
		maximo * GameConfig.BREATH_LOW_RATIO * 0.5, maximo
	)
	h.check(
		"y es una rampa de verdad, no un interruptor",
		medio > 0.001 and medio < GameConfig.PANT_TINT_MAX - 0.001,
		"a media caída el rubor es %.3f de %.3f" % [medio, GameConfig.PANT_TINT_MAX]
	)
	h.check(
		"a cero llega al tope declarado, sin pasarse",
		is_equal_approx(GameConfig.pant_tint_weight(0.0, maximo), GameConfig.PANT_TINT_MAX),
		"%.3f" % GameConfig.pant_tint_weight(0.0, maximo)
	)
	# Y ese tope deja a Flapo reconocible: teñirlo del todo lo borraría.
	h.check(
		"y el tope no borra a Flapo",
		GameConfig.PANT_TINT_MAX < 1.0,
		"%.2f" % GameConfig.PANT_TINT_MAX
	)


## Criterio: se activa y se desactiva en los umbrales, en un Flapo de verdad.
func _el_jadeo_se_ve_en_el_cuerpo_en_los_umbrales() -> void:
	var bird: Bird = load(BIRD).instantiate()
	root.add_child(bird)
	await process_frame
	bird._state = GameState.State.PLAYING

	# Lleno: nada.
	bird.recover_breath(bird.max_breath)
	await physics_frame
	h.check("con el aliento lleno no jadea", bird.pant_level() == GameConfig.Pant.NINGUNO, "")
	h.check("no suda", not bird._sweat.emitting, "")
	h.check(
		"y se dibuja sin teñir",
		bird._sprite.modulate.is_equal_approx(Color.WHITE),
		"%s" % bird._sprite.modulate
	)

	# Justo por debajo del umbral: jadeo.
	bird.recover_breath(-bird.max_breath * (1.0 - GameConfig.BREATH_LOW_RATIO) - 1.0)
	await physics_frame
	h.check("por debajo del umbral jadea", bird.pant_level() == GameConfig.Pant.JADEO, "")
	h.check("y suda", bird._sweat.emitting, "")
	h.check("pero todavía no echa vaho", not bird._puff.emitting, "")
	h.check(
		"y se tiñe",
		not bird._sprite.modulate.is_equal_approx(Color.WHITE),
		"%s" % bird._sprite.modulate
	)
	# Las alas tiemblan: el aleteo va más rápido que en reposo.
	var fps_jadeando: float = bird._sprite.speed_scale
	h.check(
		"y las alas van más rápido que respirando bien",
		fps_jadeando > bird.flap_fps_idle / 10.0,
		"%.2f frente a %.2f" % [fps_jadeando, bird.flap_fps_idle / 10.0]
	)

	# A cero: vaho.
	bird.recover_breath(-bird.max_breath)
	await physics_frame
	h.check("a cero está agotado", bird.pant_level() == GameConfig.Pant.AGOTADO, "")
	h.check("y echa vaho", bird._puff.emitting, "")

	# Y al recuperar, se apaga todo.
	bird.recover_breath(bird.max_breath)
	await physics_frame
	h.check("al recuperar deja de jadear", bird.pant_level() == GameConfig.Pant.NINGUNO, "")
	h.check("y se apagan sudor y vaho", not bird._sweat.emitting and not bird._puff.emitting, "")
	bird.free()


## Criterio: la hitbox no cambia con ningún estado de jadeo.
func _la_hitbox_no_cambia_con_ningun_estado() -> void:
	var bird: Bird = load(BIRD).instantiate()
	root.add_child(bird)
	await process_frame
	bird._state = GameState.State.PLAYING
	var forma: CollisionShape2D = bird.get_node("CollisionShape2D")
	var radio: float = (forma.shape as CircleShape2D).radius
	var sitio: Vector2 = forma.position

	var niveles: Array = []
	for fraccion in [1.0, 0.5, 0.29, 0.1, 0.0]:
		bird.recover_breath(bird.max_breath)
		bird.recover_breath(-bird.max_breath * (1.0 - fraccion))
		await physics_frame
		niveles.append(bird.pant_level())
		h.check(
			"a %.0f%% de aliento el radio no cambia" % (fraccion * 100.0),
			(
				is_equal_approx((forma.shape as CircleShape2D).radius, radio)
				and forma.position.is_equal_approx(sitio)
			),
			"radio %.3f, posición %s" % [(forma.shape as CircleShape2D).radius, forma.position]
		)
	# Premisa: entre esas fracciones se han visto los tres estados. Sin esto,
	# el bucle podría estar comprobando cinco veces el mismo caso.
	h.check(
		"premisa: se han recorrido los tres estados de jadeo",
		(
			niveles.has(GameConfig.Pant.NINGUNO)
			and niveles.has(GameConfig.Pant.JADEO)
			and niveles.has(GameConfig.Pant.AGOTADO)
		),
		"%s" % str(niveles)
	)
	bird.free()


## Criterio: no queda activo tras reiniciar. Y la gracia es que nadie lo
## reinicia: el aliento vuelve al máximo y el jadeo se apaga solo.
func _reiniciar_apaga_el_jadeo_sin_reiniciarlo() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.fruit_spawner.chance = 0.0
	# Sin tuberías: cruzar un hueco por el centro recupera +25 de aliento
	# (T-048) y sacaría a Flapo del agotamiento a mitad de la comprobación.
	main.pipe_spawner.set_physics_process(false)
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0

	main.bird.recover_breath(-main.bird.max_breath)
	# Dos frames: el primero puede pillar a Flapo ya procesado.
	await h.ticks(2)
	h.check(
		"premisa: Flapo llega agotado al final de la partida",
		main.bird.pant_level() == GameConfig.Pant.AGOTADO,
		""
	)
	h.check("premisa: y se le nota", main.bird._puff.emitting, "")

	main.change_state(GameState.State.GAME_OVER)
	await h.ticks(2)
	h.check(
		"muerto no jadea: el batacazo es lo que hay que mirar",
		not main.bird._sweat.emitting and not main.bird._puff.emitting,
		""
	)

	main.restart()
	await h.ticks(2)
	h.check(
		"y en la partida nueva no queda ni rastro",
		main.bird.pant_level() == GameConfig.Pant.NINGUNO,
		"%d" % main.bird.pant_level()
	)
	h.check(
		"ni sudor ni vaho ni tinte",
		(
			not main.bird._sweat.emitting
			and not main.bird._puff.emitting
			and main.bird._sprite.modulate.is_equal_approx(Color.WHITE)
		),
		"modulate %s" % main.bird._sprite.modulate
	)
	main.free()
