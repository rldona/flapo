extends SceneTree
## T-057 — Variantes de escenario.
##
## Lo que hay que proteger aquí no es que el cielo cambie de color: es que
## **cambiar el cielo no cambie el juego**. Una variante cosmética que mueva
## un solo número del generador rompería los códigos compartidos (T-242) y el
## replay de referencia (T-261) sin que nadie se entere hasta mucho después.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-057 · Variantes de escenario ---")
	_hay_variantes_de_verdad()
	_la_variante_sale_de_la_semilla()
	await _la_variante_llega_al_cielo_y_a_las_capas()
	await _reiniciar_puede_cambiarla()
	await _el_parallax_sigue_funcionando()
	await _cambiar_de_cielo_no_cambia_la_partida()
	SaveManager.clear()
	quit(h.resumen("T-057"))


## Criterio: al menos dos variantes además de la actual.
func _hay_variantes_de_verdad() -> void:
	var n: int = GameConfig.SCENERY_SKY.size()
	h.check("hay al menos 3 variantes (la de siempre y dos más)", n >= 3, "%d variantes" % n)
	h.check(
		"cada variante tiene cielo, tinte y si llueve",
		GameConfig.SCENERY_TINT.size() == n and GameConfig.SCENERY_LLUEVE.size() == n,
		(
			"cielos %d, tintes %d, lluvia %d"
			% [n, GameConfig.SCENERY_TINT.size(), GameConfig.SCENERY_LLUEVE.size()]
		)
	)
	# Que sean distintas de verdad: cuatro variantes del mismo azul no son
	# cuatro variantes.
	var cielos: Array = []
	for i in n:
		cielos.append(GameConfig.SCENERY_SKY[i].to_html())
	h.check(
		"y ninguna repite el cielo de otra",
		cielos.size() == _sin_repetidos(cielos).size(),
		"%s" % str(cielos)
	)
	h.check(
		"el día de siempre es el que no tiñe nada",
		GameConfig.scenery_tint(GameConfig.Scenery.DIA) == Color.WHITE,
		"%s" % GameConfig.scenery_tint(GameConfig.Scenery.DIA).to_html()
	)
	h.check(
		"y solo llueve en la variante de lluvia",
		(
			GameConfig.scenery_rains(GameConfig.Scenery.LLUVIA)
			and not GameConfig.scenery_rains(GameConfig.Scenery.DIA)
			and not GameConfig.scenery_rains(GameConfig.Scenery.NOCHE)
		),
		""
	)


## La variante es función pura de la semilla: misma semilla, mismo cielo.
##
## Es lo que hace que el reto del día salga igual para todo el mundo.
func _la_variante_sale_de_la_semilla() -> void:
	# Semillas raras: la cuenta es un `posmod`, y el riesgo real es que una
	# semilla negativa o enorme devuelva un índice fuera de la tabla y reviente
	# al pintar. Un `%` normal en GDScript devuelve negativo para negativos.
	var tope: int = GameConfig.SCENERY_SKY.size()
	var raras: Array = [0, -1, -999999, 9223372036854775806, 2147483647]
	var fuera: Array = []
	for semilla in raras:
		var v: int = int(GameConfig.scenery_for(semilla))
		if v < 0 or v >= tope:
			fuera.append([semilla, v])
	h.check(
		"ninguna semilla se sale de la tabla, ni negativa ni enorme",
		fuera.is_empty(),
		"%s" % str(fuera)
	)
	var vistas: Dictionary = {}
	for semilla in 200:
		vistas[GameConfig.scenery_for(semilla)] = true
	h.check(
		"y a lo largo de muchas semillas salen todas",
		vistas.size() == GameConfig.SCENERY_SKY.size(),
		"%d de %d variantes en 200 semillas" % [vistas.size(), GameConfig.SCENERY_SKY.size()]
	)


## Que la decisión llegue al mundo, no solo a una función pura.
func _la_variante_llega_al_cielo_y_a_las_capas() -> void:
	for semilla in [1, 2, 3, 4]:
		var main: Node = await h.montar(MAIN, {"log_transitions": false})
		main.session().set_seed(semilla)
		main.change_state(GameState.State.READY)
		var esperada: GameConfig.Scenery = GameConfig.scenery_for(main.session().seed())
		h.check(
			"con semilla %d el fondo se pone en %s" % [semilla, GameConfig.scenery_name(esperada)],
			main.background.variant() == esperada,
			"puesta %s" % GameConfig.scenery_name(main.background.variant())
		)
		h.check(
			"y el cielo coge su color",
			main.sky.color.is_equal_approx(GameConfig.scenery_sky(esperada)),
			(
				"%s, esperado %s"
				% [main.sky.color.to_html(), GameConfig.scenery_sky(esperada).to_html()]
			)
		)
		# El letterbox: en una pantalla que no es múltiplo exacto de 288×512
		# sobra sitio, y ese sobrante tiene que llevar el cielo de la partida.
		# En negro parecía que el juego no cabía en el móvil.
		h.check(
			"y las franjas del letterbox se pintan del mismo cielo",
			RenderingServer.get_default_clear_color().is_equal_approx(
				GameConfig.scenery_sky(esperada)
			),
			(
				"%s, esperado %s"
				% [
					RenderingServer.get_default_clear_color().to_html(),
					GameConfig.scenery_sky(esperada).to_html()
				]
			)
		)
		h.check(
			"y las capas su tinte",
			main.background.get_node("Far").modulate.is_equal_approx(
				GameConfig.scenery_tint(esperada)
			),
			"%s" % main.background.get_node("Far").modulate.to_html()
		)
		main.free()


