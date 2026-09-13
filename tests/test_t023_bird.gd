extends SceneTree
## T-023 — Física y control de Flapo.

const MAIN := "res://scenes/Main.tscn"

var h: Harness
var _game_over_count: int = 0


func _init() -> void:
	h = Harness.new(self)
	print("--- T-023 · Bird ---")
	await _flota_en_ready()
	await _no_sale_por_arriba()
	await _muere_al_caer()
	await _aleteo_fija_la_velocidad()
	quit(h.resumen("T-023"))


## En READY, Flapo flota: ni gravedad ni entrada. (Criterio de T-022.)
func _flota_en_ready() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	var y0: float = main.bird.position.y
	await h.ticks(60)
	h.check(
		"READY flota sin gravedad",
		is_equal_approx(main.bird.position.y, y0),
		"y tras 1 s: %.2f (inicial %.2f)" % [main.bird.position.y, y0]
	)
	main.free()


## El techo se resuelve con un clamp de posición, no con un cuerpo estático:
## debe frenar sin salir de pantalla y sin quedarse pegado. Ver ADR-0006.
func _no_sale_por_arriba() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	var bird: Node = main.bird
	main.change_state(GameState.State.PLAYING)
	bird.position.y = 3.0
	bird.velocity.y = -2000.0
	var y_min: float = INF
	for i in 60:
		await physics_frame
		y_min = minf(y_min, bird.position.y)
	h.check(
		"techo: no sale por arriba",
		y_min >= bird.ceiling_y,
		"y mínima: %.2f (techo %.2f)" % [y_min, bird.ceiling_y]
	)
	h.check(
		"techo: no se queda pegado",
		bird.position.y > bird.ceiling_y,
		"y tras 1 s: %.2f" % bird.position.y
	)
	main.free()


## Morir una sola vez es lo que protege la tabla de transiciones (ADR-0005):
## el caso real es chocar con tubería y suelo en el mismo frame.
func _muere_al_caer() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	var bird: Node = main.bird
	main.state_changed.connect(_on_state)
	main.change_state(GameState.State.PLAYING)
	await h.ticks(180)
	h.check(
		"muere al caer",
		main.get_state() == GameState.State.GAME_OVER,
		"estado final: %s" % GameState.State.keys()[main.get_state()]
	)
	h.check(
		"muere una sola vez", _game_over_count == 1, "transiciones: %d" % _game_over_count
	)

	var v_antes: float = bird.velocity.y
	h.pulsa(KEY_SPACE)
	await h.ticks(3)
	h.check(
		"en GAME_OVER ignora el aleteo",
		bird.velocity.y >= v_antes - 1.0,
		"velocity.y %.1f -> %.1f" % [v_antes, bird.velocity.y]
	)
	h.pulsa(KEY_SPACE, false)
	await h.ticks(1)
	main.free()


## Un Flappy FIJA la velocidad al aletear, no suma una fuerza: es la razón de
## usar CharacterBody2D y no RigidBody2D (ADR-0006).
func _aleteo_fija_la_velocidad() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	var bird: Node = main.bird
	main.change_state(GameState.State.PLAYING)
	await h.ticks(20)
	h.pulsa(KEY_SPACE)
	var v_min: float = INF
	for i in 5:
		await physics_frame
		v_min = minf(v_min, bird.velocity.y)
	h.pulsa(KEY_SPACE, false)
	h.check(
		"aleteo fija velocity.y = flap_impulse",
		is_equal_approx(v_min, bird.flap_impulse),
		"velocity.y mínima: %.1f (impulso %.1f)" % [v_min, bird.flap_impulse]
	)
	main.free()


func _on_state(to: GameState.State) -> void:
	if to == GameState.State.GAME_OVER:
		_game_over_count += 1
