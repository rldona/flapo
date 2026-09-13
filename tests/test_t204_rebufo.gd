extends SceneTree
## T-204 — El hermano pasa: estela de rebufo.
##
## Tres cosas que proteger, y las tres son criterios del ticket:
##
## 1. Dentro de la estela, planear **no gasta aliento**; fuera vuelve a
##    gastar. Un efecto que no se retira es peor que no tenerlo.
## 2. La estela **se libera sola**. Es la diferencia entre un efecto temporal
##    y una fuga de nodos que nadie ve hasta la partida 40.
## 3. El hermano **nunca tapa el hueco** que hay que cruzar. Es lo único del
##    ticket que suena a estética y en realidad es jugabilidad: un adorno
##    delante del hueco es un obstáculo que no mata pero cuesta una partida.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-204 · Rebufo ---")
	_el_hermano_no_tiene_fisica()
	await _dentro_de_la_estela_planear_no_gasta_aliento()
	await _el_efecto_se_retira_al_salir()
	await _la_estela_se_libera_sola()
	_el_carril_del_hermano_esta_fuera_de_todo_hueco()
	await _el_hermano_no_tapa_el_hueco()
	await _no_puntua_ni_mueve_la_partida()
	SaveManager.clear()
	quit(h.resumen("T-204"))


## Criterio: el hermano es puro escenario, no un `CharacterBody2D`.
func _el_hermano_no_tiene_fisica() -> void:
	var nodo: Node = load("res://scenes/Brother.tscn").instantiate()
	var culpables: Array = []
	_buscar_colisiones(nodo, culpables)
	h.check(
		"el hermano no tiene ninguna forma de colisión", culpables.is_empty(), "%s" % str(culpables)
	)
	h.check("y no es un cuerpo físico", not nodo is CollisionObject2D, "")
	nodo.free()


## El criterio central del ticket.
func _dentro_de_la_estela_planear_no_gasta_aliento() -> void:
	var fuera: float = await _gasto_planeando(false)
	var dentro: float = await _gasto_planeando(true)
	h.check("planeando fuera se gasta aliento", fuera > 5.0, "%.2f de aliento" % fuera)
	h.check(
		"planeando dentro de la estela no se gasta nada",
		is_zero_approx(dentro),
		"%.4f de aliento" % dentro
	)
	# El número exacto: fuera tiene que gastar lo que dice GameConfig.
	h.check(
		"y lo que se gasta fuera es BREATH_DRAIN_GLIDE",
		absf(fuera - GameConfig.BREATH_DRAIN_GLIDE * 0.5) < 1.0,
		"%.2f en medio segundo, esperado %.2f" % [fuera, GameConfig.BREATH_DRAIN_GLIDE * 0.5]
	)


func _el_efecto_se_retira_al_salir() -> void:
	var main: Node = await _montar_volando()
	main.air_spawner.slipstream_changed.emit(true)
	h.check("premisa: dentro", main.bird.in_slipstream(), "")
	main.air_spawner.slipstream_changed.emit(false)
	h.check("al salir, el efecto se retira", not main.bird.in_slipstream(), "")
	main.air_spawner.slipstream_changed.emit(true)
	main.air_spawner.slipstream_changed.emit(true)
	main.air_spawner.slipstream_changed.emit(false)
	h.check("con dos estelas, salir de una no apaga la otra", main.bird.in_slipstream(), "")
	main.free()


