extends SceneTree
## T-044 — Transiciones entre estados.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-044 · Transiciones ---")
	await _fundido_al_empezar()
	await _retardo_antes_del_panel()
	await _ninguna_transicion_bloquea_la_entrada()
	await _las_transiciones_no_sobreviven_al_reinicio()
	quit(h.resumen("T-044"))


func _partida() -> Node:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 21
	main.bird.gravity = 0.0
	return main


func _idle(n: int) -> void:
	for i in n:
		await process_frame


func _fundido_al_empezar() -> void:
	var main: Node = await _partida()
	h.check(
		"en READY no hay velo", is_zero_approx(main.fade.alpha()), "alfa %.3f" % main.fade.alpha()
	)
	main.change_state(GameState.State.PLAYING)
	h.check("al empezar aparece el velo", main.fade.alpha() > 0.0, "alfa %.3f" % main.fade.alpha())
	var frames: int = 0
	for i in 120:
		await process_frame
		frames += 1
		if is_zero_approx(main.fade.alpha()):
			break
	h.check(
		"y se disuelve solo",
		is_zero_approx(main.fade.alpha()),
		"desaparece en %d frames (~%.2f s)" % [frames, frames / 60.0]
	)
	main.free()


## GDD: 0,5 s de retardo antes del panel.
func _retardo_antes_del_panel() -> void:
	var main: Node = await _partida()
	main.change_state(GameState.State.PLAYING)
	main.bird.gravity = 1200.0
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	h.check("justo al morir el panel no está", not main.game_over_panel.visible, "")
	var frames: int = 0
	for i in 180:
		await process_frame
		frames += 1
		if main.game_over_panel.visible:
			break
	var segundos: float = frames / 60.0
	h.check(
		"el panel aparece tras el retardo del GDD",
		main.game_over_panel.visible and absf(segundos - main.game_over_panel.delay) < 0.25,
		"aparece a los %.2f s (configurado %.2f s)" % [segundos, main.game_over_panel.delay]
	)
	main.free()


## Criterio: ninguna transición bloquea la entrada más de 1 s.
##
## Se mide en frames desde la muerte hasta que el panel está visible y opaco,
## que es cuando el jugador puede volver a actuar.
func _ninguna_transicion_bloquea_la_entrada() -> void:
	var main: Node = await _partida()
	main.change_state(GameState.State.PLAYING)
	main.bird.gravity = 1200.0
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	var frames: int = 0
	for i in 300:
		await process_frame
		frames += 1
		if main.game_over_panel.is_ready_for_input():
			break
	var segundos: float = frames / 60.0
	h.check(
		"morir -> poder reintentar en menos de 1 s",
		main.game_over_panel.is_ready_for_input() and segundos < 1.0,
		(
			"%.2f s (retardo %.2f + fundido %.2f)"
			% [segundos, main.game_over_panel.delay, main.game_over_panel.fade_time]
		)
	)

	# Y la acción `restart` funciona aunque el panel aún esté entrando: el
	# fundido es decorado, no una puerta cerrada.
	main.restart()
	await h.ticks(1)
	main.change_state(GameState.State.PLAYING)
	main.bird.gravity = 1200.0
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	main.restart()
	h.check(
		"restart funciona durante el retardo del panel",
		main.get_state() == GameState.State.READY,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	main.free()


## Un fundido o un retardo a medias no debe sobrevivir a un reinicio.
func _las_transiciones_no_sobreviven_al_reinicio() -> void:
	var main: Node = await _partida()
	for vuelta in 5:
		main.change_state(GameState.State.PLAYING)
		main.bird.gravity = 1200.0
		for tick in 600:
			await physics_frame
			if main.get_state() == GameState.State.GAME_OVER:
				break
		# Se reinicia a mitad del retardo, sin esperar al panel.
		await _idle(5)
		main.restart()
		await h.ticks(1)
		main.bird.gravity = 0.0
	h.check(
		"tras 5 reinicios a destiempo el panel está oculto", not main.game_over_panel.visible, ""
	)
	h.check("y sin velo pegado", is_zero_approx(main.fade.alpha()), "alfa %.3f" % main.fade.alpha())
	h.check(
		"y en READY",
		main.get_state() == GameState.State.READY,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	main.free()
