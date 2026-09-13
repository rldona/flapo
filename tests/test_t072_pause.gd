extends SceneTree
## T-072 — Pausa y pérdida de foco.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-072 · Pausa ---")
	await _pausar_congela_el_mundo()
	await _volver_del_segundo_plano_no_mata()
	await _solo_se_pausa_jugando()
	await _reiniciar_despausa()
	SaveManager.clear()
	quit(h.resumen("T-072"))


func _partida() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 13
	return main


func _despausar(main: Node) -> void:
	main.set_paused(false)
	root.get_tree().paused = false


## Pausar tiene que parar el mundo entero, no solo dejar de dibujar.
func _pausar_congela_el_mundo() -> void:
	var main: Node = await _partida()
	main.change_state(GameState.State.PLAYING)
	await h.ticks(20)
	main.set_paused(true)
	h.check("al pausar sale el velo", main.pause_panel.visible, "")

	var y: float = main.bird.position.y
	var suelo: float = main.ground.get_node("Tile0").position.x
	var tuberias: int = main.pipe_spawner.pipe_count()
	await h.ticks(120)
	h.check(
		"en pausa Flapo no se mueve",
		is_equal_approx(main.bird.position.y, y),
		"y %.2f -> %.2f tras 2 s" % [y, main.bird.position.y]
	)
	h.check(
		"en pausa el suelo no corre",
		is_equal_approx(main.ground.get_node("Tile0").position.x, suelo),
		"x %.2f -> %.2f" % [suelo, main.ground.get_node("Tile0").position.x]
	)
	h.check(
		"en pausa no nacen tuberías",
		main.pipe_spawner.pipe_count() == tuberias,
		"%d -> %d" % [tuberias, main.pipe_spawner.pipe_count()]
	)

	_despausar(main)
	h.check("al reanudar se quita el velo", not main.pause_panel.visible, "")
	await h.ticks(20)
	h.check(
		"y el mundo vuelve a moverse",
		main.bird.position.y != y,
		"y %.2f tras reanudar" % main.bird.position.y
	)
	main.free()


## Criterio: volver del segundo plano no provoca muerte instantánea.
##
## Es el bug clásico de pausar con un flag propio en vez de con el árbol:
## el motor acumula el tiempo que la app estuvo fuera y lo aplica de golpe.
func _volver_del_segundo_plano_no_mata() -> void:
	var main: Node = await _partida()
	main.change_state(GameState.State.PLAYING)
	await h.ticks(10)
	var y_antes: float = main.bird.position.y

	# Como si Android mandase la app a segundo plano.
	main._notification(main.NOTIFICATION_APPLICATION_PAUSED)
	h.check("perder el foco pausa solo", root.get_tree().paused, "")
	await h.ticks(600)

	_despausar(main)
	await h.ticks(1)
	h.check(
		"volver del segundo plano no mata",
		main.get_state() == GameState.State.PLAYING,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	h.check(
		"y Flapo sigue donde estaba",
		absf(main.bird.position.y - y_antes) < 20.0,
		"y %.2f -> %.2f tras 10 s en segundo plano" % [y_antes, main.bird.position.y]
	)
	main.free()


func _solo_se_pausa_jugando() -> void:
	var main: Node = await _partida()
	main.set_paused(true)
	h.check("en READY no se puede pausar", not root.get_tree().paused, "")

	main.change_state(GameState.State.PLAYING)
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	main.set_paused(true)
	h.check("en GAME_OVER tampoco", not root.get_tree().paused, "")
	main.free()


## `restart()` deja el juego despausado pase lo que pase.
##
## Hoy el escenario no es alcanzable —no se puede pausar en GAME_OVER, que es
## el único estado desde el que se reinicia—, pero la salvaguarda importa: un
## reinicio con el árbol pausado dejaría el juego congelado y sin velo, es
## decir sin ninguna salida para el jugador. Se fuerza la pausa a mano.
func _reiniciar_despausa() -> void:
	var main: Node = await _partida()
	main.change_state(GameState.State.PLAYING)
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	root.get_tree().paused = true
	main.restart()
	h.check("reiniciar despausa siempre", not root.get_tree().paused, "")
	h.check("y quita el velo", not main.pause_panel.visible, "")
	await h.ticks(20)
	h.check(
		"y el juego responde",
		main.get_state() == GameState.State.READY,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	_despausar(main)
	main.free()
