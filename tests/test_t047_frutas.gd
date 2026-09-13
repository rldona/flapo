extends SceneTree
## T-047 — Frutas y efectos temporales.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-047 · Frutas ---")
	await _un_solo_efecto_a_la_vez()
	await _los_efectos_caducan()
	await _cada_fruta_hace_lo_suyo()
	await _el_escudo_absorbe_un_golpe()
	await _los_castigos_dan_puntos()
	await _la_naranja_no_sale_con_el_hueco_estrecho()
	await _las_frutas_no_cruzan_partidas()
	SaveManager.clear()
	Settings.clear()
	quit(h.resumen("T-047"))


func _partida() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 101
	main.fruit_spawner.random_seed = 202
	main.bird.gravity = 0.0
	main.bird.collision_mask = 0
	return main


## Coger una fruta sustituye el efecto anterior: nada de acumular.
func _un_solo_efecto_a_la_vez() -> void:
	var main: Node = await _partida()
	main.change_state(GameState.State.PLAYING)
	main._on_fruit_taken(Effects.Kind.LIGERO, 0)
	h.check(
		"la verde deja a Flapo ligero",
		main.bird.gravity_mult < 1.0,
		"gravity_mult %.2f" % main.bird.gravity_mult
	)
	main._on_fruit_taken(Effects.Kind.PESADO, 0)
	h.check(
		"coger la roja después deja pesado, no neutro",
		main.bird.gravity_mult > 1.0,
		"gravity_mult %.2f" % main.bird.gravity_mult
	)
	h.check(
		"y solo hay un efecto activo",
		main.effects.kind() == Effects.Kind.PESADO,
		"efecto: %s" % main.effects.kind_name(main.effects.kind())
	)
	main.free()


func _los_efectos_caducan() -> void:
	var main: Node = await _partida()
	main.effects.duration = 0.5
	main.change_state(GameState.State.PLAYING)
	main._on_fruit_taken(Effects.Kind.PESADO, 0)
	var ticks: int = 0
	for i in 120:
		await process_frame
		ticks += 1
		if main.effects.kind() == Effects.Kind.NINGUNO:
			break
	h.check(
		"el efecto caduca solo",
		main.effects.kind() == Effects.Kind.NINGUNO,
		"caducó tras %d frames (duración %.2f s)" % [ticks, main.effects.duration]
	)
	h.check(
		"y Flapo vuelve a su gravedad normal",
		is_equal_approx(main.bird.gravity_mult, 1.0),
		"gravity_mult %.2f" % main.bird.gravity_mult
	)
	main.free()


func _cada_fruta_hace_lo_suyo() -> void:
	var main: Node = await _partida()
	main.change_state(GameState.State.PLAYING)
	var base: float = main.ground.scroll_speed

	main._on_fruit_taken(Effects.Kind.LENTO, 0)
	h.check(
		"la violeta frena el mundo",
		main.ground.scroll_speed < base,
		"%.1f -> %.1f px/s" % [base, main.ground.scroll_speed]
	)
	h.check(
		"y también las tuberías, para que no se desincronicen",
		is_equal_approx(main.pipe_spawner.scroll_speed, main.ground.scroll_speed),
		"spawner %.1f px/s" % main.pipe_spawner.scroll_speed
	)

	var radio_base: float = (main.bird.get_node("CollisionShape2D").shape as CircleShape2D).radius
	main._on_fruit_taken(Effects.Kind.GRANDE, 0)
	var radio: float = (main.bird.get_node("CollisionShape2D").shape as CircleShape2D).radius
	h.check(
		"la naranja agranda el dibujo al doble",
		is_equal_approx(main.bird.get_node("Sprite").scale.x, main.effects.big_size_mult),
		"escala %.2f" % main.bird.get_node("Sprite").scale.x
	)
	h.check(
		"y la hitbox menos que el dibujo, a propósito",
		radio > radio_base and radio < radio_base * main.effects.big_size_mult,
		"radio %.1f -> %.1f (dibujo x%.1f)" % [radio_base, radio, main.effects.big_size_mult]
	)
	h.check("la violeta ya no está activa", main.ground.scroll_speed > base * 0.9, "")
	main.free()


