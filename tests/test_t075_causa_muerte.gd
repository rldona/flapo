extends SceneTree
## T-075 — La causa de la muerte llega al Game Over.
##
## Lo que se comprueba es que la frase que sale **corresponde a cómo murió
## Flapo de verdad**, no a un sorteo entre todas. Y que ninguna combinación
## deja el panel mudo, que es el único fallo que el jugador notaría.

const MAIN := "res://scenes/Main.tscn"
const RECURSO := "res://assets/data/death_lines.tres"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-075 · Causa de muerte ---")
	_cada_causa_tira_de_su_lista()
	_sin_aliento_manda_sobre_la_causa()
	_una_lista_vacia_cae_en_la_generica()
	await _chocar_con_una_tuberia_dice_tuberia()
	await _caer_al_suelo_dice_suelo()
	SaveManager.clear()
	quit(h.resumen("T-075"))


func _recurso() -> DeathLines:
	return load(RECURSO) as DeathLines


## Un recurso de laboratorio: una frase por lista, así la frase identifica
## sola de qué lista salió.
func _maqueta() -> DeathLines:
	var r := DeathLines.new()
	r.lines = PackedStringArray(["generica"])
	r.lines_pipe = PackedStringArray(["tuberia"])
	r.lines_ground = PackedStringArray(["suelo"])
	r.lines_void = PackedStringArray(["vacio"])
	r.lines_breathless = PackedStringArray(["sin-aliento"])
	return r


## Criterio: variantes por causa, y cada una tira de la suya.
func _cada_causa_tira_de_su_lista() -> void:
	var r: DeathLines = _maqueta()
	var rng := RandomNumberGenerator.new()
	h.check(
		"la tubería usa lines_pipe",
		r.pick_for(Bird.DeathCause.TUBERIA, false, rng) == "tuberia",
		r.pick_for(Bird.DeathCause.TUBERIA, false, rng)
	)
	h.check(
		"el suelo usa lines_ground",
		r.pick_for(Bird.DeathCause.SUELO, false, rng) == "suelo",
		r.pick_for(Bird.DeathCause.SUELO, false, rng)
	)
	h.check(
		"el vacío usa lines_void",
		r.pick_for(Bird.DeathCause.VACIO, false, rng) == "vacio",
		r.pick_for(Bird.DeathCause.VACIO, false, rng)
	)


## El agotamiento explica mejor la muerte que contra qué se dio.
func _sin_aliento_manda_sobre_la_causa() -> void:
	var r: DeathLines = _maqueta()
	var rng := RandomNumberGenerator.new()
	for causa in [Bird.DeathCause.TUBERIA, Bird.DeathCause.SUELO, Bird.DeathCause.VACIO]:
		h.check(
			"sin aliento gana a la causa %d" % causa,
			r.pick_for(causa, true, rng) == "sin-aliento",
			r.pick_for(causa, true, rng)
		)


## Se pueden dejar listas sin rellenar sin que el panel se quede en blanco.
func _una_lista_vacia_cae_en_la_generica() -> void:
	var r: DeathLines = _maqueta()
	r.lines_pipe = PackedStringArray()
	r.lines_breathless = PackedStringArray()
	var rng := RandomNumberGenerator.new()
	h.check(
		"sin lista de tubería cae en la genérica",
		r.pick_for(Bird.DeathCause.TUBERIA, false, rng) == "generica",
		r.pick_for(Bird.DeathCause.TUBERIA, false, rng)
	)
	h.check(
		"sin lista de agotamiento cae en la de la causa",
		r.pick_for(Bird.DeathCause.SUELO, true, rng) == "suelo",
		r.pick_for(Bird.DeathCause.SUELO, true, rng)
	)
	var vacio := DeathLines.new()
	h.check(
		"un recurso sin nada devuelve cadena vacía",
		vacio.pick_for(Bird.DeathCause.SUELO, false, rng) == "",
		""
	)
	h.check(
		"y el recurso real tiene frases para las tres causas",
		(
			not _recurso().lines_pipe.is_empty()
			and not _recurso().lines_ground.is_empty()
			and not _recurso().lines_void.is_empty()
		),
		""
	)


## En una partida real: se estampa contra una tubería.
##
## Se coloca a Flapo dentro de la tubería a mano en vez de esperar a que la
## física lo lleve: lo que se prueba es la clasificación de la causa, no el
## vuelo, y esperar haría el test dependiente de la semilla del spawner.
func _chocar_con_una_tuberia_dice_tuberia() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.fruit_spawner.chance = 0.0
	main.pipe_spawner.random_seed = 7
	h.jugar(main)

	# Se espera a que exista una tubería y se mete a Flapo en el tubo de
	# arriba, bien lejos del suelo para que no haya duda de contra qué chocó.
	var pipe: Node = null
	for tick in 300:
		await physics_frame
		for hijo in main.pipe_spawner.get_children():
			if hijo is Pipe:
				pipe = hijo
				break
		if pipe != null:
			break
	h.check("hay una tubería en escena", pipe != null, "")
	if pipe == null:
		main.free()
		return

	var top: Node2D = pipe.get_node("Top")
	main.bird.global_position = top.global_position
	main.bird.velocity = Vector2.ZERO
	for tick in 30:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break

	h.check("Flapo ha muerto", main.get_state() == GameState.State.GAME_OVER, "")
	h.check(
		"y la causa registrada es la tubería",
		main._death_cause == Bird.DeathCause.TUBERIA,
		"causa: %d" % main._death_cause
	)
	var titulo: Label = main.game_over_panel.get_node("Root/Box/Title")
	h.check(
		"y la frase del panel es de la lista de tuberías",
		_recurso().lines_pipe.has(titulo.text),
		"'%s'" % titulo.text
	)
	main.free()


## Y sin tocar ninguna tubería: se cae al suelo.
func _caer_al_suelo_dice_suelo() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.fruit_spawner.chance = 0.0
	# Sin tuberías no hay más obstáculo que el suelo: aísla la causa.
	main.pipe_spawner.set_process(false)
	main.pipe_spawner.set_physics_process(false)
	h.jugar(main)
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break

	h.check("Flapo ha muerto", main.get_state() == GameState.State.GAME_OVER, "")
	h.check(
		"sin tuberías delante, la causa es el suelo",
		main._death_cause == Bird.DeathCause.SUELO,
		"causa: %d" % main._death_cause
	)
	var titulo: Label = main.game_over_panel.get_node("Root/Box/Title")
	var esperadas: PackedStringArray = (
		_recurso().lines_breathless if main._death_breathless else _recurso().lines_ground
	)
	h.check(
		"y la frase es de la lista que toca",
		esperadas.has(titulo.text),
		"'%s' (sin aliento: %s)" % [titulo.text, main._death_breathless]
	)
	main.free()
