extends SceneTree
## T-028 — Muerte, Game Over y reinicio.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-028 · Reinicio ---")
	await _el_panel_aparece_solo_al_morir()
	await _la_accion_restart_reinicia()
	await _reiniciar_deja_el_mundo_como_al_principio()
	await _cincuenta_reinicios_sin_acumular()
	quit(h.resumen("T-028"))


func _partida() -> Node:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 1234
	return main


## Cuenta todos los nodos colgando de `nodo`, él incluido.
func _contar_nodos(nodo: Node) -> int:
	var n: int = 1
	for hijo in nodo.get_children():
		n += _contar_nodos(hijo)
	return n


## Cuenta los Timer vivos: el criterio los nombra aparte porque un Timer
## huérfano sigue disparando y es de los bugs más difíciles de ver.
func _contar_timers(nodo: Node) -> int:
	var n: int = 1 if nodo is Timer else 0
	for hijo in nodo.get_children():
		n += _contar_timers(hijo)
	return n


func _morir(main: Node) -> void:
	main.change_state(GameState.State.PLAYING)
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			return


func _el_panel_aparece_solo_al_morir() -> void:
	var main: Node = await _partida()
	h.check("en READY el panel está oculto", not main.game_over_panel.visible, "")
	main.change_state(GameState.State.PLAYING)
	h.check("en PLAYING el panel está oculto", not main.game_over_panel.visible, "")
	await _morir(main)
	# El panel tarda 0,5 s a propósito (T-044): da tiempo a ver el batacazo.
	var frames: int = 0
	for i in 120:
		await process_frame
		frames += 1
		if main.game_over_panel.visible:
			break
	h.check(
		"al morir el panel se muestra",
		main.game_over_panel.visible,
		"aparece tras %d frames (~%.2f s)" % [frames, frames / 60.0]
	)
	main.restart()
	h.check("al reiniciar el panel se oculta", not main.game_over_panel.visible, "")
	main.free()


## El panel enseña la puntuación de la partida que se acaba de perder.
func _la_accion_restart_reinicia() -> void:
	var main: Node = await _partida()
	main.change_state(GameState.State.PLAYING)
	main._on_scored()
	main._on_scored()
	await _morir(main)
	var etiqueta: Label = main.game_over_panel.get_node("Root/Box/Score")
	h.check(
		"el panel enseña la puntuación de la partida",
		etiqueta.text == "2",
		"texto del panel: '%s', puntuación %d" % [etiqueta.text, main.get_score()]
	)

	h.pulsa(KEY_R)
	await h.ticks(3)
	h.pulsa(KEY_R, false)
	await h.ticks(1)
	h.check(
		"la acción restart vuelve a READY",
		main.get_state() == GameState.State.READY,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	main.free()


## Reiniciar tiene que dejarlo TODO como al arrancar: sin tuberías de la
## partida anterior, con la puntuación a cero y Flapo en su sitio, quieto,
## sin rotación y vivo.
func _reiniciar_deja_el_mundo_como_al_principio() -> void:
	var main: Node = await _partida()
	var bird: Node = main.bird
	var sitio: Vector2 = bird.position
	main.change_state(GameState.State.PLAYING)
	main._on_scored()
	await _morir(main)
	main.restart()
	await h.ticks(2)

	h.check("reinicio: puntuación a 0", main.get_score() == 0, "%d" % main.get_score())
	h.check(
		"reinicio: sin tuberías",
		main.pipe_spawner.pipe_count() == 0,
		"%d tuberías" % main.pipe_spawner.pipe_count()
	)
	h.check(
		"reinicio: Flapo vuelve a su sitio",
		bird.position.is_equal_approx(sitio),
		"%s (esperado %s)" % [bird.position, sitio]
	)
	h.check(
		"reinicio: Flapo quieto y sin girar",
		bird.velocity.is_zero_approx() and is_zero_approx(bird.rotation),
		"velocity %s, rotación %.4f rad" % [bird.velocity, bird.rotation]
	)
	# Y vuelve a poder morir: si el flag `_dead` no se limpiara, la segunda
	# partida sería inmortal y el juego se quedaría colgado en PLAYING.
	await _morir(main)
	h.check(
		"reinicio: Flapo puede volver a morir",
		main.get_state() == GameState.State.GAME_OVER,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	main.free()


## Criterio: reiniciar 50 veces seguidas no acumula nodos ni timers.
func _cincuenta_reinicios_sin_acumular() -> void:
	var main: Node = await _partida()
	await _morir(main)
	main.restart()
	await h.ticks(2)
	var nodos_base: int = _contar_nodos(main)
	var timers_base: int = _contar_timers(main)
	var huerfanos_base: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)

	for vuelta in 50:
		await _morir(main)
		main.restart()
		await h.ticks(2)

	var nodos: int = _contar_nodos(main)
	var timers: int = _contar_timers(main)
	var huerfanos: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)

	h.check(
		"50 reinicios no acumulan nodos",
		nodos == nodos_base,
		"%d nodos antes, %d después" % [nodos_base, nodos]
	)
	h.check(
		"50 reinicios no acumulan timers",
		timers == timers_base,
		"%d timers antes, %d después" % [timers_base, timers]
	)
	h.check(
		"50 reinicios no dejan huérfanos",
		huerfanos == huerfanos_base,
		"%d huérfanos antes, %d después" % [huerfanos_base, huerfanos]
	)
	h.check(
		"tras 50 reinicios sigue jugable",
		main.get_state() == GameState.State.READY,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	main.free()
