extends SceneTree
## T-203 — Térmicas.
##
## Lo que hay que proteger: que **planear dentro suba y fuera no**, que el
## efecto se **retire al salir** —un efecto que se queda puesto es un bug que
## el jugador nota tres tuberías después—, que haya **tope** para que la
## columna no estampe a Flapo contra el techo, y que el aleteo siga siendo el
## de siempre.
##
## Y la garantía del ticket: una térmica **nunca** coincide con una tubería
## móvil ni con el tramo especial, y lo garantiza el spawner. Eso se comprueba
## jugando, no leyendo el código.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-203 · Térmicas ---")
	await _planear_dentro_sube_y_fuera_baja()
	await _el_efecto_se_retira_al_salir()
	await _la_subida_tiene_tope()
	await _el_aleteo_no_cambia()
	await _no_salen_antes_de_la_puntuacion_minima()
	await _nunca_coinciden_con_movil_ni_con_tramo_especial()
	await _no_mueven_la_secuencia_de_tuberias()
	SaveManager.clear()
	quit(h.resumen("T-203"))


## El corazón del ticket.
func _planear_dentro_sube_y_fuera_baja() -> void:
	var fuera: float = await _planear(false)
	var dentro: float = await _planear(true)
	h.check("planeando fuera, Flapo baja", fuera > 5.0, "%.1f px" % fuera)
	h.check("planeando dentro de una térmica, sube", dentro < -5.0, "%.1f px" % dentro)


## Un efecto que no se apaga es peor que no tenerlo.
func _el_efecto_se_retira_al_salir() -> void:
	var main: Node = await _montar_volando()
	main.air_spawner.thermal_changed.emit(true)
	h.check("premisa: dentro", main.bird.in_thermal(), "")
	main.air_spawner.thermal_changed.emit(false)
	h.check("al salir, el efecto se retira", not main.bird.in_thermal(), "")
	var recorrido: float = await _planear_en(main)
	h.check("y planear vuelve a bajar", recorrido > 5.0, "%.1f px" % recorrido)
	main.free()

	# Dos columnas solapadas: salir de la primera no puede apagar la segunda.
	var otro: Node = await _montar_volando()
	otro.air_spawner.thermal_changed.emit(true)
	otro.air_spawner.thermal_changed.emit(true)
	otro.air_spawner.thermal_changed.emit(false)
	h.check("con dos térmicas solapadas, salir de una no apaga la otra", otro.bird.in_thermal(), "")
	otro.air_spawner.thermal_changed.emit(false)
	h.check("y al salir de las dos, sí", not otro.bird.in_thermal(), "")
	otro.free()


## Criterio: nunca saca a Flapo del control ni lo estampa arriba.
func _la_subida_tiene_tope() -> void:
	var main: Node = await _montar_volando()
	main.air_spawner.thermal_changed.emit(true)
	# Se mide solo mientras PLANEA: el aleteo con el que se engancha el
	# planeo llega a -380 y no es lo que este criterio limita.
	h.pulsa(KEY_SPACE)
	var pico: float = 0.0
	var planeando: int = 0
	for i in 300:
		await physics_frame
		if not main.bird.is_gliding() or main.bird.velocity.y < -AirConfig.THERMAL_MAX_RISE * 1.5:
			continue
		planeando += 1
		pico = minf(pico, main.bird.velocity.y)
	h.check("premisa: ha planeado dentro de la térmica", planeando > 60, "%d frames" % planeando)
	h.check(
		"la subida dentro de la térmica está topada",
		pico >= -AirConfig.THERMAL_MAX_RISE - 1.0,
		"pico %.1f px/s, tope %.1f" % [pico, -AirConfig.THERMAL_MAX_RISE]
	)
	h.check(
		"y el tope es menor que lo que sube un aleteo: ayuda, no vuela por ti",
		AirConfig.THERMAL_MAX_RISE < absf(main.bird.flap_impulse),
		"%.1f frente a %.1f" % [AirConfig.THERMAL_MAX_RISE, absf(main.bird.flap_impulse)]
	)
	h.pulsa(KEY_SPACE, false)
	main.free()


## Criterio: el aleteo no cambia.
func _el_aleteo_no_cambia() -> void:
	var fuera: float = await _aletear(false)
	var dentro: float = await _aletear(true)
	h.check(
		"el aleteo dentro de la térmica es exactamente el de siempre",
		is_equal_approx(fuera, dentro),
		"fuera %.4f, dentro %.4f" % [fuera, dentro]
	)


