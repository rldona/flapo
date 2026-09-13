extends SceneTree
## T-261 — Replay determinista.
##
## La promesa es fuerte: **un bug reportado con su replay se reproduce sin que
## nadie tenga que jugar**. Así que el test no comprueba que el fichero se
## escriba y se lea; comprueba que **volver a jugarlo da la misma partida**,
## contra un replay de referencia versionado en `tests/fixtures/` que no
## cambia nunca.
##
## Y comprueba lo contrario, que es igual de importante: si se cambia la
## semilla, el modo o la confianza del fichero, la partida deja de cuadrar.
## Sin ese caso, un reproductor que ignorase el fichero entero y jugase
## siempre igual pasaría el test anterior tan tranquilo.

const MAIN := "res://scenes/Main.tscn"
const REFERENCIA := "res://tests/fixtures/referencia.replay"
const PRUEBA := "user://replay_prueba.replay"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-261 · Replay determinista ---")
	_un_fichero_roto_no_da_replay()
	await _el_replay_de_referencia_se_reproduce()
	await _cambiar_el_fichero_cambia_la_partida()
	await _la_partida_se_graba_sola_al_morir()
	await _la_pausa_guarda_una_copia()
	Replay.borrar()
	Replay.borrar(PRUEBA)
	SaveManager.clear()
	quit(h.resumen("T-261"))


