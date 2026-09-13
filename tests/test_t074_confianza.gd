extends SceneTree
## T-074 — Progresión de confianza.
##
## Lo que se comprueba aquí es que la progresión es **pequeña, con tope,
## persistente y automática**: sube sola jugando, nunca baja, se para en el
## escalón 5 y sobrevive a un guardado ausente o corrupto sin impedir que el
## juego arranque. Ver ADR-0021.

const MAIN := "res://scenes/Main.tscn"
const RUTA := "user://save.cfg"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-074 · Confianza ---")
	_el_escalon_depende_de_las_partidas()
	_el_aliento_sube_poco_y_tiene_tope()
	_se_guarda_y_sobrevive_a_reabrir()
	_la_confianza_nunca_baja()
	await _sin_guardado_el_juego_arranca_igual()
	await _un_guardado_corrupto_no_rompe_el_arranque()
	await _main_aplica_la_confianza_desde_la_primera_partida()
	SaveManager.clear()
	quit(h.resumen("T-074"))


func _escribir_basura(contenido: String) -> void:
	SaveManager.clear()
	var f: FileAccess = FileAccess.open(RUTA, FileAccess.WRITE)
	f.store_string(contenido)
	f.close()
	SaveManager.forget_cache()


## Se cuentan partidas, no puntos: mejora quien insiste.
func _el_escalon_depende_de_las_partidas() -> void:
	h.check("con 0 partidas no hay confianza", GameConfig.confidence_level(0) == 0, "")
	h.check(
		"una partida antes del escalón todavía no cuenta",
		GameConfig.confidence_level(GameConfig.CONFIDENCE_STEP - 1) == 0,
		"nivel: %d" % GameConfig.confidence_level(GameConfig.CONFIDENCE_STEP - 1)
	)
	h.check(
		"al llegar a CONFIDENCE_STEP sube un escalón",
		GameConfig.confidence_level(GameConfig.CONFIDENCE_STEP) == 1,
		"nivel: %d" % GameConfig.confidence_level(GameConfig.CONFIDENCE_STEP)
	)
	var justo: int = GameConfig.CONFIDENCE_STEP * GameConfig.CONFIDENCE_MAX_LEVEL
	h.check(
		"el tope se alcanza en la partida esperada",
		GameConfig.confidence_level(justo) == GameConfig.CONFIDENCE_MAX_LEVEL,
		"partidas %d -> nivel %d" % [justo, GameConfig.confidence_level(justo)]
	)
	h.check(
		"y jugar 1000 partidas no lo pasa",
		GameConfig.confidence_level(1000) == GameConfig.CONFIDENCE_MAX_LEVEL,
		"nivel: %d" % GameConfig.confidence_level(1000)
	)


## Criterio: el tope está documentado en GameConfig y la mejora es pequeña.
func _el_aliento_sube_poco_y_tiene_tope() -> void:
	var base: float = GameConfig.max_breath_for(0)
	var tope: float = GameConfig.max_breath_for(GameConfig.CONFIDENCE_MAX_LEVEL)
	h.check(
		"sin confianza el aliento es el de siempre",
		is_equal_approx(base, GameConfig.MAX_BREATH),
		"%f" % base
	)
	h.check(
		"un escalón sube exactamente el bono",
		is_equal_approx(GameConfig.max_breath_for(1) - base, GameConfig.CONFIDENCE_BREATH_BONUS),
		"nivel 1: %f" % GameConfig.max_breath_for(1)
	)
	# El número concreto importa: si algún día alguien sube el bono "un poco",
	# este test le recuerda que la progresión deja de ser pequeña.
	var crecimiento: float = tope / base
	h.check(
		"el tope no llega ni a duplicar el aliento inicial",
		crecimiento < 1.5,
		"tope %f sobre base %f (x%.2f)" % [tope, base, crecimiento]
	)
	h.check(
		"pasarse del tope no da más aliento",
		is_equal_approx(GameConfig.max_breath_for(GameConfig.CONFIDENCE_MAX_LEVEL + 7), tope),
		"%f" % GameConfig.max_breath_for(GameConfig.CONFIDENCE_MAX_LEVEL + 7)
	)


