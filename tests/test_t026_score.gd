extends SceneTree
## T-026 — Zona de puntuación.

const MAIN := "res://scenes/Main.tscn"
const PIPE := "res://scenes/Pipe.tscn"
const BIRD := "res://scenes/Bird.tscn"

var h: Harness
var _puntos: int = 0


func _init() -> void:
	h = Harness.new(self)
	print("--- T-026 · Zona de puntuación ---")
	await _puntua_al_cruzar_el_hueco()
	await _una_sola_vez_aunque_oscile()
	await _no_puntua_si_choca()
	await _main_lleva_la_cuenta_y_la_reinicia()
	quit(h.resumen("T-026"))


## Monta una tubería quieta y a Flapo sin gravedad, para poder moverlo a mano.
func _escenario(y_flapo: float) -> Dictionary:
	var mundo := Node2D.new()
	root.add_child(mundo)
	var pipe: Node = load(PIPE).instantiate()
	pipe.moving = false
	pipe.position = Vector2(120.0, 0.0)
	mundo.add_child(pipe)
	var bird: Node = load(BIRD).instantiate()
	bird.gravity = 0.0
	bird.position = Vector2(40.0, y_flapo)
	mundo.add_child(bird)
	await process_frame
	pipe.set_gap_center(256.0)
	pipe.scored.connect(_on_scored)
	bird._state = GameState.State.PLAYING
	_puntos = 0
	return {"mundo": mundo, "pipe": pipe, "bird": bird}


func _on_scored() -> void:
	_puntos += 1


## Cruzar el hueco de lado a lado da exactamente un punto.
func _puntua_al_cruzar_el_hueco() -> void:
	var e: Dictionary = await _escenario(256.0)
	for i in 120:
		e["bird"].velocity = Vector2(120.0, 0.0)
		await physics_frame
	h.check(
		"cruzar el hueco puntúa una vez",
		_puntos == 1,
		"puntos: %d, x final %.1f" % [_puntos, e["bird"].position.x]
	)
	e["mundo"].free()


## Criterio: una sola puntuación por tubería, aunque el pájaro oscile.
##
## Se le hace entrar, salir marcha atrás y volver a entrar tres veces. Sin el
## flag, `body_entered` daría un punto por cada entrada.
func _una_sola_vez_aunque_oscile() -> void:
	var e: Dictionary = await _escenario(256.0)
	var bird: Node = e["bird"]
	var entradas: int = 0
	for vuelta in 3:
		for i in 40:
			bird.velocity = Vector2(150.0, 0.0)
			await physics_frame
			if bird.position.x > 125.0:
				break
		entradas += 1
		for i in 40:
			bird.velocity = Vector2(-150.0, 0.0)
			await physics_frame
			if bird.position.x < 90.0:
				break
	h.check(
		"solo puntúa una vez aunque oscile",
		_puntos == 1,
		"%d entradas al hueco, %d punto(s)" % [entradas, _puntos]
	)
	e["mundo"].free()


## Chocar contra el tubo no debe puntuar: el hueco es el único camino.
func _no_puntua_si_choca() -> void:
	var e: Dictionary = await _escenario(60.0)
	for i in 120:
		e["bird"].velocity = Vector2(120.0, 0.0)
		await physics_frame
	h.check(
		"chocar no puntúa",
		_puntos == 0,
		"puntos: %d, x final %.1f" % [_puntos, e["bird"].position.x]
	)
	e["mundo"].free()


## La cuenta la lleva Main, y se reinicia al volver a READY (no al morir:
## el panel de Game Over de T-071 tiene que poder seguir enseñándola).
func _main_lleva_la_cuenta_y_la_reinicia() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.bird.gravity = 0.0
	main.pipe_spawner.random_seed = 7
	var emitidos: Array[int] = []
	main.score_changed.connect(func(s: int) -> void: emitidos.append(s))
	main.change_state(GameState.State.PLAYING)

	# Flapo quieto en el centro; las tuberías vienen hacia él. El hueco se
	# fuerza a su altura en cada tubería que nace: si se dejara al azar,
	# chocaría casi siempre y esto probaría la muerte, no la puntuación.
	main.bird.position = Vector2(72.0, 256.0)
	for i in 600:
		for hijo in main.pipe_spawner.get_children():
			if hijo is Pipe:
				hijo.set_gap_center(256.0)
		main.bird.velocity = Vector2.ZERO
		main.bird.position.y = 256.0
		await physics_frame

	h.check(
		"Main cuenta las tuberías cruzadas",
		main.get_score() > 0,
		"puntuación tras 10 s: %d" % main.get_score()
	)
	h.check(
		"cada punto emite score_changed",
		not emitidos.is_empty() and emitidos[-1] == main.get_score(),
		"emisiones: %s" % [emitidos]
	)

	main.change_state(GameState.State.GAME_OVER)
	var al_morir: int = main.get_score()
	h.check("al morir la puntuación se conserva", al_morir > 0, "puntuación: %d" % al_morir)
	main.change_state(GameState.State.READY)
	h.check(
		"al reiniciar la puntuación vuelve a 0",
		main.get_score() == 0,
		"puntuación: %d" % main.get_score()
	)
	main.free()