## Criterio: la estela se libera sola.
##
## Se sigue **una estela concreta**, no el contador: durante la espera la
## partida sigue y puede cruzar otro hermano, así que "queda 1 estela" no dice
## nada sobre si la primera murió. Con el contador, el test fallaba culpando a
## la estela vieja de una nueva.
func _la_estela_se_libera_sola() -> void:
	var main: Node = await _con_hermano()
	var estela: Node = null
	for hijo in main.air_spawner.get_children():
		if hijo is Slipstream:
			estela = hijo
	h.check("premisa: hay estela", estela != null, "")
	if estela == null:
		main.free()
		return

	# A mitad de vida sigue ahí: sin este lado, una estela que muriera al
	# instante también pasaría el test.
	await h.ticks(int(AirConfig.SLIPSTREAM_TIME * 30.0))
	h.check("a mitad de su tiempo la estela sigue viva", is_instance_valid(estela), "")

	# Lo que separa "caduca" de "se sale de pantalla" no es el reloj: a la
	# velocidad del mundo las dos cosas pasan casi a la vez, y medir por
	# tiempo daba por bueno un caducado inexistente. Lo que las distingue de
	# verdad es **dónde** muere: por tiempo muere estando todavía en pantalla.
	var estela_ancho: float = estela.ancho
	var ultima_x: float = estela.position.x
	var frames: int = 0
	for i in 400:
		await physics_frame
		if not is_instance_valid(estela):
			break
		ultima_x = estela.position.x
		frames += 1
	h.check("la estela acaba liberándose sola", not is_instance_valid(estela), "%d frames" % frames)
	# El borde derecho de la estela todavía dentro de la pantalla: eso es lo
	# que separa "ha caducado" de "se ha ido por la izquierda".
	h.check(
		"y muere por tiempo, no por salirse: seguía asomando en pantalla",
		ultima_x + estela_ancho * 0.5 > 0.0,
		"murió con el borde derecho en x = %.1f" % (ultima_x + estela_ancho * 0.5)
	)

	var hermanos: int = main.air_spawner.brother_count()
	h.check("y el hermano de esa pasada también se ha ido", hermanos <= 1, "%d hermanos" % hermanos)
	main.free()


## Criterio: nunca tapa el hueco. Comprobado con aritmética, no muestreando.
##
## Muestrear mientras el hermano cruza no bastaba: pasa en un segundo y con
## suerte no coincide con un hueco malo. Se comprobó rompiéndolo —mandándolo a
## cruzar por media pantalla— y el test no se enteraba.
##
## Lo que se comprueba es la geometría entera: el carril del hermano tiene que
## quedar fuera del hueco **más extremo que el juego puede sortear**. Si eso se
## cumple, no hay partida en la que pueda taparlo.
func _el_carril_del_hermano_esta_fuera_de_todo_hueco() -> void:
	var pipe: Pipe = load("res://scenes/Pipe.tscn").instantiate()
	var alto: float = GameConfig.playable_height()
	var hueco_max: float = GameConfig.PIPE_GAP
	# El hueco más alto que puede salir, y el más bajo.
	var centro_alto: float = pipe.gap_center_min_ratio * alto
	var centro_bajo: float = pipe.gap_center_max_ratio * alto
	var borde_superior: float = centro_alto - hueco_max * 0.5
	var borde_inferior: float = centro_bajo + hueco_max * 0.5
	var carril_arriba: float = AirConfig.BROTHER_EDGE_MARGIN
	var carril_abajo: float = alto - AirConfig.BROTHER_EDGE_MARGIN
	h.check(
		"el carril de arriba queda por encima del hueco más alto posible",
		carril_arriba < borde_superior,
		"carril %.1f, hueco más alto empieza en %.1f" % [carril_arriba, borde_superior]
	)
	h.check(
		"y el de abajo por debajo del más bajo",
		carril_abajo > borde_inferior,
		"carril %.1f, hueco más bajo acaba en %.1f" % [carril_abajo, borde_inferior]
	)
	h.check(
		"y los dos carriles caben en la pantalla",
		carril_arriba > 0.0 and carril_abajo < alto,
		"%.1f y %.1f de %.1f" % [carril_arriba, carril_abajo, alto]
	)
	pipe.free()


## Y además, jugando: que en una partida real tampoco pase por ningún hueco.
func _el_hermano_no_tapa_el_hueco() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.session().set_seed(2024)
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	for i in AirConfig.BROTHER_MIN_SCORE + 20:
		main._on_scored()
	var invasiones: Array = []
	var comprobaciones: int = 0
	for tick in 1500:
		await physics_frame
		for b in main.air_spawner.get_children():
			if not (b is Brother):
				continue
			var pipe: Pipe = _pipe_mas_cercana(main, b.position.x)
			if pipe == null:
				continue
			comprobaciones += 1
			var dentro_del_hueco: bool = absf(b.position.y - pipe.get_gap_center()) < pipe.gap * 0.5
			if dentro_del_hueco:
				invasiones.append([snappedf(b.position.y, 1), snappedf(pipe.get_gap_center(), 1)])
	h.check("premisa: ha pasado el hermano", comprobaciones > 30, "%d muestras" % comprobaciones)
	h.check(
		"el hermano nunca cruza por dentro del hueco que toca",
		invasiones.is_empty(),
		"%d invasiones: %s" % [invasiones.size(), str(invasiones.slice(0, 3))]
	)
	main.free()


