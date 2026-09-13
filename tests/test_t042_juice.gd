extends SceneTree
## T-042 — Feedback de muerte: flash, sacudida, hit-stop y rebote.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-042 · Feedback de muerte ---")
	await _intensidades_exportadas()
	await _al_morir_hay_flash_sacudida_y_rebote()
	await _el_hit_stop_siempre_devuelve_el_reloj()
	await _liberar_a_media_congelacion_no_deja_el_juego_parado()
	await _no_rompe_el_reinicio()
	quit(h.resumen("T-042"))


func _partida() -> Node:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 9
	return main


func _morir(main: Node) -> void:
	h.jugar(main)
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			return


## Criterio: intensidades como @export en un nodo Juice.
func _intensidades_exportadas() -> void:
	var main: Node = await _partida()
	var exportadas: Array[String] = []
	for prop in main.juice.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_EDITOR:
			exportadas.append(prop.name)
	for nombre in [
		"flash_alpha",
		"flash_time",
		"shake_strength",
		"shake_time",
		"shake_frequency",
		"hit_stop_time"
	]:
		h.check("`%s` es @export en Juice" % nombre, exportadas.has(nombre), "")
	main.free()


func _al_morir_hay_flash_sacudida_y_rebote() -> void:
	var main: Node = await _partida()
	var flash: ColorRect = main.get_node("FlashLayer/Flash")
	var camara: Camera2D = main.get_node("Camera2D")
	h.check("antes de morir no hay flash", is_zero_approx(flash.color.a), "")
	h.check("antes de morir la cámara está centrada", camara.offset.is_zero_approx(), "")

	h.jugar(main)
	var subio: bool = false
	var y_previa: float = main.bird.position.y
	var flash_max: float = 0.0
	var shake_max: float = 0.0
	for tick in 600:
		await physics_frame
		flash_max = maxf(flash_max, flash.color.a)
		shake_max = maxf(shake_max, camara.offset.length())
		if main.get_state() == GameState.State.GAME_OVER:
			# Rebote: tras el golpe Flapo tiene que subir algo.
			if main.bird.position.y < y_previa:
				subio = true
			y_previa = main.bird.position.y

	h.check("al morir hay flash blanco", flash_max > 0.1, "alfa máximo: %.2f" % flash_max)
	h.check("al morir la cámara se sacude", shake_max > 1.0, "offset máximo: %.2f px" % shake_max)
	h.check("al morir Flapo rebota hacia arriba", subio, "")
	h.check(
		"y el flash se apaga solo",
		is_zero_approx(flash.color.a),
		"alfa final: %.3f" % flash.color.a
	)
	h.check(
		"y la cámara vuelve al centro",
		camara.offset.is_zero_approx(),
		"offset final: %s" % camara.offset
	)
	main.free()


## El hit-stop congela y descongela. Que se quede congelado es el peor bug
## posible: el juego no vuelve y no hay nada que el jugador pueda hacer.
func _el_hit_stop_siempre_devuelve_el_reloj() -> void:
	var main: Node = await _partida()
	h.jugar(main)
	var congelo: bool = false
	for tick in 600:
		await process_frame
		if is_zero_approx(Engine.time_scale):
			congelo = true
		if main.get_state() == GameState.State.GAME_OVER and congelo:
			break
	h.check("el golpe congela el tiempo", congelo, "")
	for i in 30:
		await process_frame
	h.check(
		"y el reloj vuelve a 1.0",
		is_equal_approx(Engine.time_scale, 1.0),
		"time_scale = %.3f" % Engine.time_scale
	)
	main.free()


## Regresión: liberar la escena a media congelación dejaba `time_scale` en 0
## para todo el motor, y el juego no volvía nunca.
func _liberar_a_media_congelacion_no_deja_el_juego_parado() -> void:
	var main: Node = await _partida()
	h.jugar(main)
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	# Se libera inmediatamente después del golpe, en plena congelación.
	var congelado_al_liberar: bool = is_zero_approx(Engine.time_scale)
	main.free()
	await process_frame
	h.check(
		"liberar a media congelación devuelve el reloj",
		is_equal_approx(Engine.time_scale, 1.0),
		(
			"estaba congelado al liberar: %s, time_scale ahora %.3f"
			% [congelado_al_liberar, Engine.time_scale]
		)
	)


## Criterio: no rompe el reinicio.
func _no_rompe_el_reinicio() -> void:
	var main: Node = await _partida()
	var flash: ColorRect = main.get_node("FlashLayer/Flash")
	var camara: Camera2D = main.get_node("Camera2D")
	for vuelta in 10:
		await _morir(main)
		main.restart()
		await h.ticks(2)
		if not is_equal_approx(Engine.time_scale, 1.0):
			break
	h.check(
		"10 muertes y reinicios seguidos dejan el reloj a 1.0",
		is_equal_approx(Engine.time_scale, 1.0),
		"time_scale = %.3f" % Engine.time_scale
	)
	h.check("y sin flash pegado", is_zero_approx(flash.color.a), "alfa: %.3f" % flash.color.a)
	h.check("y la cámara centrada", camara.offset.is_zero_approx(), "offset: %s" % camara.offset)
	h.check(
		"y en READY",
		main.get_state() == GameState.State.READY,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	main.free()