## Criterio: persistido en el mismo ConfigFile, sobrevive a cerrar y abrir.
func _se_guarda_y_sobrevive_a_reabrir() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	for partida in GameConfig.CONFIDENCE_STEP - 1:
		SaveManager.record_game(0)
	h.check(
		"antes del escalón la confianza sigue a 0",
		SaveManager.get_confidence() == 0,
		"partidas %d, confianza %d" % [SaveManager.get_games_played(), SaveManager.get_confidence()]
	)
	SaveManager.record_game(0)
	h.check(
		"la partida que completa el escalón lo sube",
		SaveManager.get_confidence() == 1,
		"partidas %d, confianza %d" % [SaveManager.get_games_played(), SaveManager.get_confidence()]
	)
	# Simula cerrar y volver a abrir el juego.
	SaveManager.forget_cache()
	h.check(
		"y sobrevive a reabrir el juego",
		SaveManager.get_confidence() == 1,
		"confianza tras releer del disco: %d" % SaveManager.get_confidence()
	)
	h.check("guardada en el mismo fichero que el récord", FileAccess.file_exists(RUTA), RUTA)


## Una progresión que retrocede es lo único que un jugador no perdona.
func _la_confianza_nunca_baja() -> void:
	var guardado: String = "[progreso]"
	guardado += "\n" + "high_score=3"
	guardado += "\n" + "games_played=0"
	guardado += "\n" + "confidence=4" + "\n"
	_escribir_basura(guardado)
	h.check(
		"se lee la confianza guardada",
		SaveManager.get_confidence() == 4,
		"%d" % SaveManager.get_confidence()
	)
	SaveManager.record_game(0)
	h.check(
		"una partida con la cuenta a cero no la hace bajar",
		SaveManager.get_confidence() == 4,
		"confianza: %d" % SaveManager.get_confidence()
	)


## Criterio: la progresión no rompe el arranque sin fichero de guardado.
func _sin_guardado_el_juego_arranca_igual() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.check(
		"sin guardado, Main arranca con confianza 0",
		main.get_confidence() == 0,
		"%d" % main.get_confidence()
	)
	h.check(
		"y Flapo con el aliento de salida",
		is_equal_approx(main.bird.max_breath, GameConfig.MAX_BREATH),
		"max_breath: %f" % main.bird.max_breath
	)
	main.free()


## Criterio: fichero corrupto, igual que cubre SaveManager.
func _un_guardado_corrupto_no_rompe_el_arranque() -> void:
	_escribir_basura("[progreso\nconfidence=??? }}} ")
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.check(
		"con guardado corrupto, confianza 0",
		main.get_confidence() == 0,
		"%d" % main.get_confidence()
	)
	h.check(
		"y el juego llega al menú igualmente",
		main.get_state() == GameState.State.MENU,
		"estado: %d" % main.get_state()
	)
	# Y se puede jugar: lo importante no es leer 0, es que la partida arranque.
	h.jugar(main)
	await physics_frame
	h.check("y se puede empezar a jugar", main.get_state() == GameState.State.PLAYING, "")
	main.free()


## El bug que casi se cuela: `change_state(READY)` no hace nada si ya se está
## en READY, así que sin aplicarla en `_ready()` la confianza no llegaba a
## Flapo hasta después de la primera muerte.
func _main_aplica_la_confianza_desde_la_primera_partida() -> void:
	var partidas: int = GameConfig.CONFIDENCE_STEP * 3
	var guardado: String = "[progreso]"
	guardado += "\n" + "high_score=9"
	guardado += "\n" + "games_played=%d" % partidas
	guardado += "\n" + "confidence=3" + "\n"
	_escribir_basura(guardado)

	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	var esperado: float = GameConfig.max_breath_for(3)
	h.check(
		"Main lee la confianza guardada",
		main.get_confidence() == 3,
		"confianza: %d" % main.get_confidence()
	)
	h.check(
		"y Flapo tiene más aliento máximo ya en la primera partida",
		is_equal_approx(main.bird.max_breath, esperado),
		"max_breath %f, esperado %f" % [main.bird.max_breath, esperado]
	)
	h.jugar(main)
	await physics_frame
	h.check(
		"y arranca con la barra llena hasta el nuevo máximo",
		is_equal_approx(main.bird.breath(), esperado),
		"aliento %f de %f" % [main.bird.breath(), esperado]
	)

	# Y tras una vuelta completa sigue aplicada, no solo al montar. La vuelta
	# tiene que ser de verdad: `restart()` desde PLAYING es transición ilegal
	# y dejaría este check pasando sin haber pasado por READY.
	main.change_state(GameState.State.GAME_OVER)
	main.restart()
	await physics_frame
	h.check(
		"la partida ha vuelto de verdad a READY",
		main.get_state() == GameState.State.READY,
		"estado: %d" % main.get_state()
	)
	h.check(
		"y la confianza sigue aplicada tras reiniciar",
		is_equal_approx(main.bird.max_breath, esperado),
		"max_breath: %f" % main.bird.max_breath
	)
	main.free()
