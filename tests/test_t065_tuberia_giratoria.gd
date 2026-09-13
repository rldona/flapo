extends SceneTree
## T-065 — Tubería giratoria.
##
## El criterio entero del ticket es una equivalencia: **con giro y sin giro,
## la física y la puntuación tienen que ser idénticas**. Así que el test es
## una comparación de dos tuberías gemelas, una girando y otra no, y la
## afirmación de que la única diferencia está en el dibujo.
##
## Ojo a la trampa: comparar dos cosas que no se mueven da siempre igual. Por
## eso el test comprueba primero que **el giro ocurre de verdad**; sin ese
## aserto, todo lo demás pasaría con el giro desactivado.

const MAIN := "res://scenes/Main.tscn"
const PIPE := "res://scenes/Pipe.tscn"
const BIRD := "res://scenes/Bird.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-065 · Tubería giratoria ---")
	_la_probabilidad_es_pura_y_respeta_la_rampa()
	await _el_giro_ocurre_pero_la_hitbox_no_se_mueve()
	await _la_puntuacion_es_identica_con_y_sin_giro()
	await _la_colision_es_identica_con_y_sin_giro()
	SaveManager.clear()
	quit(h.resumen("T-065"))


func _la_probabilidad_es_pura_y_respeta_la_rampa() -> void:
	h.check("a 0 puntos no gira ninguna", is_zero_approx(GameConfig.spin_pipe_chance(0)), "")
	h.check(
		"justo antes del mínimo tampoco",
		is_zero_approx(GameConfig.spin_pipe_chance(GameConfig.SPIN_PIPE_MIN_SCORE - 1)),
		"%.3f" % GameConfig.spin_pipe_chance(GameConfig.SPIN_PIPE_MIN_SCORE - 1)
	)
	h.check(
		"en el mínimo arranca",
		GameConfig.spin_pipe_chance(GameConfig.SPIN_PIPE_MIN_SCORE) > 0.0,
		"%.3f" % GameConfig.spin_pipe_chance(GameConfig.SPIN_PIPE_MIN_SCORE)
	)
	h.check(
		"y nunca es la norma",
		GameConfig.spin_pipe_chance(1000) < 0.5,
		"%.3f" % GameConfig.spin_pipe_chance(1000)
	)


## Criterio: la hitbox no cambia por el giro; solo el dibujo.
func _el_giro_ocurre_pero_la_hitbox_no_se_mueve() -> void:
	var escena: PackedScene = load(PIPE)
	var quieta: Pipe = escena.instantiate()
	var girando: Pipe = escena.instantiate()
	root.add_child(quieta)
	root.add_child(girando)
	await process_frame
	for p in [quieta, girando]:
		p.scroll_speed = 0.0
		p.gap = GameConfig.PIPE_GAP
		p.set_gap_center(GameConfig.playable_height() * 0.5)
	girando.spin = true

	var forma_antes: Transform2D = _forma(girando).global_transform
	var zona_antes: Transform2D = girando.get_node("ScoreZone").global_transform
	var angulo_antes: float = girando.spin_angle()

	for i in 90:
		await physics_frame

	# PRIMERO la premisa: si el giro no ocurriera, el resto del test sería
	# comparar dos cosas quietas y pasaría siempre.
	h.check(
		"el giro ocurre de verdad",
		absf(girando.spin_angle() - angulo_antes) > 1.0,
		"ha girado %.2f rad en 1,5 s" % absf(girando.spin_angle() - angulo_antes)
	)
	h.check(
		"y la tubería quieta no gira",
		is_zero_approx(quieta.spin_angle()),
		"%.4f" % quieta.spin_angle()
	)

	h.check(
		"la forma de colisión no se ha movido ni girado",
		_forma(girando).global_transform.is_equal_approx(forma_antes),
		"%s -> %s" % [forma_antes, _forma(girando).global_transform]
	)
	h.check(
		"ni la zona de puntuación",
		girando.get_node("ScoreZone").global_transform.is_equal_approx(zona_antes),
		"%s" % girando.get_node("ScoreZone").global_transform
	)
	# Y la giratoria tiene exactamente la misma hitbox que la quieta.
	h.check(
		"y es idéntica a la de una tubería normal",
		(
			_forma(girando).global_transform.is_equal_approx(_forma(quieta).global_transform)
			and _tamano(girando).is_equal_approx(_tamano(quieta))
		),
		"girando %s vs quieta %s" % [_tamano(girando), _tamano(quieta)]
	)
	quieta.free()
	girando.free()


