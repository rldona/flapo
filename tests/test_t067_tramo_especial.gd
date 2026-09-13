extends SceneTree
## T-067 — Tramo especial al superar el récord.
##
## El ticket lo dice en una línea que es la que hay que proteger:
## **celebración, no un muro de dificultad**. Así que además de comprobar
## cuándo se dispara, este test comprueba que el tramo **no aprieta**: el
## hueco no se estrecha y el mundo no acelera mientras dura.
##
## Un tramo que se notara solo porque va más rápido sería el castigo por batir
## tu récord.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-067 · Tramo especial ---")
	await _sin_superar_el_record_no_se_dispara()
	await _sin_record_previo_tampoco()
	await _al_superarlo_se_dispara_una_vez()
	await _el_tramo_combina_gimmicks_y_se_ve()
	await _el_tramo_no_aprieta()
	await _no_toca_el_generador()
	SaveManager.clear()
	quit(h.resumen("T-067"))


## Criterio explícito del ticket: no se dispara sin superar el récord.
func _sin_superar_el_record_no_se_dispara() -> void:
	var main: Node = await _con_record(10)
	h.jugar(main)
	for i in 10:
		main._on_scored()
	h.check(
		"con la puntuación igualada al récord todavía no se dispara",
		not main.in_special_stretch(),
		"%d puntos, récord %d" % [main.get_score(), main.get_high_score()]
	)
	main.free()


## Y el caso que se olvida: la primera partida de todas, con récord 0.
func _sin_record_previo_tampoco() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.check("premisa: no hay récord previo", main.get_high_score() == 0, "")
	h.jugar(main)
	for i in 5:
		main._on_scored()
	h.check(
		"en la primera partida, sin récord que batir, no se dispara",
		not main.in_special_stretch(),
		"%d puntos" % main.get_score()
	)
	main.free()


## Criterio: solo una vez por partida, justo tras superar el récord.
func _al_superarlo_se_dispara_una_vez() -> void:
	var main: Node = await _con_record(3)
	h.jugar(main)
	for i in 3:
		main._on_scored()
	h.check("premisa: aún no", not main.in_special_stretch(), "%d puntos" % main.get_score())
	main._on_scored()
	h.check(
		"al pasar el récord se dispara",
		main.in_special_stretch(),
		"%d puntos, récord %d" % [main.get_score(), main.get_high_score()]
	)
	h.check(
		"y dura lo que dice GameConfig",
		main.pipe_spawner.special_left == GameConfig.SPECIAL_STRETCH_PIPES,
		"%d tuberías" % main.pipe_spawner.special_left
	)

	# Gastarlo entero y seguir puntuando: no vuelve.
	main.pipe_spawner.special_left = 0
	for i in 20:
		main._on_scored()
	h.check(
		"y no vuelve a salir aunque se siga subiendo el récord",
		not main.in_special_stretch(),
		"%d puntos" % main.get_score()
	)

	# Y en la partida siguiente vuelve a estar disponible.
	main.change_state(GameState.State.GAME_OVER)
	main.restart()
	h.check(
		"al empezar otra partida el tramo vuelve a estar sin usar",
		not main.in_special_stretch(),
		""
	)
	main.free()


## Criterio: combina 2-3 gimmicks y se nota que es especial.
func _el_tramo_combina_gimmicks_y_se_ve() -> void:
	var main: Node = await _con_record(1)
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	main._on_scored()
	main._on_scored()
	h.check("premisa: el tramo está en marcha", main.in_special_stretch(), "")

	# Se anota lo que interesa EN CUANTO se ve la tubería, no una referencia
	# al nodo: las tuberías se liberan solas al salir de pantalla (ADR-0008) y
	# guardarlas para mirarlas al final es leer objetos ya muertos.
	var vistas: Dictionary = {}
	var especiales: Array = []
	for tick in 600:
		await physics_frame
		for hijo in main.pipe_spawner.get_children():
			if not (hijo is Pipe) or not hijo.special:
				continue
			if vistas.has(hijo.get_instance_id()):
				continue
			vistas[hijo.get_instance_id()] = true
			(
				especiales
				. append(
					{
						"spin": hijo.spin,
						"amplitud": hijo.oscillation_amplitude,
						"soft": hijo.soft,
						"tinte": hijo.tint(),
					}
				)
			)
		if (
			main.pipe_spawner.special_left == 0
			and especiales.size() >= GameConfig.SPECIAL_STRETCH_PIPES
		):
			break
	h.check(
		"salen exactamente las tuberías del tramo",
		especiales.size() == GameConfig.SPECIAL_STRETCH_PIPES,
		"%d de %d" % [especiales.size(), GameConfig.SPECIAL_STRETCH_PIPES]
	)

	var giran: int = 0
	var oscilan: int = 0
	var blandas: int = 0
	var tenidas: int = 0
	for pipe in especiales:
		if pipe["spin"]:
			giran += 1
		if pipe["amplitud"] > 0.0:
			oscilan += 1
		if pipe["soft"]:
			blandas += 1
		if not (pipe["tinte"] as Color).is_equal_approx(Color.WHITE):
			tenidas += 1
	h.check("todas giran", giran == especiales.size(), "%d de %d" % [giran, especiales.size()])
	h.check(
		"todas oscilan", oscilan == especiales.size(), "%d de %d" % [oscilan, especiales.size()]
	)
	h.check("todas se tiñen: el tramo se ve", tenidas == especiales.size(), "%d" % tenidas)
	h.check("y hay una blandita de red", blandas == 1, "%d blanditas" % blandas)
	main.free()


