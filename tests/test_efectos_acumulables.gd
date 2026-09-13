extends SceneTree
## Los efectos de fruta se acumulan, uno por eje.
##
## Antes, coger una fruta **sustituía** la anterior: ser grande y coger la
## violeta te dejaba lento y pequeño. Eso no es lo que uno espera — grande y
## lento son cosas distintas y deberían convivir.
##
## Lo que NO se acumula es lo que se cancelaría: pesado y ligero son opuestos
## y comparten eje. Dejarlos convivir daría "no pasa nada" con dos frutas
## encima, que es justo lo que ADR-0019 quería evitar.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- Efectos acumulables ---")
	await _grande_y_lento_conviven()
	await _los_opuestos_se_sustituyen()
	await _cada_uno_caduca_por_su_cuenta()
	await _el_hud_los_ensena_todos()
	await _la_partida_siguiente_empieza_limpia()
	SaveManager.clear()
	quit(h.resumen("Efectos"))


## El caso que reportó Raúl.
func _grande_y_lento_conviven() -> void:
	var main: Node = await _volando()
	main.effects.apply(Effects.Kind.GRANDE)
	var grande: float = main.effects.size_mult()
	h.check("premisa: la naranja agranda", grande > 1.0, "x%.2f" % grande)

	main.effects.apply(Effects.Kind.LENTO)
	h.check("al coger la violeta sigue siendo grande", main.effects.activo(Effects.Kind.GRANDE), "")
	h.check("y además va lento", main.effects.activo(Effects.Kind.LENTO), "")
	h.check(
		"el tamaño no se ha perdido",
		is_equal_approx(main.effects.size_mult(), grande),
		"x%.2f, era x%.2f" % [main.effects.size_mult(), grande]
	)
	h.check(
		"y el mundo va más lento de verdad",
		main.effects.speed_mult() < 1.0,
		"x%.2f" % main.effects.speed_mult()
	)
	# Y que llegue a Flapo, no solo al contador.
	h.check(
		"Flapo sigue grande en el mundo",
		is_equal_approx(main.bird.size_mult, grande),
		"x%.2f" % main.bird.size_mult
	)
	main.free()


## Lo que ADR-0019 protegía: nada de cancelaciones que haya que deducir.
func _los_opuestos_se_sustituyen() -> void:
	var main: Node = await _volando()
	main.effects.apply(Effects.Kind.LIGERO)
	var ligero: float = main.effects.gravity_mult()
	h.check("premisa: la verde aligera", ligero < 1.0, "x%.2f" % ligero)

	main.effects.apply(Effects.Kind.PESADO)
	h.check(
		"coger la roja llevando la verde deja PESADO",
		main.effects.gravity_mult() > 1.0,
		"x%.2f" % main.effects.gravity_mult()
	)
	h.check(
		"y la verde se va: no se cancelan a 'normal'",
		not main.effects.activo(Effects.Kind.LIGERO),
		""
	)
	h.check(
		"premisa: y no ha quedado en 1.0, que sería la cancelación",
		not is_equal_approx(main.effects.gravity_mult(), 1.0),
		"x%.2f" % main.effects.gravity_mult()
	)
	main.free()


## Cada efecto trae su reloj: el que se cogió antes se va antes.
func _cada_uno_caduca_por_su_cuenta() -> void:
	var main: Node = await _volando()
	main.effects.apply(Effects.Kind.GRANDE)
	await h.ticks(int(main.effects.duration * 30.0))
	main.effects.apply(Effects.Kind.LENTO)
	h.check("premisa: los dos activos", main.effects.activos().size() == 2, "")
	h.check(
		"al que se cogió antes le queda menos",
		(
			main.effects.time_left_of(Effects.Kind.GRANDE)
			< main.effects.time_left_of(Effects.Kind.LENTO)
		),
		(
			"grande %.2f, lento %.2f"
			% [
				main.effects.time_left_of(Effects.Kind.GRANDE),
				main.effects.time_left_of(Effects.Kind.LENTO)
			]
		)
	)
	await h.ticks(int(main.effects.duration * 35.0))
	h.check(
		"y se va solo él",
		not main.effects.activo(Effects.Kind.GRANDE) and main.effects.activo(Effects.Kind.LENTO),
		"%s" % str(main.effects.activos())
	)
	h.check("Flapo recupera su tamaño", is_equal_approx(main.bird.size_mult, 1.0), "")
	main.free()


func _el_hud_los_ensena_todos() -> void:
	var main: Node = await _volando()
	var etiqueta: Label = main.hud.get_node("Effect")
	h.check("sin efectos no se enseña nada", not etiqueta.visible, "")

	main.effects.apply(Effects.Kind.GRANDE)
	await h.ticks(2)
	h.check("con uno, sale su nombre", etiqueta.text.contains("Grande"), "'%s'" % etiqueta.text)

	main.effects.apply(Effects.Kind.LENTO)
	await h.ticks(2)
	h.check(
		"con dos, salen los dos",
		etiqueta.text.contains("Grande") and etiqueta.text.contains("Lento"),
		"'%s'" % etiqueta.text
	)
	h.check("separados", etiqueta.text.contains("·"), "'%s'" % etiqueta.text)
	main.free()


func _la_partida_siguiente_empieza_limpia() -> void:
	var main: Node = await _volando()
	main.effects.apply(Effects.Kind.GRANDE)
	main.effects.apply(Effects.Kind.LENTO)
	h.check("premisa: dos efectos encima", main.effects.activos().size() == 2, "")
	main.change_state(GameState.State.GAME_OVER)
	main.restart()
	await h.ticks(2)
	h.check(
		"la partida siguiente empieza sin ninguno",
		main.effects.activos().is_empty(),
		"%s" % str(main.effects.activos())
	)
	h.check("y Flapo con su tamaño", is_equal_approx(main.bird.size_mult, 1.0), "")
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