## Criterio de T-057: "reiniciar puede cambiarla". Con un matiz que hay que
## contar, porque dos tickets se contradicen.
##
## T-240 garantiza que **reiniciar repite la misma partida**: la semilla no se
## vuelve a sortear al morir y volver a intentarlo, a propósito. Como el cielo
## sale de la semilla, reintentar mantiene el cielo — y eso es lo correcto: si
## cambiara, el mismo código de T-242 daría dos partidas de aspecto distinto.
##
## Lo que sí cambia el cielo es empezar una partida **nueva**, que es lo que
## hace el botón de Jugar del menú. Eso es lo que se comprueba aquí.
func _reiniciar_puede_cambiarla() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})

	# Reintentar la misma: el cielo NO cambia, y es lo que se quiere.
	main.start_free()
	await h.ticks(1)
	var primera: GameConfig.Scenery = main.background.variant()
	var semilla: int = main.session().seed()
	main.change_state(GameState.State.GAME_OVER)
	main.restart()
	await h.ticks(1)
	h.check(
		"reintentar la misma partida conserva su cielo",
		main.background.variant() == primera and main.session().seed() == semilla,
		(
			"%s con semilla %d, ahora %s con %d"
			% [
				GameConfig.scenery_name(primera),
				semilla,
				GameConfig.scenery_name(main.background.variant()),
				main.session().seed()
			]
		)
	)

	# Empezar una partida nueva desde el menú: ahí sí puede cambiar.
	var vistas: Dictionary = {}
	for intento in 40:
		main.to_menu()
		main.start_free()
		await h.ticks(1)
		vistas[main.background.variant()] = true
	main.free()
	h.check(
		"y empezar partidas nuevas acaba sacando varias",
		vistas.size() >= 2,
		"%d variantes distintas en 40 partidas nuevas" % vistas.size()
	)


## Criterio: la variante no rompe el parallax que ya había (T-043).
func _el_parallax_sigue_funcionando() -> void:
	for variante in [GameConfig.Scenery.DIA, GameConfig.Scenery.NOCHE, GameConfig.Scenery.LLUVIA]:
		var main: Node = await h.montar(MAIN, {"log_transitions": false})
		main.background.set_variant(variante)
		h.jugar(main)
		var antes_lejos: float = main.background.layer_offset(0)
		var antes_cerca: float = main.background.layer_offset(1)
		await h.ticks(30)
		var lejos: float = absf(main.background.layer_offset(0) - antes_lejos)
		var cerca: float = absf(main.background.layer_offset(1) - antes_cerca)
		h.check(
			"con %s las dos capas siguen moviéndose" % GameConfig.scenery_name(variante),
			lejos > 0.0 and cerca > 0.0,
			"lejana %.1f px, cercana %.1f px" % [lejos, cerca]
		)
		h.check(
			"y la lejana sigue yendo más despacio que la cercana",
			lejos < cerca,
			"lejana %.1f px, cercana %.1f px" % [lejos, cerca]
		)
		main.free()


## El criterio que de verdad importa: el adorno no toca el juego.
##
## Dos partidas con la MISMA semilla pero el escenario forzado a variantes
## distintas tienen que dar exactamente las mismas tuberías. Si la variante
## pidiera un número al generador, la secuencia se movería un paso y esto
## saltaría.
func _cambiar_de_cielo_no_cambia_la_partida() -> void:
	var a: Array = await _secuencia(GameConfig.Scenery.DIA)
	var b: Array = await _secuencia(GameConfig.Scenery.NOCHE)
	h.check("premisa: han salido tuberías", a.size() > 2, "%d" % a.size())
	h.check(
		"con otro cielo salen exactamente las mismas tuberías",
		a == b,
		"%s vs %s" % [str(a), str(b)]
	)


func _secuencia(variante: GameConfig.Scenery) -> Array:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.session().set_seed(777)
	h.jugar(main)
	main.background.set_variant(variante)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	var vistas: Dictionary = {}
	var orden: Array = []
	for tick in 300:
		await physics_frame
		for hijo in main.pipe_spawner.get_children():
			if hijo is Pipe and not vistas.has(hijo.get_instance_id()):
				vistas[hijo.get_instance_id()] = true
				orden.append([snappedf(hijo.get_base_gap_center(), 0.01), hijo.soft, hijo.spin])
	main.free()
	return orden


func _sin_repetidos(lista: Array) -> Array:
	var unicos: Dictionary = {}
	for x in lista:
		unicos[x] = true
	return unicos.keys()
