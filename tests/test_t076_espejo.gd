extends SceneTree
## T-076 — Modo espejo desbloqueable.
##
## Dos cosas que proteger. Una: **el modo normal no cambia en nada**. Un modo
## alternativo que toque de refilón el juego de siempre no vale la pena, por
## bueno que sea.
##
## Y dos: que la inversión sea **consistente**. No basta con que la gravedad
## tire para arriba; el aleteo, el tope de caída, el planeo y la muerte tienen
## que estar del revés a la vez. Una inversión a medias es un modo roto que
## además parece que funciona.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-076 · Modo espejo ---")
	_el_desbloqueo_depende_del_record()
	await _el_boton_no_existe_hasta_desbloquearlo()
	await _nunca_se_activa_solo()
	await _la_gravedad_esta_del_reves()
	await _el_aleteo_esta_del_reves()
	await _el_techo_mata_en_espejo()
	await _el_modo_normal_no_cambia()
	await _el_espejo_viaja_en_el_replay()
	SaveManager.clear()
	quit(h.resumen("T-076"))


## Criterio: el desbloqueo depende del récord guardado.
func _el_desbloqueo_depende_del_record() -> void:
	var umbral: int = GameConfig.MIRROR_UNLOCK_SCORE
	h.check("premisa: hay un umbral y no es 0", umbral > 0, "%d" % umbral)
	h.check("justo por debajo del umbral, cerrado", not GameConfig.mirror_unlocked(umbral - 1), "")
	h.check("en el umbral, abierto", GameConfig.mirror_unlocked(umbral), "")
	h.check("y por encima sigue abierto", GameConfig.mirror_unlocked(umbral + 50), "")
	h.check("sin récord, cerrado", not GameConfig.mirror_unlocked(0), "")


## El botón no está desactivado: no está. Un botón apagado que no dice por
## qué es peor que no tener botón.
func _el_boton_no_existe_hasta_desbloquearlo() -> void:
	var flojo: Node = await _con_record(GameConfig.MIRROR_UNLOCK_SCORE - 1)
	flojo.menu_panel.options_pressed.emit()
	h.check(
		"con récord por debajo del umbral, el botón no se ve",
		not flojo.options_panel.mirror_visible(),
		""
	)
	flojo.free()

	var bueno: Node = await _con_record(GameConfig.MIRROR_UNLOCK_SCORE)
	bueno.menu_panel.options_pressed.emit()
	h.check("al llegar al récord, aparece", bueno.options_panel.mirror_visible(), "")
	h.check(
		"y dice que está apagado",
		bueno.options_panel.lines_text()[3] == "Espejo: no",
		"'%s'" % bueno.options_panel.lines_text()[3]
	)
	bueno.free()


## Criterio: nunca automático. Ni al desbloquearlo, ni tocándolo sin permiso.
func _nunca_se_activa_solo() -> void:
	var main: Node = await _con_record(GameConfig.MIRROR_UNLOCK_SCORE + 10)
	h.check("desbloquearlo no lo enciende", not main.session().mirror(), "")
	h.jugar(main)
	h.check("y Flapo vuela del derecho", not main.bird.mirror, "")
	main.free()

	# Y con el récord por debajo, tocar la señal a mano tampoco lo enciende:
	# esconder un botón no es una garantía de nada.
	var flojo: Node = await _con_record(1)
	flojo.options_panel.mirror_toggled.emit()
	h.check("sin desbloquear, forzar el botón no hace nada", not flojo.session().mirror(), "")
	flojo.free()


## La gravedad tira hacia arriba. Se mide, no se lee la bandera.
func _la_gravedad_esta_del_reves() -> void:
	var normal: float = await _caida(false)
	var espejo: float = await _caida(true)
	h.check("del derecho, Flapo cae hacia abajo", normal > 20.0, "%.1f px" % normal)
	h.check("en espejo, cae hacia arriba", espejo < -20.0, "%.1f px" % espejo)
	h.check(
		"y exactamente lo mismo, del revés",
		is_equal_approx(normal, -espejo),
		"%.4f vs %.4f" % [normal, -espejo]
	)


## El aleteo empuja al otro lado.
func _el_aleteo_esta_del_reves() -> void:
	for espejo in [false, true]:
		var main: Node = await _montar_modo(espejo)
		h.jugar(main)
		main.bird.collision_mask = 0
		await h.ticks(2)
		# Se mira el PICO de velocidad durante unos frames en vez de un frame
		# concreto: cuándo exactamente ve el juego una pulsación inyectada es
		# un detalle del arnés, y clavar el frame haría que este test fallara
		# por un motivo que no es el que se está probando.
		var v: float = 0.0
		for i in 10:
			if i == 0:
				h.pulsa(KEY_SPACE)
			elif i == 1:
				h.pulsa(KEY_SPACE, false)
			await physics_frame
			if absf(main.bird.velocity.y) > absf(v):
				v = main.bird.velocity.y
		if espejo:
			h.check("en espejo el aleteo empuja hacia abajo", v > 0.0, "velocidad %.1f" % v)
		else:
			h.check("del derecho el aleteo empuja hacia arriba", v < 0.0, "velocidad %.1f" % v)
		main.free()


