extends SceneTree
## T-241 — Reto del día.
##
## La promesa: todo el mundo juega las mismas tuberías ese día, sin servidor.
## Se apoya entera en T-240, así que aquí lo que se comprueba es la parte
## nueva: que **la semilla sale solo de la fecha**, que **cambia al día
## siguiente** y que **la marca del reto no toca el récord general**.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-241 · Reto del día ---")
	_la_semilla_sale_solo_de_la_fecha()
	await _dos_arranques_el_mismo_dia_dan_la_misma_partida()
	await _al_dia_siguiente_cambia()
	await _el_reto_no_toca_el_record_general()
	await _el_reto_no_cambia_las_reglas()
	await _el_texto_de_compartir_dice_el_dia()
	SaveManager.clear()
	quit(h.resumen("T-241"))


## Criterio: derivada SOLO de la fecha local.
func _la_semilla_sale_solo_de_la_fecha() -> void:
	h.check(
		"la semilla es la fecha legible, AAAAMMDD",
		GameConfig.daily_seed(2026, 9, 8) == 20260908,
		"%d" % GameConfig.daily_seed(2026, 9, 8)
	)
	var vistas: Dictionary = {}
	var choques: Array = []
	for mes in range(1, 13):
		for dia in range(1, 29):
			var s: int = GameConfig.daily_seed(2026, mes, dia)
			if vistas.has(s):
				choques.append("%d/%d" % [dia, mes])
			vistas[s] = true
	h.check(
		"y días distintos dan semillas distintas, en un año entero",
		choques.is_empty(),
		"%s" % str(choques)
	)
	h.check(
		"la clave de guardado también sale de la fecha",
		GameConfig.daily_key(2026, 9, 8) == "daily_20260908",
		GameConfig.daily_key(2026, 9, 8)
	)
	h.check(
		"y el nombre se lee en castellano",
		GameConfig.daily_name(9, 8) == "8 de septiembre",
		GameConfig.daily_name(9, 8)
	)
	# Un mes imposible no puede reventar el texto de compartir.
	h.check(
		"un mes imposible no rompe el nombre",
		GameConfig.daily_name(0, 3) != "",
		GameConfig.daily_name(0, 3)
	)


## Criterio: dos arranques el mismo día dan la misma partida.
func _dos_arranques_el_mismo_dia_dan_la_misma_partida() -> void:
	var a: Array = await _secuencia_del_reto([2026, 9, 8])
	var b: Array = await _secuencia_del_reto([2026, 9, 8])
	h.check("premisa: se han generado tuberías", a.size() > 2, "%d" % a.size())
	h.check(
		"dos arranques el mismo día dan la misma partida", a == b, "%s vs %s" % [str(a), str(b)]
	)


## Criterio: y cambia al día siguiente.
func _al_dia_siguiente_cambia() -> void:
	var hoy: Array = await _secuencia_del_reto([2026, 9, 8])
	var manana: Array = await _secuencia_del_reto([2026, 9, 9])
	h.check("al día siguiente el reto es otro", hoy != manana, "iguales")


## Criterio: el récord general no se mezcla con el del reto.
func _el_reto_no_toca_el_record_general() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.fruit_spawner.chance = 0.0

	# Primero una partida normal, para tener un récord que proteger.
	main.start_free()
	main.change_state(GameState.State.PLAYING)
	for punto in 4:
		main._on_scored()
	_morir(main)
	await h.ticks(2)
	h.check(
		"premisa: hay récord general",
		SaveManager.get_high_score() == 4,
		"%d" % SaveManager.get_high_score()
	)

	# Ahora un reto con MÁS puntos: no puede subir el récord general.
	main.restart()
	main.start_daily([2026, 9, 8])
	main.change_state(GameState.State.PLAYING)
	for punto in 9:
		main._on_scored()
	_morir(main)
	await h.ticks(2)
	h.check(
		"una buena marca en el reto NO sube el récord general",
		SaveManager.get_high_score() == 4,
		"récord general: %d" % SaveManager.get_high_score()
	)
	h.check(
		"pero sí se guarda en la clave del reto",
		SaveManager.get_daily_best(GameConfig.daily_key(2026, 9, 8)) == 9,
		"%d" % SaveManager.get_daily_best(GameConfig.daily_key(2026, 9, 8))
	)
	# Y al revés: el reto de otro día es otra clave.
	h.check(
		"el reto de otro día empieza a cero",
		SaveManager.get_daily_best(GameConfig.daily_key(2026, 9, 9)) == 0,
		""
	)
	# La partida cuenta como jugada aunque sea un reto: si no, jugar retos no
	# haría avanzar la confianza de T-074 y sería una trampa al revés.
	h.check(
		"pero la partida sí cuenta como jugada",
		SaveManager.get_games_played() == 2,
		"%d partidas" % SaveManager.get_games_played()
	)
	# Y el histórico sale solo de las claves, sin lista que mantener.
	h.check(
		"el histórico recoge el reto jugado",
		SaveManager.get_daily_history().size() == 1,
		"%s" % str(SaveManager.get_daily_history())
	)
	main.free()


