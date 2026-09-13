extends SceneTree
## T-260 — Bot de justicia.
##
## El test NO corre las 200 partidas: eso es la herramienta, y tarda minutos.
## Lo que comprueba es que **la herramienta sirve**: que el bot juega de
## verdad (puntúa, no se queda cayendo), que dos tandas iguales dan lo mismo
## —si no, la métrica no se puede comparar entre versiones— y que el informe
## sale con sus tres números y su histograma.

const MAIN := "res://scenes/Main.tscn"
const PARTIDAS: int = 5
const SEMILLA_BASE: int = 1000

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-260 · Bot de justicia ---")
	var tanda: Array = await _correr(PARTIDAS)
	_el_bot_juega_de_verdad(tanda)
	_el_informe_se_genera(tanda)
	await _la_medida_es_repetible(tanda)
	await _el_guardado_no_contamina_la_tanda(tanda)
	await _apuntar_es_lo_que_decide_la_partida()
	_el_histograma_encuentra_un_pico()
	SaveManager.clear()
	quit(h.resumen("T-260"))


## Monta el juego con el aleteo mudo.
##
## El bot aletea miles de veces, y cada aleteo crea un reproductor de sonido.
## Al liberar el juego con sonidos a medias, Godot avisa de decenas de fugas
## que no son del juego sino de haber apagado la luz mientras hablaba alguien.
## Silenciar el bus no vale: el mute baja el volumen, no deja de reproducir.
##
## Quita el grueso, no todo: al salir siguen quedando un par de sonidos de
## golpe a medias y Godot lo avisa. Es ruido de este test, no del juego —de
## las fugas del juego se ocupa `test_t082_perf.gd`, que mide el árbol de
## nodos de una partida real.
func _montar_mudo() -> Node:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.bird.flapped.disconnect(main.audio.play_flap)
	return main


func _correr(partidas: int) -> Array:
	var main: Node = await _montar_mudo()
	var bot := BotPilot.new()
	var resultados: Array = []
	for i in partidas:
		resultados.append(await bot.jugar(self, main, SEMILLA_BASE + i))
	main.free()
	return resultados


## Criterio: el bot puntúa > 0.
##
## Y algo más, porque "> 0" lo cumpliría un bot que cruza una tubería de
## chiripa y se estrella: se exige que puntúe en TODAS las partidas. Un bot
## que solo acierta a veces no mide la curva, mide su propia suerte.
func _el_bot_juega_de_verdad(tanda: Array) -> void:
	h.check("premisa: se han jugado las partidas", tanda.size() == PARTIDAS, "%d" % tanda.size())
	var ceros: Array = []
	var total: int = 0
	for r in tanda:
		total += int(r["score"])
		if int(r["score"]) <= 0:
			ceros.append(r["semilla"])
		h.check(
			"la partida %d termina sola, sin agotar el tope" % r["semilla"],
			not r["agotado"],
			"%d frames" % r["frames"]
		)
	h.check("el bot puntúa en todas las partidas", ceros.is_empty(), "sin puntuar: %s" % str(ceros))
	h.check(
		"y no de chiripa: la media pasa de 1",
		float(total) / float(tanda.size()) > 1.0,
		"media %.2f" % (float(total) / float(tanda.size()))
	)


## Criterio: el reporte se genera.
func _el_informe_se_genera(tanda: Array) -> void:
	var texto: String = BotPilot.informe(tanda)
	for trozo in ["Partidas:", "Media:", "Mediana:", "Muertes por índice"]:
		h.check("el informe trae '%s'" % trozo, texto.contains(trozo), "")
	h.check(
		"y el histograma tiene una fila por índice con muertes",
		texto.count("|") >= 1,
		"%d filas" % texto.count("|")
	)
	h.check("un informe sin partidas no revienta", BotPilot.informe([]) == "Sin partidas.", "")