## No salen antes de que el jugador sepa planear.
func _no_salen_antes_de_la_puntuacion_minima() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	for i in 40:
		main.pipe_spawner.pipe_spawned.emit()
	h.check(
		"a 0 puntos no sale ninguna térmica",
		main.air_spawner.thermal_count() == 0,
		"%d térmicas" % main.air_spawner.thermal_count()
	)
	for i in AirConfig.THERMAL_MIN_SCORE:
		main._on_scored()
	for i in AirConfig.THERMAL_INTERVAL:
		main.pipe_spawner.pipe_spawned.emit()
	h.check(
		"con la puntuación mínima ya salen",
		main.air_spawner.thermal_count() > 0,
		"%d térmicas con %d puntos" % [main.air_spawner.thermal_count(), main.get_score()]
	)
	main.free()


## La garantía del ticket, comprobada jugando.
##
## "Coincidir" no puede medirse como solape de rectángulos: la térmica cae a
## media separación de las tuberías, así que **nunca** se solapa con ninguna y
## un test así estaría siempre en verde. Se comprobó rompiéndolo —quitando la
## garantía entera— y el test no se enteraba.
##
## Lo que de verdad dice el ticket es que la térmica no caiga en un tramo de
## tuberías raras. Así que se mira **la tubería de antes y la de después** de
## cada térmica: ninguna de las dos puede ser móvil ni del tramo especial.
func _nunca_coinciden_con_movil_ni_con_tramo_especial() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	SaveManager.record_game(3)
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.session().set_seed(4242)
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	# Puntuación alta: la curva pone la probabilidad de móvil al máximo y el
	# caso difícil se da de verdad.
	for i in 40:
		main._on_scored()
	var malas: Array = []
	var comprobaciones: int = 0
	var moviles_vistas: int = 0
	for tick in 1500:
		await physics_frame
		for p in main.pipe_spawner.get_children():
			if p is Pipe and (p.oscillation_amplitude > 0.0 or p.special):
				moviles_vistas += 1
		for t in main.air_spawner.get_children():
			if not (t is Thermal):
				continue
			for lado in [_vecina(main, t.position.x, true), _vecina(main, t.position.x, false)]:
				if lado == null:
					continue
				# Solo las dos tuberías entre las que la térmica cae de
				# verdad. Una tubería a una separación entera no "coincide"
				# con nada: exigir eso sería exigir que no haya móviles en
				# media pantalla, que no es lo que pide el ticket.
				if absf(lado.position.x - t.position.x) > main.pipe_spawner.spacing * 0.75:
					continue
				comprobaciones += 1
				if lado.oscillation_amplitude > 0.0 or lado.special:
					malas.append(snappedf(lado.position.x, 1))
	h.check(
		"premisa: se han mirado vecinas de térmicas", comprobaciones > 50, "%d" % comprobaciones
	)
	h.check(
		"premisa: y había tuberías móviles en la partida, o no probaría nada",
		moviles_vistas > 0,
		"%d observaciones" % moviles_vistas
	)
	h.check(
		"ninguna térmica tiene al lado una tubería móvil o del tramo especial",
		malas.is_empty(),
		"%d vecinas malas: %s" % [malas.size(), str(malas.slice(0, 4))]
	)
	main.free()


## La tubería más cercana a `x` por un lado o por el otro.
func _vecina(main: Node, x: float, derecha: bool) -> Pipe:
	var mejor: Pipe = null
	for p in main.pipe_spawner.get_children():
		if not (p is Pipe):
			continue
		if derecha and p.position.x <= x:
			continue
		if not derecha and p.position.x >= x:
			continue
		if mejor == null or absf(p.position.x - x) < absf(mejor.position.x - x):
			mejor = p
	return mejor