## Criterio: modo y frutas no cambian respecto al juego normal.
func _el_reto_no_cambia_las_reglas() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.options_panel.difficulty_selected.emit(GameConfig.Difficulty.DIFICIL)
	var chance_antes: float = main.fruit_spawner.chance
	main.start_daily([2026, 9, 8])
	await h.ticks(2)
	h.check(
		"el reto respeta el modo de dificultad elegido",
		main.session().difficulty() == GameConfig.Difficulty.DIFICIL,
		"%d" % main.session().difficulty()
	)
	h.check(
		"y no toca las frutas",
		is_equal_approx(main.fruit_spawner.chance, chance_antes),
		"%.2f vs %.2f" % [main.fruit_spawner.chance, chance_antes]
	)
	h.check("y se sabe que se está en el reto", main.session().daily.activo(), "")
	# Volver al juego normal lo apaga y vuelve a sortear semilla.
	main.change_state(GameState.State.PLAYING)
	main.change_state(GameState.State.GAME_OVER)
	main.start_free()
	await h.ticks(2)
	h.check("volver a Jugar sale del reto", not main.session().daily.activo(), "")
	h.check(
		"y con semilla propia, no la de la fecha",
		main.session().seed() != GameConfig.daily_seed(2026, 9, 8),
		"%d" % main.session().seed()
	)
	main.free()


## El texto de compartir tiene que decir de qué día era el reto: sin eso,
## comparar marcas no significa nada.
func _el_texto_de_compartir_dice_el_dia() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.start_daily([2026, 9, 8])
	main.change_state(GameState.State.PLAYING)
	for punto in 14:
		main._on_scored()
	_morir(main)
	await h.ticks(2)
	var textos: Array = []
	main.game_over_panel.share_pressed.connect(func(t: String) -> void: textos.append(t))
	main.game_over_panel._on_share_pressed()
	h.check("compartir emite un texto", textos.size() == 1, "%d" % textos.size())
	if textos.size() == 1:
		var t: String = textos[0]
		h.check("y dice de qué día era el reto", t.contains("8 de septiembre"), "'%s'" % t)
		h.check("y la marca", t.contains("14"), "'%s'" % t)
	main.free()


## La secuencia de tuberías del reto de esa fecha.
func _secuencia_del_reto(fecha: Array) -> Array:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.fruit_spawner.chance = 0.0
	main.start_daily(fecha)
	main.change_state(GameState.State.PLAYING)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	var vistas: Dictionary = {}
	var orden: Array = []
	for tick in 420:
		await physics_frame
		for hijo in main.pipe_spawner.get_children():
			if hijo is Pipe and not vistas.has(hijo.get_instance_id()):
				vistas[hijo.get_instance_id()] = true
				orden.append(snappedf((hijo as Pipe).get_base_gap_center(), 0.01))
	main.free()
	return orden


## Mata a Flapo por la ruta de verdad.
##
## `change_state(GAME_OVER)` a pelo NO vale: se salta `_on_bird_died`, que es
## quien guarda la partida. Un test que lo usara comprobaría el guardado de
## una partida que nunca se registró.
func _morir(main: Node) -> void:
	main._on_bird_died(Bird.DeathCause.SUELO, false)