## Lo que de verdad protege la intención del ticket.
func _el_tramo_no_aprieta() -> void:
	var main: Node = await _con_record(5)
	h.jugar(main)
	for i in 5:
		main._on_scored()
	main._on_scored()
	h.check("premisa: el tramo está en marcha", main.in_special_stretch(), "")
	# La foto se toma AL ARRANCAR el tramo: lo que se congela es la
	# dificultad de ese momento, no la de un punto antes.
	var hueco_al_arrancar: float = main.pipe_spawner.gap
	var velocidad_al_arrancar: float = main.pipe_spawner.scroll_speed
	var puntos_al_arrancar: int = main.get_score()
	for i in 5:
		main._on_scored()
	h.check(
		"premisa: se ha seguido puntuando durante el tramo",
		main.get_score() > puntos_al_arrancar and main.in_special_stretch(),
		"%d puntos, de %d" % [main.get_score(), puntos_al_arrancar]
	)
	h.check(
		"durante el tramo el hueco no se estrecha",
		is_equal_approx(main.pipe_spawner.gap, hueco_al_arrancar),
		(
			"%.2f al arrancar, %.2f con %d puntos"
			% [hueco_al_arrancar, main.pipe_spawner.gap, main.get_score()]
		)
	)
	h.check(
		"ni el mundo acelera",
		is_equal_approx(main.pipe_spawner.scroll_speed, velocidad_al_arrancar),
		"%.2f al arrancar, %.2f ahora" % [velocidad_al_arrancar, main.pipe_spawner.scroll_speed]
	)
	h.check(
		"premisa: sin congelar, con esos puntos el hueco sería menor",
		GameConfig.pipe_gap_for(main.get_score(), main.session().difficulty()) < hueco_al_arrancar,
		(
			"%.2f frente a %.2f"
			% [
				GameConfig.pipe_gap_for(main.get_score(), main.session().difficulty()),
				hueco_al_arrancar
			]
		)
	)

	# Y al acabar el tramo, la curva retoma donde le tocaba: congelar no puede
	# regalar dificultad para el resto de la partida.
	main.pipe_spawner.special_left = 0
	main._on_scored()
	var esperado: float = GameConfig.pipe_gap_for(main.get_score(), main.session().difficulty())
	h.check(
		"y al acabar el tramo la curva vuelve a donde le tocaba",
		is_equal_approx(main.pipe_spawner.gap, esperado),
		"%.2f, esperado %.2f para %d puntos" % [main.pipe_spawner.gap, esperado, main.get_score()]
	)
	main.free()


## El tramo no puede tocar el generador: si lo hiciera, dos partidas con la
## misma semilla dejarían de ser la misma según quién batiera su récord, y se
## caerían los códigos de T-242 y el replay de T-261.
func _no_toca_el_generador() -> void:
	var con: Array = await _secuencia(true)
	var sin: Array = await _secuencia(false)
	h.check("premisa: han salido tuberías", con.size() > 3, "%d" % con.size())
	h.check(
		"el tramo especial no mueve la secuencia de huecos",
		con == sin,
		"%s vs %s" % [str(con), str(sin)]
	)


## Alturas de hueco con y sin tramo, misma semilla. Solo la altura: las
## variantes sí cambian, que es el objetivo del tramo.
func _secuencia(con_tramo: bool) -> Array:
	SaveManager.clear()
	SaveManager.forget_cache()
	if con_tramo:
		SaveManager.record_game(2)
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.session().set_seed(4242)
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	if con_tramo:
		main._on_scored()
		main._on_scored()
		main._on_scored()
		if not main.in_special_stretch():
			h.check("premisa: el tramo debía estar en marcha", false, "")
	var vistas: Dictionary = {}
	var alturas: Array = []
	for tick in 500:
		await physics_frame
		for hijo in main.pipe_spawner.get_children():
			if hijo is Pipe and not vistas.has(hijo.get_instance_id()):
				vistas[hijo.get_instance_id()] = true
				alturas.append(snappedf(hijo.get_base_gap_center(), 0.01))
	main.free()
	return alturas


## Monta el juego con un récord ya guardado.
func _con_record(record: int) -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	SaveManager.record_game(record)
	return await h.montar(MAIN, {"log_transitions": false})