## Criterio: la azul da inmunidad a UN toque.
func _el_escudo_absorbe_un_golpe() -> void:
	var main: Node = await _partida()
	main.bird.collision_mask = Bird.OBSTACULOS
	main.bird.gravity = 1200.0
	main.change_state(GameState.State.PLAYING)
	main._on_fruit_taken(Effects.Kind.INMUNIDAD, 0)
	h.check("la azul da escudo", main.effects.has_shield(), "")

	for tick in 600:
		await physics_frame
		if not main.effects.has_shield():
			break
	h.check(
		"el escudo se gasta al chocar y la partida sigue",
		main.get_state() == GameState.State.PLAYING,
		(
			"estado: %s, escudo: %s"
			% [GameState.State.keys()[main.get_state()], main.effects.has_shield()]
		)
	)

	# Y el segundo golpe sí mata: la inmunidad era de un toque.
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	h.check(
		"el segundo golpe sí mata",
		main.get_state() == GameState.State.GAME_OVER,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	main.free()


## Lo que convierte un castigo en una decisión (ADR-0019).
func _los_castigos_dan_puntos() -> void:
	var main: Node = await _partida()
	main.change_state(GameState.State.PLAYING)
	var antes: int = main.get_score()
	main._on_fruit_taken(Effects.Kind.PESADO, main.fruit_spawner.penalty_points)
	h.check(
		"la fruta de castigo paga en puntos",
		main.get_score() == antes + main.fruit_spawner.penalty_points,
		"%d -> %d puntos" % [antes, main.get_score()]
	)
	var ahora: int = main.get_score()
	main._on_fruit_taken(Effects.Kind.LIGERO, 0)
	h.check(
		"y las buenas no dan puntos: su premio es el efecto",
		main.get_score() == ahora,
		"%d puntos" % main.get_score()
	)
	main.free()


## Con Flapo al doble y el hueco ya estrecho no habría forma de pasar.
func _la_naranja_no_sale_con_el_hueco_estrecho() -> void:
	var main: Node = await _partida()
	var spawner: Node = main.fruit_spawner
	spawner.set_difficulty(GameConfig.SCROLL_SPEED, GameConfig.PIPE_GAP, GameConfig.PIPE_SPACING)
	h.check(
		"con el hueco ancho la naranja puede salir",
		spawner.kinds_disponibles().has(Effects.Kind.GRANDE),
		"hueco %.0f px, mínimo %.0f" % [GameConfig.PIPE_GAP, spawner.big_min_gap]
	)
	spawner.set_difficulty(
		GameConfig.SCROLL_SPEED_MAX, GameConfig.PIPE_GAP_MIN, GameConfig.PIPE_SPACING_MAX
	)
	h.check(
		"con el hueco estrecho ya no sale",
		not spawner.kinds_disponibles().has(Effects.Kind.GRANDE),
		"hueco %.0f px, mínimo %.0f" % [GameConfig.PIPE_GAP_MIN, spawner.big_min_gap]
	)
	h.check(
		"pero las demás siguen saliendo",
		spawner.kinds_disponibles().size() == 4,
		"%d frutas disponibles" % spawner.kinds_disponibles().size()
	)
	main.free()


## Ni las frutas ni sus efectos sobreviven a un reinicio.
func _las_frutas_no_cruzan_partidas() -> void:
	var main: Node = await _partida()
	main.fruit_spawner.chance = 1.0
	main.change_state(GameState.State.PLAYING)
	main._on_fruit_taken(Effects.Kind.GRANDE, 0)
	await h.ticks(200)
	var vivas: int = main.fruit_spawner.fruit_count()

	main.bird.collision_mask = Bird.OBSTACULOS
	main.bird.gravity = 1200.0
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	main.restart()
	await h.ticks(2)

	h.check(
		"reiniciar limpia las frutas", main.fruit_spawner.fruit_count() == 0, "había %d" % vivas
	)
	h.check(
		"y los efectos",
		main.effects.kind() == Effects.Kind.NINGUNO and not main.effects.has_shield(),
		"efecto: %s" % main.effects.kind_name(main.effects.kind())
	)
	h.check(
		"y Flapo vuelve a su tamaño",
		is_equal_approx(main.bird.get_node("Sprite").scale.x, 1.0),
		"escala %.2f" % main.bird.get_node("Sprite").scale.x
	)
	main.free()