func _escribir(bytes: PackedByteArray) -> void:
	var f: FileAccess = FileAccess.open(PRUEBA, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


## Mismo trato que `SaveManager` y que el fantasma: nunca reventar.
func _un_fichero_roto_no_da_replay() -> void:
	Replay.borrar(PRUEBA)
	h.check("un fichero que no existe no da replay", Replay.cargar(PRUEBA) == null, "")
	_escribir("esto es texto, no un replay".to_utf8_buffer())
	h.check("un fichero de basura tampoco", Replay.cargar(PRUEBA) == null, "")

	var bueno := Replay.new()
	bueno.semilla = 4242
	bueno.modo = GameConfig.Difficulty.DIFICIL
	bueno.confianza = 3
	bueno.record = 8
	bueno.score = 11
	bueno.anotar(5, true)
	bueno.anotar(9, false)
	h.check("premisa: un replay bueno se guarda", bueno.guardar(PRUEBA), "")
	var leido: Replay = Replay.cargar(PRUEBA)
	h.check("y se vuelve a leer entero", leido != null, "")
	if leido != null:
		h.check(
			"con semilla, modo, confianza, récord, marca y flancos",
			(
				leido.semilla == 4242
				and leido.modo == GameConfig.Difficulty.DIFICIL
				and leido.confianza == 3
				and leido.record == 8
				and leido.score == 11
				and leido.frames == bueno.frames
				and leido.pulsado == bueno.pulsado
			),
			(
				"semilla %d modo %d confianza %d marca %d flancos %d"
				% [leido.semilla, leido.modo, leido.confianza, leido.score, leido.eventos()]
			)
		)

	var crudo: PackedByteArray = FileAccess.get_file_as_bytes(PRUEBA)
	_escribir(crudo.slice(0, crudo.size() - 3))
	h.check("un fichero cortado a medias no da replay", Replay.cargar(PRUEBA) == null, "")
	var mala: PackedByteArray = crudo.duplicate()
	mala[0] = 0
	_escribir(mala)
	h.check("uno que no es nuestro tampoco", Replay.cargar(PRUEBA) == null, "")
	var futura: PackedByteArray = crudo.duplicate()
	futura[4] = Replay.VERSION + 1
	_escribir(futura)
	h.check("ni uno de otra versión", Replay.cargar(PRUEBA) == null, "")

	# Frames desordenados: el fichero es binario pero se puede manipular, y
	# reproducir flancos que van hacia atrás daría cualquier cosa.
	var desorden := Replay.new()
	desorden.anotar(9, true)
	desorden.anotar(5, false)
	desorden.guardar(PRUEBA)
	h.check("ni uno con los flancos desordenados", Replay.cargar(PRUEBA) == null, "")
	Replay.borrar(PRUEBA)


## El corazón del ticket, contra el fichero versionado.
func _el_replay_de_referencia_se_reproduce() -> void:
	var rep: Replay = Replay.cargar(REFERENCIA)
	h.check("el replay de referencia se lee", rep != null, "%s" % REFERENCIA)
	if rep == null:
		return
	h.check(
		"premisa: es una partida de verdad, no dos aleteos",
		rep.score >= 5 and rep.eventos() >= 20,
		"%d puntos, %d flancos" % [rep.score, rep.eventos()]
	)
	var r: Dictionary = await _reproducir(rep)
	h.check(
		"reproducirlo da exactamente la puntuación grabada",
		r["cuadra"],
		"esperado %d, obtenido %d" % [rep.score, r["score"]]
	)


## Y el contrario: si el fichero dice otra cosa, la partida es otra.
##
## Es lo que separa "el reproductor lee el fichero" de "el reproductor juega
## siempre lo mismo y acierta de casualidad".
func _cambiar_el_fichero_cambia_la_partida() -> void:
	var base: Replay = Replay.cargar(REFERENCIA)
	if base == null:
		return

	var otra_semilla: Replay = Replay.cargar(REFERENCIA)
	otra_semilla.semilla = base.semilla + 7
	var r1: Dictionary = await _reproducir(otra_semilla)
	h.check(
		"con otra semilla la partida ya no cuadra",
		not r1["cuadra"],
		"esperado %d, obtenido %d" % [base.score, r1["score"]]
	)

	var otro_modo: Replay = Replay.cargar(REFERENCIA)
	otro_modo.modo = GameConfig.Difficulty.DIFICIL
	var r2: Dictionary = await _reproducir(otro_modo)
	h.check(
		"con otro modo tampoco: el modo cambia el mundo",
		not r2["cuadra"],
		"esperado %d, obtenido %d" % [base.score, r2["score"]]
	)

	# La confianza se comprueba distinto, y merece la pena explicarlo. Alarga
	# la barra de aliento (T-074), o sea que cambia cuánto se puede planear —
	# pero ESTE replay es de un bot que nunca planea, así que darle más aire
	# no le cambia la partida. Comprobar "con otra confianza no cuadra" sería
	# afirmar algo que solo es verdad a veces.
	#
	# Lo que sí es siempre verdad, y lo que hay que proteger, es que el
	# reproductor **aplique** la confianza del fichero en vez de ignorarla.
	var otra_confianza: Replay = Replay.cargar(REFERENCIA)
	otra_confianza.confianza = GameConfig.CONFIDENCE_MAX_LEVEL
	var r3: Dictionary = await _reproducir(otra_confianza)
	h.check(
		"la confianza del fichero llega a la partida",
		r3["confianza"] == GameConfig.CONFIDENCE_MAX_LEVEL,
		"en el fichero %d, en la sesión %d" % [GameConfig.CONFIDENCE_MAX_LEVEL, r3["confianza"]]
	)
	h.check(
		"y con ella el aliento que le toca a Flapo",
		is_equal_approx(r3["aliento"], GameConfig.max_breath_for(GameConfig.CONFIDENCE_MAX_LEVEL)),
		(
			"aliento %.1f, esperado %.1f"
			% [r3["aliento"], GameConfig.max_breath_for(GameConfig.CONFIDENCE_MAX_LEVEL)]
		)
	)
	h.check(
		"premisa: y es distinto del aliento de base, o no probaría nada",
		not is_equal_approx(
			GameConfig.max_breath_for(GameConfig.CONFIDENCE_MAX_LEVEL),
			GameConfig.max_breath_for(base.confianza)
		),
		(
			"%.1f vs %.1f"
			% [
				GameConfig.max_breath_for(GameConfig.CONFIDENCE_MAX_LEVEL),
				GameConfig.max_breath_for(base.confianza)
			]
		)
	)

	# El récord: desde T-067 dispara el tramo especial, o sea que cambia el
	# mundo. Este caso no existía cuando se escribió el fichero de replay, y
	# lo destapó el bot de T-260 al dejar de dar dos tandas iguales.
	var otro_record: Replay = Replay.cargar(REFERENCIA)
	# Un récord bajo, para que el tramo salga PRONTO y le dé tiempo a cambiar
	# la partida. Con un récord casi igual a la puntuación, el tramo salta en
	# las últimas tuberías y puede no llegar a notarse: sería el mismo error
	# que con la confianza, afirmar algo cierto solo a veces.
	otro_record.record = 3
	var r5: Dictionary = await _reproducir(otro_record)
	h.check(
		"premisa: ese récord se supera pronto, con partida por delante",
		otro_record.record >= GameConfig.SPECIAL_MIN_RECORD and otro_record.record < base.score / 2,
		"récord %d, partida de %d" % [otro_record.record, base.score]
	)
	h.check(
		"con otro récord la partida cambia: el tramo especial de T-067 sale",
		not r5["cuadra"],
		"esperado %d, obtenido %d" % [base.score, r5["score"]]
	)

	# Quitar pulsaciones tiene que notarse: si no, el reproductor no las está
	# usando.
	var sin_final: Replay = Replay.cargar(REFERENCIA)
	sin_final.frames = sin_final.frames.slice(0, 6)
	sin_final.pulsado = sin_final.pulsado.slice(0, 6)
	var r4: Dictionary = await _reproducir(sin_final)
	h.check(
		"y sin la mitad de las pulsaciones, menos aún",
		not r4["cuadra"] and r4["score"] < base.score,
		"esperado %d, obtenido %d" % [base.score, r4["score"]]
	)


## Criterio: volcado automático de la última partida en cada muerte.
func _la_partida_se_graba_sola_al_morir() -> void:
	Replay.borrar()
	SaveManager.clear()
	SaveManager.forget_cache()
	h.check("premisa: no hay replay de antes", Replay.cargar() == null, "")
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.session().set_seed(1234)
	h.jugar(main)
	for tick in 90:
		if tick % 20 == 0:
			h.pulsa(KEY_SPACE)
		elif tick % 20 == 1:
			h.pulsa(KEY_SPACE, false)
		await physics_frame
	var puntos: int = main.get_score()
	main._on_bird_died(Bird.DeathCause.SUELO, false)
	main.free()

	var rep: Replay = Replay.cargar()
	h.check("al morir se guarda la última partida sola", rep != null, "")
	if rep == null:
		return
	h.check("con su semilla", rep.semilla == 1234, "%d" % rep.semilla)
	h.check("y su puntuación", rep.score == puntos, "%d vs %d" % [rep.score, puntos])
	h.check("y las pulsaciones que hubo", rep.eventos() >= 8, "%d flancos" % rep.eventos())


## Criterio: volcado desde el menú de pausa.
func _la_pausa_guarda_una_copia() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	await h.ticks(20)
	main.set_paused(true)
	h.check("premisa: el juego está en pausa", main.get_tree().paused, "")
	h.check("y el aviso empieza vacío", main.pause_panel.aviso() == "", "")
	main.pause_panel.save_replay_pressed.emit()
	h.check(
		"el botón de la pausa avisa de que ha guardado",
		main.pause_panel.aviso() == "Guardada",
		"'%s'" % main.pause_panel.aviso()
	)
	main.set_paused(false)
	main.free()

	var copias: Array = []
	var dir: DirAccess = DirAccess.open("user://")
	for nombre in dir.get_files():
		if nombre.begins_with("replay_") and nombre.ends_with(".replay"):
			copias.append(nombre)
	h.check(
		"y deja un fichero aparte, sin pisar el automático",
		not copias.is_empty(),
		"%s" % str(copias)
	)
	for nombre in copias:
		var copia: Replay = Replay.cargar("user://" + nombre)
		h.check("la copia se puede leer: %s" % nombre, copia != null, "")
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + nombre))


func _reproducir(rep: Replay) -> Dictionary:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	var r: Dictionary = await ReplayPlayer.new().reproducir(self, main, rep)
	# Se sacan del juego antes de liberarlo: son lo que prueba que el perfil
	# del fichero se ha aplicado de verdad y no solo leído.
	r["confianza"] = main.session().confidence()
	r["aliento"] = main.bird.max_breath
	main.free()
	return r
