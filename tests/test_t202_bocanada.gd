extends SceneTree
## T-202 — Bocanada: feedback al recuperar aliento.
##
## **`breath_recovered` se emite una sola vez por hueco y solo en la franja
## central.** Esa es la regla, y es lo que se comprueba aquí.
##
## El ticket también pedía **dibujar** esa franja: un brillo tenue en el hueco
## que enseñara dónde se recupera. Se implementó y se quitó — jugando no se
## leía como una pista, se leía como un rectángulo raro en medio del hueco.
## La regla sigue exactamente igual; lo que se fue es el dibujo.

const MAIN := "res://scenes/Main.tscn"
const PIPE := "res://scenes/Pipe.tscn"
const BIRD := "res://scenes/Bird.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-202 · Bocanada ---")
	await _solo_se_recupera_dentro_de_la_franja()
	await _una_sola_vez_por_hueco()
	await _la_senal_lleva_lo_que_de_verdad_ha_entrado()
	SaveManager.clear()
	quit(h.resumen("T-202"))


## Criterio 2, primera mitad: solo en la franja.
func _solo_se_recupera_dentro_de_la_franja() -> void:
	var gap: float = GameConfig.PIPE_GAP
	var media: float = GameConfig.breath_band_half(gap)
	var casos: Array = [
		{"desvio": 0.0, "recupera": true},
		{"desvio": media * 0.8, "recupera": true},
		{"desvio": media * 1.5, "recupera": false},
		{"desvio": gap * 0.45, "recupera": false},
	]
	var fallos: Array = []
	for caso in casos:
		var recuperado: bool = await _cruzar(caso["desvio"])
		if recuperado != caso["recupera"]:
			fallos.append(
				"desvío %.1f: %s (esperado %s)" % [caso["desvio"], recuperado, caso["recupera"]]
			)
	h.check("solo se coge aire cruzando por la franja", fallos.is_empty(), "%s" % str(fallos))


## Criterio 2, segunda mitad: una sola vez por hueco.
func _una_sola_vez_por_hueco() -> void:
	var mundo := Node2D.new()
	root.add_child(mundo)
	var pipe: Pipe = load(PIPE).instantiate()
	pipe.scroll_speed = 0.0
	pipe.position = Vector2(100.0, 0.0)
	mundo.add_child(pipe)
	pipe.set_gap_center(224.0)
	var bird: Bird = load(BIRD).instantiate()
	bird.gravity = 0.0
	bird.position = Vector2(40.0, 224.0)
	mundo.add_child(bird)
	await process_frame
	bird._state = GameState.State.PLAYING
	var veces: Array = [0]
	pipe.centered.connect(func() -> void: veces[0] += 1)

	# Entra, sale y vuelve a entrar por el mismo lado: es lo que hace un
	# aleteo dentro del hueco, y lo que daría dos bocanadas si el guardado
	# de "ya puntuada" no valiera también para esto.
	for vuelta in 3:
		for i in 40:
			bird.velocity = Vector2(120.0, 0.0)
			await physics_frame
		for i in 40:
			bird.velocity = Vector2(-120.0, 0.0)
			await physics_frame
	h.check(
		"una sola bocanada por hueco, aunque se entre tres veces",
		veces[0] == 1,
		"%d bocanadas" % veces[0]
	)
	mundo.free()


## La señal lleva lo que ha entrado de verdad, no lo que se pidió.
func _la_senal_lleva_lo_que_de_verdad_ha_entrado() -> void:
	var bird: Bird = load(BIRD).instantiate()
	root.add_child(bird)
	await process_frame
	bird._state = GameState.State.PLAYING
	var recibido: Array = []
	bird.breath_recovered.connect(func(c: float) -> void: recibido.append(c))

	# Con el aliento lleno no entra nada: no hay bocanada que celebrar.
	bird.recover_breath(GameConfig.BREATH_RECOVER_ON_GAP)
	h.check("con el aliento lleno no hay bocanada", recibido.is_empty(), "%s" % str(recibido))

	# Con hueco de sobra, entra todo.
	bird.recover_breath(-bird.max_breath)
	recibido.clear()
	bird.recover_breath(GameConfig.BREATH_RECOVER_ON_GAP)
	h.check(
		"con hueco de sobra entra todo",
		recibido.size() == 1 and is_equal_approx(recibido[0], GameConfig.BREATH_RECOVER_ON_GAP),
		"%s" % str(recibido)
	)

	# Casi lleno: entra solo lo que cabe, y eso es lo que se anuncia.
	bird.recover_breath(bird.max_breath)
	bird.recover_breath(-5.0)
	recibido.clear()
	bird.recover_breath(GameConfig.BREATH_RECOVER_ON_GAP)
	h.check(
		"casi lleno, se anuncia solo lo que cabía",
		recibido.size() == 1 and is_equal_approx(recibido[0], 5.0),
		"%s (esperado 5.0)" % str(recibido)
	)
	h.check("y la partícula de aire se dispara", bird._air.emitting, "")
	bird.free()


## Cruza el hueco con ese desvío vertical y dice si recuperó aliento.
func _cruzar(desvio: float) -> bool:
	var mundo := Node2D.new()
	root.add_child(mundo)
	var pipe: Pipe = load(PIPE).instantiate()
	pipe.scroll_speed = 0.0
	pipe.position = Vector2(100.0, 0.0)
	mundo.add_child(pipe)
	pipe.set_gap_center(224.0)
	var bird: Bird = load(BIRD).instantiate()
	bird.gravity = 0.0
	bird.position = Vector2(40.0, 224.0 + desvio)
	mundo.add_child(bird)
	await process_frame
	bird._state = GameState.State.PLAYING
	var cogido: Array = [false]
	pipe.centered.connect(func() -> void: cogido[0] = true)
	for i in 120:
		bird.velocity = Vector2(120.0, 0.0)
		await physics_frame
	mundo.free()
	return cogido[0]
