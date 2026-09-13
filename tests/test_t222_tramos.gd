extends SceneTree
## T-222 — Tramos del viaje.
##
## El paisaje cuenta lo lejos que has llegado. Lo que hay que proteger:
##
## - Los **umbrales** son función pura de la puntuación, así que reiniciar
##   vuelve al parque sin código de reinicio.
## - El cambio es un **fundido**, no un corte. Un corte se lee como un fallo
##   de dibujo, no como avanzar.
## - **No deja capas huérfanas.** Aquí eso no se comprueba limpiando bien: las
##   cuatro capas existen desde el primer frame y el cambio es mover alfas, así
##   que no hay nada que pueda quedarse huérfano. El test lo verifica contando
##   nodos antes y después de recorrer el viaje entero.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-222 · Tramos del viaje ---")
	_los_umbrales_son_funcion_pura()
	await _el_paisaje_cambia_al_avanzar()
	await _el_cambio_es_un_fundido_no_un_corte()
	await _no_deja_capas_huerfanas()
	await _reiniciar_vuelve_al_parque()
	await _el_nido_cae_en_el_ultimo_tramo()
	SaveManager.clear()
	quit(h.resumen("T-222"))


## Criterio: el tramo es función pura de la puntuación.
func _los_umbrales_son_funcion_pura() -> void:
	var paso: int = GameConfig.JOURNEY_STAGE_SCORE
	h.check(
		"premisa: hay cuatro tramos", GameConfig.Stage.size() == 4, "%d" % GameConfig.Stage.size()
	)
	h.check("a 0 puntos, el parque", GameConfig.journey_stage(0) == GameConfig.Stage.PARQUE, "")
	h.check(
		"justo antes del primer umbral, todavía el parque",
		GameConfig.journey_stage(paso - 1) == GameConfig.Stage.PARQUE,
		"%d puntos" % (paso - 1)
	)
	h.check(
		"en el primer umbral, los tejados",
		GameConfig.journey_stage(paso) == GameConfig.Stage.TEJADOS,
		"%d puntos" % paso
	)
	h.check(
		"y los cuatro tramos salen en orden",
		(
			GameConfig.journey_stage(paso * 2) == GameConfig.Stage.NUBES
			and GameConfig.journey_stage(paso * 3) == GameConfig.Stage.CIELO
		),
		""
	)
	h.check(
		"pasado el último, se queda en el cielo y no se sale de la tabla",
		GameConfig.journey_stage(paso * 99) == GameConfig.Stage.CIELO,
		"%d" % GameConfig.journey_stage(paso * 99)
	)
	h.check(
		"y una puntuación negativa no revienta",
		GameConfig.journey_stage(-5) == GameConfig.Stage.PARQUE,
		""
	)


## Que la decisión llegue al fondo, no solo a una función pura.
func _el_paisaje_cambia_al_avanzar() -> void:
	var main: Node = await _volando()
	h.check(
		"se empieza en el parque",
		main.background.stage() == GameConfig.Stage.PARQUE,
		"%s" % GameConfig.stage_name(main.background.stage())
	)
	var vistos: Array = [main.background.stage()]
	for i in GameConfig.JOURNEY_STAGE_SCORE * 3:
		main._on_scored()
		if main.background.stage() != vistos[-1]:
			vistos.append(main.background.stage())
	h.check(
		"recorriendo el viaje se pasa por los cuatro paisajes, en orden",
		(
			vistos
			== [
				GameConfig.Stage.PARQUE,
				GameConfig.Stage.TEJADOS,
				GameConfig.Stage.NUBES,
				GameConfig.Stage.CIELO
			]
		),
		"%s" % str(vistos)
	)
	main.free()


## Criterio: con fundido, no de golpe.
func _el_cambio_es_un_fundido_no_un_corte() -> void:
	var main: Node = await _volando()
	for i in GameConfig.JOURNEY_STAGE_SCORE:
		main._on_scored()
	h.check(
		"premisa: se ha cambiado de tramo", main.background.stage() == GameConfig.Stage.TEJADOS, ""
	)
	h.check(
		"el fundido empieza en 0",
		is_zero_approx(main.background.mezcla()),
		"%.3f" % main.background.mezcla()
	)

	# A mitad de camino las dos capas comparten pantalla: eso es el fundido.
	await h.ticks(int(GameConfig.JOURNEY_FADE_TIME * 30.0))
	var saliendo: float = main.background.stage_alpha(int(GameConfig.Stage.PARQUE))
	var entrando: float = main.background.stage_alpha(int(GameConfig.Stage.TEJADOS))
	h.check(
		"a mitad del fundido se ven las dos capas a la vez",
		saliendo > 0.1 and saliendo < 0.9 and entrando > 0.1 and entrando < 0.9,
		"parque %.2f, tejados %.2f" % [saliendo, entrando]
	)
	h.check(
		"y entre las dos suman una capa entera: ni se oscurece ni se aclara",
		absf(saliendo + entrando - 1.0) < 0.01,
		"%.3f" % (saliendo + entrando)
	)

	await h.ticks(int(GameConfig.JOURNEY_FADE_TIME * 60.0))
	h.check(
		"al acabar, el tramo nuevo está entero",
		is_equal_approx(main.background.stage_alpha(int(GameConfig.Stage.TEJADOS)), 1.0),
		"%.3f" % main.background.stage_alpha(int(GameConfig.Stage.TEJADOS))
	)
	h.check(
		"y el viejo ha desaparecido",
		is_zero_approx(main.background.stage_alpha(int(GameConfig.Stage.PARQUE))),
		"%.3f" % main.background.stage_alpha(int(GameConfig.Stage.PARQUE))
	)
	main.free()


