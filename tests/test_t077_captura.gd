extends SceneTree
## T-077 — Captura del mejor salto.
##
## El criterio explícito del ticket es **cuándo** se dispara: solo al superar
## el récord, no en cualquier Game Over. Eso se puede contar sin ventana, y es
## lo que más se protege aquí.
##
## Lo demás —que la imagen salga, que tenga el tamaño que toca y que dibuje el
## vuelo y no una foto fija— también se comprueba, y se puede **porque la
## imagen se compone a mano en vez de leer el framebuffer**. Con
## `Viewport.get_texture()` este fichero no existiría: en headless no hay
## render (ADR-0039).

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-077 · Captura del mejor salto ---")
	await _no_se_captura_en_un_game_over_cualquiera()
	await _se_captura_al_superar_el_record()
	await _la_estela_son_los_ultimos_segundos()
	await _la_imagen_sale_y_tiene_el_tamano_que_toca()
	await _la_imagen_cuenta_un_vuelo_no_un_instante()
	_borrar()
	SaveManager.clear()
	quit(h.resumen("T-077"))


func _borrar() -> void:
	if FileAccess.file_exists(Snapshot.RUTA):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Snapshot.RUTA))


## El criterio explícito: en un Game Over normal ni se pide.
func _no_se_captura_en_un_game_over_cualquiera() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	SaveManager.record_game(30)
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	await h.ticks(60)
	main._on_scored()
	h.check(
		"premisa: se muere por debajo del récord",
		main.get_score() < main.get_high_score(),
		"%d puntos, récord %d" % [main.get_score(), main.get_high_score()]
	)
	main._on_bird_died(Bird.DeathCause.SUELO, false)
	h.check("premisa: no ha sido récord", not main.is_new_high_score(), "")
	h.check(
		"en un Game Over normal no se pide ninguna captura",
		main.snapshot.pedidas() == 0,
		"%d pedidas" % main.snapshot.pedidas()
	)
	main.free()


## Y el contrario, que es lo que evita un test que se cumple solo.
func _se_captura_al_superar_el_record() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	_borrar()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	await h.ticks(60)
	main._on_scored()
	main._on_bird_died(Bird.DeathCause.SUELO, false)
	h.check("premisa: ha sido récord", main.is_new_high_score(), "")
	h.check(
		"al superar el récord se pide la captura",
		main.snapshot.pedidas() == 1,
		"%d pedidas" % main.snapshot.pedidas()
	)
	h.check(
		"y se hace",
		main.snapshot.hechas() == 1,
		"%d hechas de %d pedidas" % [main.snapshot.hechas(), main.snapshot.pedidas()]
	)
	h.check("y deja el fichero", FileAccess.file_exists(Snapshot.RUTA), Snapshot.RUTA)
	main.free()


## La estela son los últimos segundos, no la partida entera: si creciera sin
## fin, una partida larga se llevaría por delante la memoria del móvil.
func _la_estela_son_los_ultimos_segundos() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	await h.ticks(30)
	var pocas: int = main.snapshot.estela().size()
	await h.ticks(600)
	var muchas: int = main.snapshot.estela().size()
	h.check("premisa: se ha grabado algo", pocas > 0, "%d muestras" % pocas)
	h.check(
		"la estela no crece con la partida",
		muchas <= GameConfig.SNAPSHOT_SAMPLES,
		"%d muestras tras 10 s, tope %d" % [muchas, GameConfig.SNAPSHOT_SAMPLES]
	)
	h.check(
		"y llega a llenarse",
		muchas == GameConfig.SNAPSHOT_SAMPLES,
		"%d de %d" % [muchas, GameConfig.SNAPSHOT_SAMPLES]
	)
	# Al volver a READY se olvida: la captura es de ESTA partida.
	main.change_state(GameState.State.GAME_OVER)
	main.restart()
	h.check("y al empezar otra partida se vacía", main.snapshot.estela().is_empty(), "")
	main.free()


func _la_imagen_sale_y_tiene_el_tamano_que_toca() -> void:
	_borrar()
	var main: Node = await _volar_y_batir_el_record()
	var img := Image.new()
	var err: Error = img.load(Snapshot.RUTA)
	h.check("la imagen se puede abrir", err == OK, "error %d" % err)
	if err == OK:
		# Contra números concretos y no contra `SNAPSHOT_SCALE`: comparar la
		# imagen con la constante que la generó no comprueba nada, los dos
		# lados se mueven juntos. Lo que importa para compartir es que NO sea
		# una miniatura de 288 px, que en cualquier red se ve borrosa.
		h.check(
			"la imagen es bastante mayor que el playfield",
			(
				img.get_width() >= GameConfig.VIEWPORT_SIZE.x * 2
				and img.get_height() >= GameConfig.VIEWPORT_SIZE.y * 2
			),
			(
				"%dx%d, playfield %dx%d"
				% [
					img.get_width(),
					img.get_height(),
					GameConfig.VIEWPORT_SIZE.x,
					GameConfig.VIEWPORT_SIZE.y
				]
			)
		)
		# Y múltiplo entero: media escala convierte el pixel art en papilla.
		h.check(
			"y a una escala entera del playfield",
			(
				img.get_width() % GameConfig.VIEWPORT_SIZE.x == 0
				and img.get_height() % GameConfig.VIEWPORT_SIZE.y == 0
			),
			"%dx%d" % [img.get_width(), img.get_height()]
		)
		h.check(
			"con la proporción del juego intacta",
			(
				img.get_width() * GameConfig.VIEWPORT_SIZE.y
				== img.get_height() * GameConfig.VIEWPORT_SIZE.x
			),
			"%dx%d" % [img.get_width(), img.get_height()]
		)
	main.free()


## Lo que la hace útil para compartir: que se vea el arco del vuelo y no un
## Flapo suelto sobre un fondo liso.
func _la_imagen_cuenta_un_vuelo_no_un_instante() -> void:
	var main: Node = await _volar_y_batir_el_record()
	var estela: Array = main.snapshot.estela()
	h.check("premisa: hay varias muestras", estela.size() >= 3, "%d" % estela.size())
	var alturas: Array = []
	for m in estela:
		alturas.append(snappedf(m["y"], 0.01))
	h.check(
		"y Flapo no está en el mismo sitio en todas: hay vuelo que contar",
		alturas.min() != alturas.max(),
		"%s" % str(alturas)
	)

	var img := Image.new()
	if img.load(Snapshot.RUTA) == OK:
		var colores: Dictionary = {}
		for y in range(0, img.get_height(), 7):
			for x in range(0, img.get_width(), 7):
				colores[img.get_pixel(x, y).to_html(false)] = true
		h.check(
			"la imagen no es un rectángulo de un solo color",
			colores.size() >= 3,
			"%d colores distintos" % colores.size()
		)
	main.free()


func _volar_y_batir_el_record() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	main.bird.collision_mask = 0
	for tick in 200:
		if tick % 20 == 0:
			h.pulsa(KEY_SPACE)
		elif tick % 20 == 1:
			h.pulsa(KEY_SPACE, false)
		await physics_frame
	if main.get_score() == 0:
		main._on_scored()
	main._on_bird_died(Bird.DeathCause.SUELO, false)
	return main
