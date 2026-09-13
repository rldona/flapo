extends SceneTree
## T-025 — PipeSpawner.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-025 · PipeSpawner ---")
	await _intervalo_desde_gameconfig()
	await _no_crea_en_ready()
	await _crea_en_playing_con_la_separacion_del_gdd()
	await _para_y_congela_en_game_over()
	await _limpia_al_reiniciar()
	quit(h.resumen("T-025"))


func _partida() -> Node:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 4242
	# Sin suelo (T-027) Flapo cae y muere en ~1 s, y eso para el spawner
	# —correctamente—. Aquí se prueba el spawner, no la muerte: se le quita
	# la gravedad para que la partida dure lo que dure el test.
	main.bird.gravity = 0.0
	return main


## Criterio: intervalo y velocidad centralizados en GameConfig.
func _intervalo_desde_gameconfig() -> void:
	var main: Node = await _partida()
	var timer: Timer = main.pipe_spawner.get_node("Timer")
	h.check(
		"el intervalo sale de GameConfig",
		is_equal_approx(timer.wait_time, GameConfig.pipe_spawn_interval()),
		(
			"wait_time %.3f s = %.0f px / %.0f px/s"
			% [timer.wait_time, GameConfig.PIPE_SPACING, GameConfig.SCROLL_SPEED]
		)
	)
	main.free()


## En READY no debe aparecer nada: el mundo está esperando al jugador.
func _no_crea_en_ready() -> void:
	var main: Node = await _partida()
	await h.ticks(300)
	h.check(
		"en READY no crea tuberías",
		main.pipe_spawner.pipe_count() == 0,
		"tuberías: %d tras 5 s" % main.pipe_spawner.pipe_count()
	)
	main.free()


## La primera sale ya, y la separación real debe ser la del GDD.
func _crea_en_playing_con_la_separacion_del_gdd() -> void:
	var main: Node = await _partida()
	var spawner: Node = main.pipe_spawner
	main.change_state(GameState.State.PLAYING)
	h.check(
		"la primera tubería sale al empezar",
		spawner.pipe_count() == 1,
		"tuberías: %d" % spawner.pipe_count()
	)
	# Se espera a la segunda y se mide en qué tick llega, en vez de fijar un
	# número exacto: el timer termina en un tick u otro según el redondeo del
	# delta, y un test que dependa de eso es frágil sin motivo.
	var esperado: int = int(round(GameConfig.pipe_spawn_interval() * 60.0))
	var tick_segunda: int = -1
	for tick in esperado * 2:
		await physics_frame
		if spawner.pipe_count() == 2:
			tick_segunda = tick + 1
			break
	h.check(
		"crea una por intervalo",
		tick_segunda > 0 and absi(tick_segunda - esperado) <= 2,
		"segunda tubería en el tick %d (esperado ~%d)" % [tick_segunda, esperado]
	)
	var vivas: Array[Node] = []
	for hijo in spawner.get_children():
		if hijo is Pipe:
			vivas.append(hijo)
	if vivas.size() == 2:
		var separacion: float = absf(vivas[0].position.x - vivas[1].position.x)
		h.check(
			"la separación real es la del GDD",
			absf(separacion - GameConfig.PIPE_SPACING) <= 2.0,
			"%.1f px (GDD: %.1f px)" % [separacion, GameConfig.PIPE_SPACING]
		)
	main.free()


## Criterio: se detiene en GAME_OVER. Y las que ya están tampoco se mueven:
## un mundo que sigue corriendo detrás del panel de muerte se nota.
func _para_y_congela_en_game_over() -> void:
	var main: Node = await _partida()
	var spawner: Node = main.pipe_spawner
	main.change_state(GameState.State.PLAYING)
	await h.ticks(120)
	var antes: int = spawner.pipe_count()
	var x_antes: Array[float] = []
	for hijo in spawner.get_children():
		if hijo is Pipe:
			x_antes.append(hijo.position.x)

	main.change_state(GameState.State.GAME_OVER)
	await h.ticks(300)

	h.check(
		"en GAME_OVER no crea más",
		spawner.pipe_count() == antes,
		"%d antes, %d después de 5 s" % [antes, spawner.pipe_count()]
	)
	var quietas: bool = true
	var i: int = 0
	for hijo in spawner.get_children():
		if hijo is Pipe:
			quietas = quietas and is_equal_approx(hijo.position.x, x_antes[i])
			i += 1
	h.check("en GAME_OVER las tuberías se paran", quietas, "%d tuberías comparadas" % i)
	main.free()


## Criterio de T-028 adelantado: reiniciar no debe dejar tuberías de la
## partida anterior flotando en la pantalla de READY.
func _limpia_al_reiniciar() -> void:
	var main: Node = await _partida()
	var spawner: Node = main.pipe_spawner
	main.change_state(GameState.State.PLAYING)
	await h.ticks(200)
	main.change_state(GameState.State.GAME_OVER)
	var habia: int = spawner.pipe_count()
	main.change_state(GameState.State.READY)
	await h.ticks(2)
	h.check(
		"reiniciar limpia las tuberías",
		spawner.pipe_count() == 0,
		"había %d, quedan %d" % [habia, spawner.pipe_count()]
	)
	main.free()