## En espejo, el techo es el suelo: te mata. Sin esto Flapo se quedaría
## pegado arriba para siempre, porque ahí no hay ningún cuerpo con el que
## chocar.
func _el_techo_mata_en_espejo() -> void:
	var main: Node = await _montar_modo(true)
	h.jugar(main)
	# Sin colisiones: así lo ÚNICO que puede matarle es el techo. Sin esto el
	# test no probaba nada — pegado al techo, Flapo choca con la parte alta de
	# la primera tubería y muere igual, con o sin muerte por techo. Se
	# comprobó rompiéndolo: el test seguía en verde.
	main.bird.collision_mask = 0
	var muerto: bool = false
	# Array y no un int: los lambdas de GDScript capturan por VALOR, así que
	# `causa = c` dentro de la lambda escribiría en una copia y aquí fuera se
	# leería siempre -1.
	var causa: Array = [-1]
	main.bird.died.connect(func(c: int, _s: bool) -> void: causa[0] = c)
	for tick in 400:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			muerto = true
			break
	h.check("en espejo, y sin nada con lo que chocar, el techo mata", muerto, "")
	h.check(
		"y cuenta como suelo: en espejo el techo ES el suelo",
		causa[0] == Bird.DeathCause.SUELO,
		"causa: %s" % ("ninguna" if causa[0] < 0 else Bird.DeathCause.keys()[causa[0]])
	)
	h.check(
		"y Flapo acaba arriba, no abajo",
		main.bird.position.y < GameConfig.playable_height() * 0.5,
		"y = %.1f" % main.bird.position.y
	)
	main.free()


## Criterio: el modo normal no cambia en nada.
func _el_modo_normal_no_cambia() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.check("premisa: se arranca del derecho", not main.session().mirror(), "")
	main.session().set_seed(999)
	h.jugar(main)
	main.bird.collision_mask = 0
	var trayectoria: Array = []
	for tick in 120:
		if tick % 25 == 0:
			h.pulsa(KEY_SPACE)
		elif tick % 25 == 1:
			h.pulsa(KEY_SPACE, false)
		await physics_frame
		trayectoria.append(snappedf(main.bird.position.y, 0.0001))
	main.free()

	# La misma partida con el espejo existiendo pero apagado tiene que dar la
	# misma trayectoria al milímetro.
	var otra: Node = await h.montar(MAIN, {"log_transitions": false})
	otra.session().set_seed(999)
	h.jugar(otra)
	otra.bird.collision_mask = 0
	var otra_trayectoria: Array = []
	for tick in 120:
		if tick % 25 == 0:
			h.pulsa(KEY_SPACE)
		elif tick % 25 == 1:
			h.pulsa(KEY_SPACE, false)
		await physics_frame
		otra_trayectoria.append(snappedf(otra.bird.position.y, 0.0001))
	otra.free()
	h.check("premisa: se ha volado de verdad", trayectoria.size() == 120, "")
	h.check(
		"con el espejo apagado, el vuelo de siempre es idéntico",
		trayectoria == otra_trayectoria,
		"primera diferencia en %d" % _primera_diferencia(trayectoria, otra_trayectoria)
	)


## Regla de ADR-0036: si cambia la partida, va al replay.
func _el_espejo_viaja_en_el_replay() -> void:
	var rep := Replay.new()
	rep.semilla = 55
	rep.espejo = true
	rep.score = 3
	rep.anotar(4, true)
	rep.anotar(9, false)
	h.check("premisa: se guarda", rep.guardar("user://espejo_prueba.replay"), "")
	var leido: Replay = Replay.cargar("user://espejo_prueba.replay")
	h.check("el replay se relee", leido != null, "")
	if leido != null:
		h.check("y trae el espejo puesto", leido.espejo, "")
	Replay.borrar("user://espejo_prueba.replay")


## Cuánto se desplaza Flapo en vertical soltándolo un segundo.
func _caida(espejo: bool) -> float:
	var main: Node = await _montar_modo(espejo)
	h.jugar(main)
	main.bird.collision_mask = 0
	await h.ticks(2)
	var antes: float = main.bird.position.y
	await h.ticks(30)
	var recorrido: float = main.bird.position.y - antes
	main.free()
	return recorrido


func _montar_modo(espejo: bool) -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	SaveManager.record_game(GameConfig.MIRROR_UNLOCK_SCORE)
	SaveManager.set_mirror(espejo)
	return await h.montar(MAIN, {"log_transitions": false})


func _con_record(record: int) -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	if record > 0:
		SaveManager.record_game(record)
	return await h.montar(MAIN, {"log_transitions": false})


func _primera_diferencia(a: Array, b: Array) -> int:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return i
	return -1