## Reservar una tubería normal no puede mover el generador: si lo hiciera,
## dos partidas con la misma semilla dejarían de ser la misma según dónde
## cayera una térmica.
func _no_mueven_la_secuencia_de_tuberias() -> void:
	var con: Array = await _secuencia(AirConfig.THERMAL_MIN_SCORE + 20, true)
	var sin: Array = await _secuencia(AirConfig.THERMAL_MIN_SCORE + 20, false)
	# Suficientes tuberías para que hayan salido varias térmicas: con tres o
	# cuatro, una tirada de menos puede no llegar a notarse y el test pasaría
	# sin comprobar nada.
	h.check("premisa: han salido bastantes tuberías", con.size() >= 8, "%d" % con.size())
	# Se comparan las ALTURAS de hueco, no las variantes. Una tubería
	# reservada sale sin variante a propósito —es lo que hace la reserva—,
	# pero su altura tiene que ser la misma: eso es lo que demuestra que el
	# generador no se ha movido un paso. Comparar también las variantes fallaba
	# por el motivo correcto y por eso no valía como comprobación.
	h.check(
		"con térmicas, las alturas de hueco son exactamente las mismas",
		con == sin,
		"%s vs %s" % [str(con), str(sin)]
	)


## La secuencia de tuberías, con el aire puesto o quitado del árbol.
##
## Contra una partida SIN aire y no contra otra igual: comparar dos
## ejecuciones del mismo código no comprueba nada, los dos lados se mueven a
## la vez. Se verificó rompiéndolo —haciendo que la reserva se saltara las
## tiradas del generador— y el test seguía en verde.
func _secuencia(puntos: int, con_aire: bool) -> Array:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	if not con_aire:
		main.air_spawner.get_parent().remove_child(main.air_spawner)
		main.air_spawner.queue_free()
		main.air_spawner = null
	main.session().set_seed(31415)
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	for i in puntos:
		main._on_scored()
	var vistas: Dictionary = {}
	var orden: Array = []
	for tick in 1400:
		await physics_frame
		for hijo in main.pipe_spawner.get_children():
			if hijo is Pipe and not vistas.has(hijo.get_instance_id()):
				vistas[hijo.get_instance_id()] = true
				orden.append(snappedf(hijo.get_base_gap_center(), 0.01))
	main.free()
	return orden


## Cuánto se desplaza Flapo planeando medio segundo, dentro o fuera.
func _planear(dentro: bool) -> float:
	var main: Node = await _montar_volando()
	if dentro:
		main.air_spawner.thermal_changed.emit(true)
	var recorrido: float = await _planear_en(main)
	main.free()
	return recorrido


## Cuánto se desplaza Flapo PLANEANDO, ya con el planeo enganchado.
##
## Mantener pulsado empieza por un **aleteo**: el planeo se activa manteniendo
## el mismo botón (T-200), así que el primer flanco es siempre un impulso
## hacia arriba. Medir desde el momento de pulsar mide el arco del aleteo, no
## el planeo — la primera versión de este test lo hacía y daba a Flapo
## subiendo 38 px "planeando".
##
## Por eso se espera a `is_gliding()` y además a que el impulso se agote.
func _planear_en(main: Node) -> float:
	# Flapo se baja antes de medir: dentro de una térmica sube 170 px/s y
	# desde el centro de la pantalla se comería el techo a mitad de la medida,
	# que daría 0 px de recorrido y un test que miente.
	main.bird.position.y = GameConfig.playable_height() * 0.85
	main.bird.velocity = Vector2.ZERO
	h.pulsa(KEY_SPACE)
	# 80 frames de margen antes de medir. Mantener pulsado empieza por un
	# **aleteo** —el planeo se activa con el mismo botón (T-200)— y planeando
	# ese impulso tarda mucho más en agotarse, porque el planeo frena la
	# subida a 300 px/s² en vez de a 1200. Medir antes mide el arco del
	# aleteo: la primera versión de este test daba a Flapo "planeando" hacia
	# arriba fuera de toda térmica.
	await h.ticks(80)
	var glide: bool = main.bird.is_gliding()
	var antes: float = main.bird.position.y
	await h.ticks(20)
	var recorrido: float = main.bird.position.y - antes
	h.pulsa(KEY_SPACE, false)
	await h.ticks(2)
	h.check("premisa: estaba planeando de verdad al medir", glide, "")
	return recorrido


## El pico de velocidad de un aleteo, dentro o fuera.
func _aletear(dentro: bool) -> float:
	var main: Node = await _montar_volando()
	if dentro:
		main.air_spawner.thermal_changed.emit(true)
	var v: float = 0.0
	for i in 10:
		if i == 0:
			h.pulsa(KEY_SPACE)
		elif i == 1:
			h.pulsa(KEY_SPACE, false)
		await physics_frame
		if absf(main.bird.velocity.y) > absf(v):
			v = main.bird.velocity.y
	main.free()
	return v


func _montar_volando() -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	main.bird.collision_mask = 0
	await h.ticks(2)
	return main