## Ni puntúa ni cambia la partida: es escenario.
##
## Se comprueba comparando la misma partida **con el aire y sin él**, no
## contando puntos a mano. Dos intentos de contarlos fallaron por motivos que
## no eran el hermano: la zona de punto no está exactamente en el centro de la
## tubería, así que "tuberías que han pasado a Flapo" y "puntos" no coinciden
## frame a frame. Comparar dos partidas idénticas no tiene ese problema.
func _no_puntua_ni_mueve_la_partida() -> void:
	var con: Array = await _partida_larga(true)
	var sin: Array = await _partida_larga(false)
	h.check("premisa: el aire estaba en la primera", con[2], "")
	h.check("premisa: y no en la segunda", not sin[2], "")
	h.check("premisa: se ha puntuado", con[1] > 0, "%d puntos" % con[1])
	h.check(
		"con el hermano cruzando, la puntuación es exactamente la misma",
		con[1] == sin[1],
		"con aire %d, sin aire %d" % [con[1], sin[1]]
	)
	h.check("y las mismas tuberías", con[0] == sin[0], "%s vs %s" % [str(con[0]), str(sin[0])])


## Una partida larga con el aire puesto o quitado del árbol.
func _partida_larga(con_aire: bool) -> Array:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	var habia: bool = main.air_spawner != null
	if not con_aire and habia:
		main.air_spawner.get_parent().remove_child(main.air_spawner)
		main.air_spawner.queue_free()
		main.air_spawner = null
	main.session().set_seed(777)
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	for i in AirConfig.BROTHER_MIN_SCORE:
		main._on_scored()
	var vistas: Dictionary = {}
	var orden: Array = []
	for tick in 1200:
		await physics_frame
		for p in main.pipe_spawner.get_children():
			if p is Pipe and not vistas.has(p.get_instance_id()):
				vistas[p.get_instance_id()] = true
				orden.append(snappedf(p.get_base_gap_center(), 0.01))
	var r: Array = [orden, main.get_score(), con_aire and habia]
	main.free()
	return r


## Cuánto aliento se gasta planeando medio segundo, dentro o fuera.
func _gasto_planeando(dentro: bool) -> float:
	var main: Node = await _montar_volando()
	if dentro:
		main.air_spawner.slipstream_changed.emit(true)
	h.pulsa(KEY_SPACE)
	# Igual que en T-203: mantener empieza por un aleteo, y el aleteo también
	# gasta aliento. Se espera a estar planeando y se mide desde ahí.
	await h.ticks(40)
	var glide: bool = main.bird.is_gliding()
	var antes: float = main.bird.breath()
	await h.ticks(30)
	var gasto: float = antes - main.bird.breath()
	h.pulsa(KEY_SPACE, false)
	h.check("premisa: estaba planeando al medir", glide, "")
	main.free()
	return gasto


## Monta una partida con el hermano ya cruzando.
func _con_hermano() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	for i in AirConfig.BROTHER_MIN_SCORE:
		main._on_scored()
	for i in AirConfig.BROTHER_INTERVAL:
		main.pipe_spawner.pipe_spawned.emit()
	await h.ticks(2)
	return main


func _montar_volando() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	main.bird.collision_mask = 0
	await h.ticks(2)
	return main


func _pipe_mas_cercana(main: Node, x: float) -> Pipe:
	var mejor: Pipe = null
	for p in main.pipe_spawner.get_children():
		if not (p is Pipe):
			continue
		if mejor == null or absf(p.position.x - x) < absf(mejor.position.x - x):
			mejor = p
	return mejor


func _buscar_colisiones(nodo: Node, culpables: Array) -> void:
	if nodo is CollisionObject2D or nodo is CollisionShape2D or nodo is CollisionPolygon2D:
		culpables.append(nodo.name)
	for hijo in nodo.get_children():
		_buscar_colisiones(hijo, culpables)
