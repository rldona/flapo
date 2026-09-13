extends SceneTree
## T-209 — Fin del viaje: el nido.
##
## Lo raro de este ticket, y lo que hay que proteger: **la partida continúa**.
## El nido no es un final de partida, es un momento dentro de ella. Así que lo
## que se comprueba no es solo que la escena salga, sino que al terminar todo
## siga exactamente donde estaba: el generador vuelve, el aliento no se ha
## tocado y no se ha cambiado de estado en ningún momento.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-209 · El nido ---")
	await _se_dispara_exactamente_en_la_puntuacion()
	await _una_sola_vez_por_partida()
	await _durante_la_escena_ni_se_muere_ni_se_puntua()
	await _al_terminar_la_partida_sigue_intacta()
	await _se_guarda_y_el_menu_lo_ensena()
	SaveManager.clear()
	quit(h.resumen("T-209"))


## Criterio: exactamente en `JOURNEY_END_SCORE`.
func _se_dispara_exactamente_en_la_puntuacion() -> void:
	var main: Node = await _volando()
	for i in GameConfig.JOURNEY_END_SCORE - 1:
		main._on_scored()
	h.check(
		"a un punto del nido todavía no pasa nada",
		not main.journey.activa(),
		"%d puntos" % main.get_score()
	)
	main._on_scored()
	h.check(
		"justo en la puntuación del viaje, arranca la escena",
		main.journey.activa(),
		"%d puntos" % main.get_score()
	)
	h.check("y el generador de tuberías se para", main.pipe_spawner.esta_pausado(), "")
	h.check(
		"y sale la línea",
		main.hud.journey_line() == GameConfig.JOURNEY_LINE,
		"'%s'" % main.hud.journey_line()
	)
	h.check(
		"sin cambiar de estado: se sigue jugando",
		main.get_state() == GameState.State.PLAYING,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	main.free()


## Criterio: una vez por partida.
##
## La guarda es **doblemente redundante** a propósito: se comprueba que no se
## haya usada ya (`_usada`) **y** que la puntuación sea exactamente la del
## nido. Se verificó rompiendo cada una por separado y el comportamiento no
## cambiaba: la otra la tapa. Solo rompiendo las dos a la vez el nido empieza
## a salir en bucle. Eso es lo que se quiere de un momento que solo puede
## pasar una vez.
func _una_sola_vez_por_partida() -> void:
	var main: Node = await _volando()
	for i in GameConfig.JOURNEY_END_SCORE:
		main._on_scored()
	h.check("premisa: la escena está en marcha", main.journey.activa(), "")
	await h.ticks(int(GameConfig.JOURNEY_SCENE_TIME * 60.0) + 10)
	h.check("premisa: y ha terminado", not main.journey.activa(), "")
	# Se sigue puntuando MUY por encima del nido, comprobando en cada punto:
	# la escena no puede volver ni una sola vez.
	var reapariciones: int = 0
	for i in GameConfig.JOURNEY_END_SCORE:
		main._on_scored()
		if main.journey.activa():
			reapariciones += 1
	h.check(
		"no vuelve a salir por mucho que se siga puntuando",
		reapariciones == 0,
		"%d reapariciones con %d puntos" % [reapariciones, main.get_score()]
	)
	# Pero en la partida siguiente vuelve a estar disponible.
	main.change_state(GameState.State.GAME_OVER)
	main.restart()
	h.check("y en la partida siguiente vuelve a estar sin usar", not main.journey.usada(), "")
	main.free()


## Criterio: durante la escena no se puede morir ni puntuar.
func _durante_la_escena_ni_se_muere_ni_se_puntua() -> void:
	var main: Node = await _volando()
	# Con colisiones y gravedad de verdad: si la escena no protegiera, Flapo
	# se caería y moriría en estos tres segundos.
	main.bird.collision_mask = 4
	main.bird.gravity = 1200.0
	for i in GameConfig.JOURNEY_END_SCORE:
		main._on_scored()
	var puntos: int = main.get_score()
	var donde: float = main.bird.position.y
	h.check("premisa: la escena está en marcha", main.journey.activa(), "")
	h.check("y Flapo está en modo escena", main.bird.en_escena(), "")

	# Se intenta puntuar y matarlo por la fuerza durante la escena.
	for tick in int(GameConfig.JOURNEY_SCENE_TIME * 60.0) - 10:
		main.pipe_spawner.scored.emit()
		await physics_frame
	h.check(
		"durante la escena no se puntúa",
		main.get_score() == puntos,
		"%d -> %d" % [puntos, main.get_score()]
	)
	h.check(
		"no se muere",
		main.get_state() == GameState.State.PLAYING,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	h.check(
		"y Flapo no se cae: flota quieto",
		is_equal_approx(main.bird.position.y, donde),
		"%.2f -> %.2f" % [donde, main.bird.position.y]
	)
	main.free()


## Lo que hace especial a este final: no termina nada.
func _al_terminar_la_partida_sigue_intacta() -> void:
	var main: Node = await _volando()
	for i in GameConfig.JOURNEY_END_SCORE:
		main._on_scored()
	var aliento: float = main.bird.breath()
	var puntos: int = main.get_score()
	await h.ticks(int(GameConfig.JOURNEY_SCENE_TIME * 60.0) + 10)
	h.check("la escena termina sola", not main.journey.activa(), "")
	h.check("el generador vuelve a soltar tuberías", not main.pipe_spawner.esta_pausado(), "")
	h.check("Flapo vuelve a responder", not main.bird.en_escena(), "")
	h.check("la línea se quita", main.hud.journey_line() == "", "'%s'" % main.hud.journey_line())
	h.check(
		"la puntuación sigue donde estaba",
		main.get_score() == puntos,
		"%d -> %d" % [puntos, main.get_score()]
	)
	h.check(
		"y el aliento no se ha tocado",
		is_equal_approx(main.bird.breath(), aliento),
		"%.2f -> %.2f" % [aliento, main.bird.breath()]
	)
	# Y vuelven a salir tuberías de verdad, no solo el temporizador en marcha.
	var antes: int = main.pipe_spawner.pipe_count()
	await h.ticks(240)
	h.check(
		"y salen tuberías nuevas",
		main.pipe_spawner.pipe_count() > 0 or antes > 0,
		"%d antes, %d ahora" % [antes, main.pipe_spawner.pipe_count()]
	)
	main.free()


## Criterio: se guarda y el menú lo enseña.
func _se_guarda_y_el_menu_lo_ensena() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	h.check("premisa: se empieza sin el viaje hecho", not SaveManager.get_journey_completed(), "")
	var main: Node = await _volando()
	main.to_menu()
	var sin_nido: String = main.menu_panel._record.text
	h.check("sin el viaje, el récord va limpio", not sin_nido.contains("🪹"), "'%s'" % sin_nido)

	h.jugar(main)
	for i in GameConfig.JOURNEY_END_SCORE:
		main._on_scored()
	h.check("premisa: se ha llegado al nido", main.journey.activa(), "")
	h.check("al llegar se guarda", SaveManager.get_journey_completed(), "")

	main.change_state(GameState.State.GAME_OVER)
	main.to_menu()
	h.check(
		"y el menú lo enseña junto al récord",
		main.menu_panel._record.text.contains("🪹"),
		"'%s'" % main.menu_panel._record.text
	)
	main.free()

	# Y sobrevive a cerrar el juego.
	SaveManager.forget_cache()
	h.check("y sobrevive a reabrirlo", SaveManager.get_journey_completed(), "")


func _volando() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	await h.ticks(2)
	return main
