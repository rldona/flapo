extends SceneTree
## T-242 — Semilla compartible.
##
## La promesa: dos amigos escriben el mismo código y juegan exactamente las
## mismas tuberías. Eso obliga a que el código sea **de ida y vuelta**, y ahí
## está el bug fácil de este ticket: enseñar un código que lleva a otra
## partida, sin que salte ningún error.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-242 · Semilla compartible ---")
	_el_codigo_es_de_ida_y_vuelta()
	_un_codigo_invalido_se_rechaza_sin_romper_nada()
	await _la_semilla_de_la_partida_libre_cabe_en_un_codigo()
	await _jugar_un_codigo_da_la_partida_de_ese_codigo()
	await _un_codigo_malo_deja_al_jugador_en_el_menu()
	await _el_codigo_va_en_el_texto_de_compartir()
	SaveManager.clear()
	quit(h.resumen("T-242"))


## Criterio: codificación y decodificación.
func _el_codigo_es_de_ida_y_vuelta() -> void:
	var fallos: Array = []
	for semilla in [0, 1, 35, 36, 1000, 20260908, GameConfig.codigo_modulo() - 1]:
		var c: String = GameConfig.seed_a_codigo(semilla)
		var vuelta: int = GameConfig.codigo_a_seed(c)
		if vuelta != semilla:
			fallos.append("%d -> '%s' -> %d" % [semilla, c, vuelta])
	h.check("toda semilla que cabe vuelve igual", fallos.is_empty(), "%s" % str(fallos))
	h.check(
		"el código mide lo que dice GameConfig",
		GameConfig.seed_a_codigo(1).length() == GameConfig.CODIGO_LARGO,
		"'%s'" % GameConfig.seed_a_codigo(1)
	)
	# Semillas distintas dan códigos distintos: si no, el código no
	# identificaría la partida.
	var vistos: Dictionary = {}
	var choques: int = 0
	for i in 2000:
		var c: String = GameConfig.seed_a_codigo(i)
		if vistos.has(c):
			choques += 1
		vistos[c] = true
	h.check("2000 semillas dan 2000 códigos distintos", choques == 0, "%d choques" % choques)
	# Se dicta por teléfono: mayúsculas y espacios no pueden importar.
	h.check(
		"da igual mayúsculas y espacios sobrantes",
		GameConfig.codigo_a_seed("  " + GameConfig.seed_a_codigo(777).to_upper() + " ") == 777,
		""
	)


## Criterio: un código inválido no rompe nada.
func _un_codigo_invalido_se_rechaza_sin_romper_nada() -> void:
	var malos: Array = ["", "abc", "abcdefgh", "!!!!!", "12 34", "ñññññ"]
	var colados: Array = []
	for c in malos:
		if GameConfig.codigo_a_seed(c) >= 0:
			colados.append(c)
	h.check("los códigos imposibles se rechazan", colados.is_empty(), "%s" % str(colados))
	# Y uno bueno no se rechaza: sin esto, un decodificador que dijera "no"
	# a todo pasaría el caso de arriba.
	h.check(
		"pero uno bueno se acepta",
		GameConfig.codigo_a_seed(GameConfig.seed_a_codigo(4242)) == 4242,
		""
	)


## El bug fácil: si la semilla sorteada no cupiera en el código, el código
## que se enseña llevaría a otra partida y nadie se enteraría.
func _la_semilla_de_la_partida_libre_cabe_en_un_codigo() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var fallos: Array = []
	for intento in 5:
		var main: Node = await h.montar(MAIN, {"log_transitions": false})
		main.start_free()
		await h.ticks(1)
		var s: int = main.session().seed()
		if GameConfig.codigo_a_seed(GameConfig.seed_a_codigo(main.session().seed())) != s:
			fallos.append(
				"semilla %d -> '%s'" % [s, GameConfig.seed_a_codigo(main.session().seed())]
			)
		main.free()
	h.check(
		"la semilla de una partida libre siempre cabe en su código",
		fallos.is_empty(),
		"%s" % str(fallos)
	)


