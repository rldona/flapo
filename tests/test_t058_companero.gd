extends SceneTree
## T-058 — Compañero silencioso.
##
## El criterio del ticket es raro y es el bueno: hay que demostrar que este
## pájaro **no hace nada**. Que exista y que la partida sea idéntica a como
## sería sin él — misma puntuación, mismas tuberías, mismo estado.
##
## Un NPC es la clase de cosa que se cuela en la simulación sin querer: una
## colisión que nadie quería, un `randf()` para que aletee "natural", un
## `Area2D` que roba una fruta. Este test existe para que eso salte.

const MAIN := "res://scenes/Main.tscn"
const BUDDY := "res://scenes/Buddy.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-058 · Compañero silencioso ---")
	_no_tiene_una_sola_forma_de_colision()
	await _no_cambia_la_partida()
	await _sigue_a_flapo_por_detras()
	await _se_asusta_al_rozar()
	await _aplaude_al_ganar_medalla()
	await _se_para_al_morir_flapo()
	SaveManager.clear()
	quit(h.resumen("T-058"))


## Criterio: no colisiona con tuberías, suelo ni frutas.
##
## Se comprueba recorriendo la escena, no leyendo una bandera: la única forma
## de garantizar que no colisiona es que no haya nada con qué.
func _no_tiene_una_sola_forma_de_colision() -> void:
	var nodo: Node = load(BUDDY).instantiate()
	var culpables: Array = []
	_buscar_colisiones(nodo, culpables)
	h.check(
		"la escena del compañero no tiene ninguna forma de colisión",
		culpables.is_empty(),
		"%s" % str(culpables)
	)
	h.check("y no es un cuerpo físico", not nodo is CollisionObject2D, "")
	h.check("ni un área", not nodo is Area2D, "")
	nodo.free()


## El criterio central: con él y sin él, la misma partida.
func _no_cambia_la_partida() -> void:
	var con: Array = await _partida(true)
	var sin: Array = await _partida(false)
	h.check("premisa: el compañero estaba en la primera", con[2], "")
	h.check("premisa: y no en la segunda", not sin[2], "")
	h.check("premisa: han salido tuberías", con[0].size() > 2, "%d" % con[0].size())
	h.check(
		"con compañero salen exactamente las mismas tuberías",
		con[0] == sin[0],
		"%s vs %s" % [str(con[0]), str(sin[0])]
	)
	h.check(
		"y la misma puntuación: el compañero no puntúa",
		con[1] == sin[1],
		"con %d, sin %d" % [con[1], sin[1]]
	)
	h.check(
		"y Flapo acaba exactamente en el mismo sitio",
		is_equal_approx(con[3], sin[3]),
		"y = %.4f vs %.4f" % [con[3], sin[3]]
	)


## Va detrás y arriba. Es el criterio de Raúl escrito como número: entre
## Flapo y el hueco no puede haber nada.
func _sigue_a_flapo_por_detras() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	# Sin colisiones y sin gravedad: Flapo se queda flotando en su carril y lo
	# que se mide es el compañero, no una caída al vacío.
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	var delante: int = 0
	var debajo: int = 0
	var lejos: float = 0.0
	for tick in 180:
		await physics_frame
		var d: Vector2 = main.buddy.position - main.bird.position
		if d.x > 0.0:
			delante += 1
		if d.y > 0.0:
			debajo += 1
		lejos = maxf(lejos, d.length())
	h.check(
		"el compañero nunca se pone delante de Flapo", delante == 0, "%d frames delante" % delante
	)
	h.check("ni por debajo, tapando el hueco", debajo == 0, "%d frames debajo" % debajo)
	h.check("y no se va de paseo", lejos < 90.0, "se alejó %.1f px" % lejos)
	main.free()


## Reacciona a rozar un hueco. Se dispara la señal de la tubería, que es la
## ruta real, no el método del compañero.
func _se_asusta_al_rozar() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	# Flapo tiene que seguir vivo toda la prueba: si se muere, el cambio de
	# estado limpia la reacción y el test daría por bueno un temporizador que
	# no funciona. Pasó: la primera versión no detectaba esa rotura.
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	await h.ticks(2)
	h.check(
		"premisa: empieza sin reaccionar",
		main.buddy.reaccion() == Buddy.Reaccion.NADA,
		"%d" % main.buddy.reaccion()
	)
	main.pipe_spawner.grazed.emit()
	h.check(
		"al rozar un hueco se asusta",
		main.buddy.reaccion() == Buddy.Reaccion.SUSTO,
		"%d" % main.buddy.reaccion()
	)
	# Y se le pasa solo: una reacción que se queda puesta deja de ser una
	# reacción y pasa a ser el aspecto del personaje.
	await h.ticks(int(GameConfig.BUDDY_SCARE_TIME * 60.0) + 5)
	h.check(
		"premisa: y Flapo sigue vivo, así que quien la ha quitado es el reloj",
		main.get_state() == GameState.State.PLAYING,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	h.check(
		"y se le pasa solo",
		main.buddy.reaccion() == Buddy.Reaccion.NADA,
		"%d" % main.buddy.reaccion()
	)
	main.free()


## Y a las medallas, que es lo otro que pide el ticket.
func _aplaude_al_ganar_medalla() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	for i in GameConfig.MEDAL_BRONZE - 1:
		main._on_scored()
	h.check(
		"premisa: a un punto de la medalla todavía no aplaude",
		main.buddy.reaccion() != Buddy.Reaccion.APLAUSO,
		"%d puntos, %d" % [main.get_score(), main.buddy.reaccion()]
	)
	main._on_scored()
	h.check(
		"al ganar la medalla, aplaude",
		main.buddy.reaccion() == Buddy.Reaccion.APLAUSO,
		"%d puntos, %d" % [main.get_score(), main.buddy.reaccion()]
	)
	main.free()


## Al morir Flapo, el compañero se queda quieto.
func _se_para_al_morir_flapo() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	await h.ticks(20)
	main.change_state(GameState.State.GAME_OVER)
	var donde: Vector2 = main.buddy.position
	await h.ticks(30)
	h.check(
		"al morir Flapo el compañero deja de revolotear",
		main.buddy.position.is_equal_approx(donde),
		"%s -> %s" % [str(donde), str(main.buddy.position)]
	)
	main.free()


## Corre una partida idéntica con y sin compañero.
##
## "Sin" se hace **quitándolo del árbol**, no con una bandera: lo que hay que
## demostrar es que el juego es el mismo sin ese nodo.
func _partida(con_companero: bool) -> Array:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	var habia: bool = main.buddy != null
	if not con_companero and habia:
		main.buddy.get_parent().remove_child(main.buddy)
		main.buddy.queue_free()
		main.buddy = null
	main.session().set_seed(31337)
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	var vistas: Dictionary = {}
	var orden: Array = []
	for tick in 400:
		await physics_frame
		for hijo in main.pipe_spawner.get_children():
			if hijo is Pipe and not vistas.has(hijo.get_instance_id()):
				vistas[hijo.get_instance_id()] = true
				orden.append(snappedf(hijo.get_base_gap_center(), 0.01))
	var resultado: Array = [
		orden,
		main.get_score(),
		con_companero and habia,
		snappedf(main.bird.position.y, 0.0001),
	]
	main.free()
	return resultado


func _buscar_colisiones(nodo: Node, culpables: Array) -> void:
	if nodo is CollisionObject2D or nodo is CollisionShape2D or nodo is CollisionPolygon2D:
		culpables.append(nodo.name)
	for hijo in nodo.get_children():
		_buscar_colisiones(hijo, culpables)
