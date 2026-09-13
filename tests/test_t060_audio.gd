extends SceneTree
## T-060 y T-061 — Efectos de sonido, buses y silencio persistente.

const MAIN := "res://scenes/Main.tscn"

var h: Harness
## Los lambdas capturan las locales por valor (docs/testing.md), así que el
## contador tiene que ser un miembro.
var _flapeos: int = 0


func _init() -> void:
	h = Harness.new(self)
	print("--- T-060/T-061 · Audio ---")
	_buses_separados()
	await _cada_efecto_tiene_su_reproductor()
	await _en_ready_no_aletea()
	await _los_eventos_suenan()
	await _el_silencio_persiste()
	await _el_silencio_sobrevive_al_reinicio()
	Settings.clear()
	SaveManager.clear()
	quit(h.resumen("T-060/T-061"))


func _partida() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 17
	return main


## Criterio de T-061: buses SFX y Music separados.
func _buses_separados() -> void:
	for bus in ["Master", "SFX", "Music"]:
		h.check(
			"existe el bus %s" % bus,
			AudioServer.get_bus_index(bus) >= 0,
			"índice %d" % AudioServer.get_bus_index(bus)
		)


## Un reproductor por efecto: compartir uno haría que un aleteo cortara el
## sonido del punto, y es justo cuando más se solapan.
func _cada_efecto_tiene_su_reproductor() -> void:
	var main: Node = await _partida()
	for nombre in ["Flap", "Point", "Hit", "Fall", "Button"]:
		var p: AudioStreamPlayer = main.audio.get_node_or_null(nombre)
		h.check(
			"%s tiene reproductor y sonido" % nombre,
			p != null and p.stream != null and p.bus == &"SFX",
			"bus: %s" % ("-" if p == null else str(p.bus))
		)
	main.free()


## Los sonidos se disparan desde los eventos del juego, no desde la entrada:
## así un aleteo que no mueve a Flapo (en READY) tampoco suena.
## El sonido del aleteo cuelga de `Bird.flapped`, que solo se emite jugando.
##
## Se prueba con un Bird suelto y no dentro de Main: dentro, pulsar en READY
## arranca la partida y entonces Flapo sí aletea —que es lo que hace el
## Flappy original—, así que el estado cambiaría antes de poder medirlo.
func _en_ready_no_aletea() -> void:
	var bird: Node = load("res://scenes/Bird.tscn").instantiate()
	root.add_child(bird)
	await process_frame
	bird.flapped.connect(_on_flapped)
	_flapeos = 0

	bird.on_game_state_changed(GameState.State.READY)
	h.pulsa(KEY_SPACE)
	await h.ticks(5)
	h.pulsa(KEY_SPACE, false)
	await h.ticks(2)
	h.check("en READY Flapo no aletea", _flapeos == 0, "aleteos: %d" % _flapeos)

	bird.on_game_state_changed(GameState.State.PLAYING)
	h.pulsa(KEY_SPACE)
	await h.ticks(3)
	h.pulsa(KEY_SPACE, false)
	await h.ticks(2)
	h.check("jugando sí aletea", _flapeos == 1, "aleteos: %d" % _flapeos)
	bird.free()


func _on_flapped() -> void:
	_flapeos += 1


func _los_eventos_suenan() -> void:
	var main: Node = await _partida()
	var flap: AudioStreamPlayer = main.audio.get_node("Flap")
	var point: AudioStreamPlayer = main.audio.get_node("Point")
	var hit: AudioStreamPlayer = main.audio.get_node("Hit")

	h.jugar(main)
	h.pulsa(KEY_SPACE)
	await h.ticks(3)
	h.pulsa(KEY_SPACE, false)
	h.check("jugando, aletear suena", flap.playing, "")

	main._on_scored()
	await h.ticks(1)
	h.check("puntuar suena", point.playing, "")

	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	h.check("morir suena", hit.playing, "")
	main.free()


## Criterio de T-061: el mute sobrevive a cerrar y abrir el juego.
func _el_silencio_persiste() -> void:
	Settings.clear()
	Settings.forget_cache()
	var main: Node = await _partida()
	h.check("arranca con sonido", not main.audio.is_muted(), "")

	main._on_mute_pressed()
	h.check(
		"al silenciar, el bus SFX queda mudo",
		AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),
		""
	)
	h.check(
		"y el de música también", AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), ""
	)
	h.check(
		"y los botones lo reflejan",
		main.pause_panel.get_node("Root/Box/MuteButton").text.contains("no"),
		"texto: '%s'" % main.pause_panel.get_node("Root/Box/MuteButton").text
	)
	main.free()

	# Simula cerrar y volver a abrir el juego.
	Settings.forget_cache()
	var otra: Node = await _partida()
	h.check("el silencio sobrevive a reabrir", otra.audio.is_muted(), "")
	h.check(
		"y se aplica al bus nada más arrancar",
		AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),
		""
	)
	otra._on_mute_pressed()
	h.check("y se puede volver a activar", not otra.audio.is_muted(), "")
	otra.free()


## Un ajuste no es estado de partida: reiniciar no debe tocarlo.
func _el_silencio_sobrevive_al_reinicio() -> void:
	Settings.clear()
	Settings.forget_cache()
	var main: Node = await _partida()
	main._on_mute_pressed()
	h.jugar(main)
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	main.restart()
	await h.ticks(2)
	h.check("reiniciar no quita el silencio", main.audio.is_muted(), "")
	h.check("y el bus sigue mudo", AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "")
	main.free()