## Criterio: la puntuación es idéntica con y sin la variante.
func _la_puntuacion_es_identica_con_y_sin_giro() -> void:
	var con: int = await _cruzar(true)
	var sin: int = await _cruzar(false)
	h.check("premisa: cruzar puntúa", sin > 0, "%d puntos sin giro" % sin)
	h.check(
		"cruzar puntúa lo mismo con giro que sin él",
		con == sin,
		"con giro %d, sin giro %d" % [con, sin]
	)


## Y la colisión: si con giro se choca donde sin giro no, el giro no sería
## solo visual.
func _la_colision_es_identica_con_y_sin_giro() -> void:
	var alturas: Array = [60.0, 150.0, 224.0, 300.0, 400.0]
	var distintas: Array = []
	for y in alturas:
		var con: bool = await _choca(true, y)
		var sin: bool = await _choca(false, y)
		if con != sin:
			distintas.append("y=%.0f: con %s, sin %s" % [y, con, sin])
	h.check(
		"en %d alturas se choca exactamente igual" % alturas.size(),
		distintas.is_empty(),
		"difieren: %s" % str(distintas)
	)
	# Premisa: entre esas alturas hay de las dos, si no la comparación es vacía.
	var choques: int = 0
	for y in alturas:
		if await _choca(false, y):
			choques += 1
	h.check(
		"premisa: entre esas alturas hay choques y pasos",
		choques > 0 and choques < alturas.size(),
		"%d choques de %d alturas" % [choques, alturas.size()]
	)


## Cruza el hueco moviendo a Flapo y devuelve los puntos conseguidos.
func _cruzar(gira: bool) -> int:
	var mundo := Node2D.new()
	root.add_child(mundo)
	var pipe: Pipe = load(PIPE).instantiate()
	pipe.scroll_speed = 0.0
	pipe.position = Vector2(100.0, 0.0)
	mundo.add_child(pipe)
	pipe.set_gap_center(224.0)
	pipe.spin = gira
	var puntos: Array = [0]
	pipe.scored.connect(func() -> void: puntos[0] += 1)

	var bird: Bird = load(BIRD).instantiate()
	bird.gravity = 0.0
	bird.position = Vector2(40.0, 224.0)
	mundo.add_child(bird)
	await process_frame
	bird._state = GameState.State.PLAYING
	for i in 120:
		bird.velocity = Vector2(120.0, 0.0)
		await physics_frame
	mundo.free()
	return puntos[0]


## Lanza a Flapo a esa altura y dice si chocó.
func _choca(gira: bool, y: float) -> bool:
	var mundo := Node2D.new()
	root.add_child(mundo)
	var pipe: Pipe = load(PIPE).instantiate()
	pipe.scroll_speed = 0.0
	pipe.position = Vector2(100.0, 0.0)
	mundo.add_child(pipe)
	pipe.set_gap_center(224.0)
	pipe.spin = gira

	var bird: Bird = load(BIRD).instantiate()
	bird.gravity = 0.0
	bird.position = Vector2(40.0, y)
	mundo.add_child(bird)
	await process_frame
	var choco: Array = [false]
	bird.died.connect(func(_c: Bird.DeathCause, _s: bool) -> void: choco[0] = true)
	bird._state = GameState.State.PLAYING
	for i in 120:
		bird.velocity = Vector2(120.0, 0.0)
		await physics_frame
		if choco[0]:
			break
	mundo.free()
	return choco[0]


func _forma(pipe: Pipe) -> CollisionShape2D:
	return pipe.get_node("Top/CollisionShape2D") as CollisionShape2D


func _tamano(pipe: Pipe) -> Vector2:
	var forma := _forma(pipe).shape
	return (forma as RectangleShape2D).size if forma is RectangleShape2D else Vector2.ZERO