## Sin esto la métrica no vale para nada: si la misma tanda da números
## distintos, comparar antes y después de tocar `GameConfig` no dice nada.
func _la_medida_es_repetible(tanda: Array) -> void:
	var otra: Array = await _correr(PARTIDAS)
	var a: Array = []
	var b: Array = []
	for i in tanda.size():
		a.append(tanda[i]["score"])
		b.append(otra[i]["score"])
	h.check("premisa: hay variedad entre partidas", a.max() != a.min(), "%s" % str(a))
	h.check(
		"dos tandas con las mismas semillas dan lo mismo", a == b, "%s vs %s" % [str(a), str(b)]
	)


## Lo que de verdad protege la comparabilidad: el guardado se limpia antes de
## CADA partida.
##
## Sin eso, la confianza (T-074) alarga la barra de aliento con las partidas
## jugadas, y una tanda corrida después de haber jugado mucho no se puede
## comparar con la misma tanda corrida en frío. Se comprueba envejeciendo el
## guardado a propósito entre las dos tandas.
func _el_guardado_no_contamina_la_tanda(tanda: Array) -> void:
	for i in 40:
		SaveManager.record_game(9)
	h.check(
		"premisa: el guardado está envejecido",
		SaveManager.get_confidence() > 0,
		(
			"confianza %d tras %d partidas"
			% [SaveManager.get_confidence(), SaveManager.get_games_played()]
		)
	)
	var otra: Array = await _correr(PARTIDAS)
	var a: Array = []
	var b: Array = []
	for i in tanda.size():
		a.append(tanda[i]["score"])
		b.append(otra[i]["score"])
	h.check(
		"la misma tanda da lo mismo con el guardado envejecido",
		a == b,
		"en frío %s, envejecido %s" % [str(a), str(b)]
	)


## Dónde apunta el bot es lo que decide la partida, y es lo único de la
## política que merece protección en un test.
##
## Se comprueba comparando contra otro valor, no contra un umbral fijo: un
## umbral no distingue "la política funciona" de "estas cinco semillas eran
## fáciles". Si algún día alguien cambia `APUNTAR` sin medir, esto lo para.
func _apuntar_es_lo_que_decide_la_partida() -> void:
	var main: Node = await _montar_mudo()
	var calibrado: float = await _media(main, BotPilot.APUNTAR)
	var al_centro: float = await _media(main, 0.0)
	var muy_bajo: float = await _media(main, 1.0)
	main.free()
	h.check("premisa: el bot calibrado juega", calibrado > 3.0, "media %.2f" % calibrado)
	h.check(
		"apuntar al centro exacto es mucho peor: el aleteo se pasa",
		calibrado > al_centro * 2.0,
		"calibrado %.2f, al centro %.2f" % [calibrado, al_centro]
	)
	h.check(
		"y apuntar demasiado bajo, también",
		calibrado > muy_bajo * 2.0,
		"calibrado %.2f, muy bajo %.2f" % [calibrado, muy_bajo]
	)


func _media(main: Node, apuntar: float) -> float:
	var bot := BotPilot.new()
	bot.apuntar = apuntar
	var total: int = 0
	for i in PARTIDAS:
		total += int((await bot.jugar(self, main, SEMILLA_BASE + i))["score"])
	return float(total) / float(PARTIDAS)


## El histograma existe para encontrar picos, así que se comprueba con un
## pico puesto a mano: si no lo señalara, no serviría para lo que se hizo.
func _el_histograma_encuentra_un_pico() -> void:
	var falsas: Array = []
	for i in 20:
		falsas.append({"score": 6})
	for i in 3:
		falsas.append({"score": 2})
	var texto: String = BotPilot.informe(falsas)
	var lineas: PackedStringArray = texto.split("\n")
	var pico: String = ""
	var otra: String = ""
	for linea in lineas:
		if linea.begins_with("    7 |"):
			pico = linea
		elif linea.begins_with("    3 |"):
			otra = linea
	h.check("el índice del pico es la tubería que NO se pasó", pico != "", "%s" % texto)
	h.check(
		"y su barra es mucho más larga que la de al lado",
		pico.count("#") > otra.count("#") * 3,
		"pico %d '#', otra %d" % [pico.count("#"), otra.count("#")]
	)