## Criterio: la transición no deja capas huérfanas.
func _no_deja_capas_huerfanas() -> void:
	var main: Node = await _volando()
	var antes: int = _nodos(main.background)
	h.check("premisa: el fondo tiene capas", antes > 4, "%d nodos" % antes)
	# El viaje entero, ida y vuelta, con fundidos a medias.
	for vuelta in 3:
		for i in GameConfig.JOURNEY_STAGE_SCORE * 3 + 5:
			main._on_scored()
			if i % 7 == 0:
				await physics_frame
		main.change_state(GameState.State.GAME_OVER)
		main.restart()
		await h.ticks(3)
	var despues: int = _nodos(main.background)
	h.check(
		"tras tres viajes enteros el fondo tiene exactamente los mismos nodos",
		despues == antes,
		"%d antes, %d después" % [antes, despues]
	)
	h.check("y no hay huérfanos", main.background.get_parent() != null, "")
	main.free()


## Criterio: reiniciar vuelve al parque.
func _reiniciar_vuelve_al_parque() -> void:
	var main: Node = await _volando()
	for i in GameConfig.JOURNEY_STAGE_SCORE * 3:
		main._on_scored()
	h.check(
		"premisa: se ha llegado al cielo", main.background.stage() == GameConfig.Stage.CIELO, ""
	)
	main.change_state(GameState.State.GAME_OVER)
	main.restart()
	# Un frame antes de mirar las alfas: se reparten en `_process`, así que
	# leerlas en el mismo frame del reinicio devuelve las de antes. Sin esta
	# espera el test daba por bueno un reinicio que no reiniciaba nada.
	await h.ticks(1)
	h.check(
		"al reiniciar se vuelve al parque",
		main.background.stage() == GameConfig.Stage.PARQUE,
		"%s" % GameConfig.stage_name(main.background.stage())
	)
	h.check(
		"y sin fundido: no se ha viajado todavía",
		is_equal_approx(main.background.stage_alpha(int(GameConfig.Stage.PARQUE)), 1.0),
		"%.3f" % main.background.stage_alpha(int(GameConfig.Stage.PARQUE))
	)
	h.check(
		"y las demás capas están apagadas",
		(
			is_zero_approx(main.background.stage_alpha(1))
			and is_zero_approx(main.background.stage_alpha(2))
			and is_zero_approx(main.background.stage_alpha(3))
		),
		(
			"%.2f %.2f %.2f"
			% [
				main.background.stage_alpha(1),
				main.background.stage_alpha(2),
				main.background.stage_alpha(3)
			]
		)
	)
	main.free()


## El paisaje tiene que anunciar el final antes de que llegue, no cambiar
## justo encima: el nido (T-209) cae dentro del último tramo.
func _el_nido_cae_en_el_ultimo_tramo() -> void:
	h.check(
		"el nido cae en el cielo abierto, no en el cambio de tramo",
		GameConfig.journey_stage(GameConfig.JOURNEY_END_SCORE) == GameConfig.Stage.CIELO,
		(
			"tramo %s a %d puntos"
			% [
				GameConfig.stage_name(GameConfig.journey_stage(GameConfig.JOURNEY_END_SCORE)),
				GameConfig.JOURNEY_END_SCORE
			]
		)
	)
	var ultimo_umbral: int = GameConfig.JOURNEY_STAGE_SCORE * 3
	h.check(
		"y con margen: el cielo llega bastante antes que el nido",
		GameConfig.JOURNEY_END_SCORE - ultimo_umbral >= 5,
		"cielo en %d, nido en %d" % [ultimo_umbral, GameConfig.JOURNEY_END_SCORE]
	)


func _nodos(nodo: Node) -> int:
	var n: int = 1
	for hijo in nodo.get_children():
		n += _nodos(hijo)
	return n


func _volando() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	await h.ticks(2)
	return main
