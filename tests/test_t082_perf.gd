extends SceneTree
## T-082 — Perfilado: nodos vivos y coste por frame.
##
## No sustituye al profiler del editor ni a medir en un Android real, pero sí
## atrapa la clase de regresión que nadie ve a ojo: nodos que se acumulan
## partida tras partida, o un frame que se va al doble sin motivo.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-082 · Rendimiento ---")
	await _nodos_estables_en_partida_larga()
	await _coste_por_frame()
	await _sin_huerfanos_tras_muchas_partidas()
	SaveManager.clear()
	Settings.clear()
	quit(h.resumen("T-082"))


func _partida() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 31
	main.bird.gravity = 0.0  # Para que la partida dure lo que dure la medida.
	return main


func _contar(nodo: Node) -> int:
	var n: int = 1
	for hijo in nodo.get_children():
		n += _contar(hijo)
	return n


## Cinco minutos jugando: el número de nodos tiene que quedarse plano.
func _nodos_estables_en_partida_larga() -> void:
	var main: Node = await _partida()
	main.change_state(GameState.State.PLAYING)
	await h.ticks(300)
	var base: int = _contar(main)
	var pico: int = base
	for tramo in 30:
		await h.ticks(600)
		pico = maxi(pico, _contar(main))
	var final: int = _contar(main)
	h.check(
		"5 min de partida no acumulan nodos",
		final <= base + 2,
		"%d nodos a los 5 s, %d a los 5 min, pico %d" % [base, final, pico]
	)
	main.free()


## Cuánto cuesta un frame de física con el mundo lleno. No es una medida
## absoluta —la máquina de CI es otra—, sino un aviso si se dispara.
func _coste_por_frame() -> void:
	var main: Node = await _partida()
	main.change_state(GameState.State.PLAYING)
	await h.ticks(600)
	var tuberias: int = main.pipe_spawner.pipe_count()
	var t0: int = Time.get_ticks_usec()
	await h.ticks(600)
	var us: float = float(Time.get_ticks_usec() - t0) / 600.0
	h.check(
		"un frame de física cuesta menos de 1 ms",
		us < 1000.0,
		"%.1f µs por frame con %d tuberías vivas" % [us, tuberias]
	)
	main.free()


## Criterio del ROADMAP: sin fugas de nodos. 30 partidas completas.
func _sin_huerfanos_tras_muchas_partidas() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 3
	var huerfanos_base: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var nodos_base: int = _contar(main)
	for partida in 30:
		main.change_state(GameState.State.PLAYING)
		for tick in 600:
			await physics_frame
			if main.get_state() == GameState.State.GAME_OVER:
				break
		main.restart()
		await h.ticks(2)
	var huerfanos: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	h.check(
		"30 partidas completas no dejan huérfanos",
		huerfanos == huerfanos_base,
		"%d antes, %d después" % [huerfanos_base, huerfanos]
	)
	h.check(
		"y el árbol vuelve al mismo tamaño",
		_contar(main) == nodos_base,
		"%d nodos antes, %d después" % [nodos_base, _contar(main)]
	)
	main.free()