## La promesa entera: el mismo código, las mismas tuberías.
func _jugar_un_codigo_da_la_partida_de_ese_codigo() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	# Se juega una partida libre, se apunta su código y se vuelve a jugar
	# escribiéndolo: es exactamente lo que hacen dos amigos.
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.fruit_spawner.chance = 0.0
	main.start_free()
	var codigo: String = GameConfig.seed_a_codigo(main.session().seed())
	var original: Array = await _secuencia(main)
	main.free()

	var otro: Node = await h.montar(MAIN, {"log_transitions": false})
	otro.fruit_spawner.chance = 0.0
	h.check("premisa: el código se acepta", otro.start_code(codigo), "'%s'" % codigo)
	var copia: Array = await _secuencia(otro)
	otro.free()

	h.check("premisa: se han generado tuberías", original.size() > 2, "%d" % original.size())
	h.check(
		"el mismo código da las mismas tuberías",
		original == copia,
		"%s vs %s" % [str(original), str(copia)]
	)

	# Y un código distinto da otra partida: si no, el test se cumpliría solo.
	var tercero: Node = await h.montar(MAIN, {"log_transitions": false})
	tercero.fruit_spawner.chance = 0.0
	tercero.start_code(GameConfig.seed_a_codigo(GameConfig.codigo_a_seed(codigo) + 1))
	var distinta: Array = await _secuencia(tercero)
	tercero.free()
	h.check("y un código distinto da otra partida", original != distinta, "iguales")


## Criterio: un código inválido no rompe nada, aviso corto y se queda en el
## menú.
func _un_codigo_malo_deja_al_jugador_en_el_menu() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.check("premisa: se empieza en el menú", main.get_state() == GameState.State.MENU, "")

	main.menu_panel.code_pressed.emit("!!!!!")
	await h.ticks(2)
	h.check(
		"un código malo no saca del menú",
		main.get_state() == GameState.State.MENU,
		"estado: %d" % main.get_state()
	)
	h.check("y avisa", main.menu_panel.aviso() != "", "'%s'" % main.menu_panel.aviso())

	# Y uno bueno sí arranca, y borra el aviso.
	main.menu_panel.code_pressed.emit(GameConfig.seed_a_codigo(1234))
	await h.ticks(2)
	h.check(
		"uno bueno sí arranca la partida",
		main.get_state() == GameState.State.READY,
		"estado: %d" % main.get_state()
	)
	main.free()


## Criterio: el código va en el texto de compartir.
func _el_codigo_va_en_el_texto_de_compartir() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.start_code(GameConfig.seed_a_codigo(4242))
	main.change_state(GameState.State.PLAYING)
	main._on_scored()
	main._on_bird_died(Bird.DeathCause.SUELO, false)
	await h.ticks(2)
	var textos: Array = []
	main.game_over_panel.share_pressed.connect(func(t: String) -> void: textos.append(t))
	main.game_over_panel._on_share_pressed()
	h.check("compartir emite un texto", textos.size() == 1, "%d" % textos.size())
	if textos.size() == 1:
		h.check(
			"y lleva el código de la partida",
			(textos[0] as String).contains(GameConfig.seed_a_codigo(4242)),
			"'%s'" % textos[0]
		)
	# En el reto NO va código: el reto ya se identifica por su fecha, y dos
	# identificadores para la misma partida solo confunden.
	main.restart()
	main.start_daily([2026, 9, 8])
	main.change_state(GameState.State.PLAYING)
	main._on_bird_died(Bird.DeathCause.SUELO, false)
	await h.ticks(2)
	textos.clear()
	main.game_over_panel._on_share_pressed()
	h.check(
		"en el reto se comparte la fecha, no un código",
		textos.size() == 1 and (textos[0] as String).contains("septiembre"),
		"'%s'" % ("" if textos.is_empty() else textos[0])
	)
	main.free()


func _secuencia(main: Node) -> Array:
	main.change_state(GameState.State.PLAYING)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	var vistas: Dictionary = {}
	var orden: Array = []
	for tick in 360:
		await physics_frame
		for hijo in main.pipe_spawner.get_children():
			if hijo is Pipe and not vistas.has(hijo.get_instance_id()):
				vistas[hijo.get_instance_id()] = true
				orden.append(snappedf((hijo as Pipe).get_base_gap_center(), 0.01))
	return orden
