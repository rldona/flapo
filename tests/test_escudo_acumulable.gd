extends SceneTree
## El escudo se acumula.
##
## Antes, coger una fruta azul teniendo ya escudo **desperdiciaba la segunda**:
## el escudo era un `sí/no`. Ahora se apilan hasta un tope y se gastan de uno
## en uno, y el HUD dice cuántos quedan.
##
## Lo que hay que proteger, además de que sume y reste: que **el tope no se
## pueda pasar**, que un escudo absorba **un solo golpe** —si absorbiera dos,
## el contador mentiría— y que la partida siguiente empiece a cero.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- Escudo acumulable ---")
	await _suma_al_coger_y_resta_al_gastar()
	await _hay_un_tope()
	await _cada_escudo_absorbe_un_golpe_y_solo_uno()
	await _el_hud_dice_cuantos_quedan()
	await _la_partida_siguiente_empieza_a_cero()
	SaveManager.clear()
	quit(h.resumen("Escudo"))


## Lo que pidió Raúl: coger tres es llevar tres, y gastar uno deja dos.
func _suma_al_coger_y_resta_al_gastar() -> void:
	var main: Node = await _volando()
	h.check(
		"se empieza sin escudo",
		main.effects.shield_count() == 0,
		"%d" % main.effects.shield_count()
	)
	for i in 3:
		main.effects.apply(Effects.Kind.INMUNIDAD)
		h.check(
			"al coger la fruta azul %d, lleva %d" % [i + 1, i + 1],
			main.effects.shield_count() == i + 1,
			"%d" % main.effects.shield_count()
		)
	for i in 3:
		var antes: int = main.effects.shield_count()
		h.check(
			"gastar uno deja %d" % (antes - 1),
			main.effects.consume_shield() and main.effects.shield_count() == antes - 1,
			"%d" % main.effects.shield_count()
		)
	h.check("y al agotarlos, no queda ninguno", main.effects.shield_count() == 0, "")
	h.check(
		"gastar sin tener no devuelve nada ni baja de cero",
		not main.effects.consume_shield() and main.effects.shield_count() == 0,
		"%d" % main.effects.shield_count()
	)
	main.free()


## Un contador sin tope crece hasta hacer el juego otra cosa.
func _hay_un_tope() -> void:
	var main: Node = await _volando()
	for i in GameConfig.SHIELD_MAX + 5:
		main.effects.apply(Effects.Kind.INMUNIDAD)
	h.check(
		"por muchas azules que se cojan, no se pasa del tope",
		main.effects.shield_count() == GameConfig.SHIELD_MAX,
		"%d, tope %d" % [main.effects.shield_count(), GameConfig.SHIELD_MAX]
	)
	h.check("premisa: y el tope no es 1, o esto no sería acumulable", GameConfig.SHIELD_MAX > 1, "")
	main.free()


## Un escudo absorbe UN golpe. Si absorbiera dos, el contador mentiría.
func _cada_escudo_absorbe_un_golpe_y_solo_uno() -> void:
	var main: Node = await _volando()
	main.effects.apply(Effects.Kind.INMUNIDAD)
	main.effects.apply(Effects.Kind.INMUNIDAD)
	h.check(
		"premisa: dos escudos", main.effects.shield_count() == 2, "%d" % main.effects.shield_count()
	)

	main._on_bird_died(Bird.DeathCause.TUBERIA, false)
	h.check(
		"el primer golpe lo absorbe un escudo y Flapo sigue vivo",
		main.get_state() == GameState.State.PLAYING,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	h.check("y queda uno", main.effects.shield_count() == 1, "%d" % main.effects.shield_count())

	main._on_bird_died(Bird.DeathCause.TUBERIA, false)
	h.check("el segundo golpe gasta el que quedaba", main.effects.shield_count() == 0, "")
	h.check(
		"y sigue vivo",
		main.get_state() == GameState.State.PLAYING,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)

	main._on_bird_died(Bird.DeathCause.TUBERIA, false)
	h.check(
		"el tercero ya no lo para nadie",
		main.get_state() == GameState.State.GAME_OVER,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	main.free()


## Que el número llegue a la pantalla, que es lo que pidió Raúl ver.
func _el_hud_dice_cuantos_quedan() -> void:
	var main: Node = await _volando()
	h.check("sin escudo no se enseña nada", main.hud.get_node("Shield").visible == false, "")

	main.effects.apply(Effects.Kind.INMUNIDAD)
	var uno: String = main.hud.get_node("Shield").text
	h.check("con uno, el HUD lo enseña", main.hud.get_node("Shield").visible, "")
	h.check("y no escribe 'x1': sería ruido", not uno.contains("x1"), "'%s'" % uno)

	main.effects.apply(Effects.Kind.INMUNIDAD)
	main.effects.apply(Effects.Kind.INMUNIDAD)
	var tres: String = main.hud.get_node("Shield").text
	h.check("con tres, el HUD dice x3", tres.contains("x3"), "'%s'" % tres)

	main.effects.consume_shield()
	h.check(
		"y al gastar uno, x2",
		main.hud.get_node("Shield").text.contains("x2"),
		"'%s'" % main.hud.get_node("Shield").text
	)

	main.effects.consume_shield()
	main.effects.consume_shield()
	h.check("al quedarse sin ninguno, desaparece", not main.hud.get_node("Shield").visible, "")
	main.free()


func _la_partida_siguiente_empieza_a_cero() -> void:
	var main: Node = await _volando()
	main.effects.apply(Effects.Kind.INMUNIDAD)
	main.effects.apply(Effects.Kind.INMUNIDAD)
	h.check("premisa: se llevan dos", main.effects.shield_count() == 2, "")
	main.change_state(GameState.State.GAME_OVER)
	main.restart()
	h.check(
		"la partida siguiente empieza sin escudos",
		main.effects.shield_count() == 0,
		"%d" % main.effects.shield_count()
	)
	h.check("y el HUD no los enseña", not main.hud.get_node("Shield").visible, "")
	main.free()


func _volando() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	await h.ticks(2)
	return main
