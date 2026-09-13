extends SceneTree
## T-029 — HUD de puntuación.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-029 · HUD ---")
	await _visibilidad_por_estado()
	await _sigue_la_puntuacion()
	await _nunca_coincide_con_el_panel()
	quit(h.resumen("T-029"))


func _partida() -> Node:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 55
	return main


func _morir(main: Node) -> void:
	main.change_state(GameState.State.PLAYING)
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			return


## Criterio: visible en PLAYING, oculto en READY, sustituido por el panel en
## GAME_OVER.
func _visibilidad_por_estado() -> void:
	var main: Node = await _partida()
	h.check("en READY el HUD está oculto", not main.hud.visible, "")
	main.change_state(GameState.State.PLAYING)
	h.check("en PLAYING el HUD se ve", main.hud.visible, "")
	await _morir(main)
	h.check("en GAME_OVER el HUD se oculta", not main.hud.visible, "")
	for i in 120:
		await process_frame
		if main.game_over_panel.visible:
			break
	h.check("en GAME_OVER lo sustituye el panel", main.game_over_panel.visible, "")
	main.restart()
	h.check("tras reiniciar vuelve a estar oculto", not main.hud.visible, "")
	main.free()


## El marcador se actualiza por señal, no preguntando cada frame.
func _sigue_la_puntuacion() -> void:
	var main: Node = await _partida()
	var etiqueta: Label = main.hud.get_node("Score")
	main.change_state(GameState.State.PLAYING)
	for punto in 3:
		main._on_scored()
	await h.ticks(1)
	h.check(
		"el HUD enseña la puntuación",
		etiqueta.text == "3",
		"texto '%s', puntuación %d" % [etiqueta.text, main.get_score()]
	)
	await _morir(main)
	main.restart()
	await h.ticks(1)
	h.check(
		"al reiniciar el marcador vuelve a 0",
		etiqueta.text == "0",
		"texto '%s'" % etiqueta.text
	)
	main.free()


## Los dos nunca se ven a la vez: sería puntuación duplicada en pantalla.
func _nunca_coincide_con_el_panel() -> void:
	var main: Node = await _partida()
	var solapan: int = 0
	main.change_state(GameState.State.PLAYING)
	for tick in 600:
		await physics_frame
		if main.hud.visible and main.game_over_panel.visible:
			solapan += 1
		if main.get_state() == GameState.State.GAME_OVER and tick % 120 == 0:
			main.restart()
			main.change_state(GameState.State.PLAYING)
	h.check(
		"HUD y panel nunca se ven a la vez",
		solapan == 0,
		"frames solapados: %d de 600" % solapan
	)
	main.free()
