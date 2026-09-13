extends SceneTree
## T-243 — Fantasma del récord.
##
## Lo que promete el ticket es que el vuelo grabado se vuelve a ver **igual**,
## y que el fantasma no se nota en nada más: ni puntúa, ni choca, ni cambia
## una sola tubería. Así que aquí hay dos clases de comprobación:
##
## 1. **Que reproduce.** Se juega una partida, se graba, se monta el juego de
##    cero (leyendo el fichero del disco, no la copia en memoria) y se compara
##    la `y` del fantasma frame a frame con la que se grabó.
## 2. **Que no se nota.** La misma partida con fantasma y sin él tiene que dar
##    exactamente las mismas tuberías y la misma puntuación. Sin este caso,
##    un fantasma que pidiera números al generador pasaría el test anterior
##    tan tranquilo.

const MAIN := "res://scenes/Main.tscn"
const GHOST := "res://scenes/Ghost.tscn"
const CODIGO := "00abc"
const OTRO := "00abd"
const PRUEBA := "user://ghost_prueba.dat"

## Cada cuántos frames aletea el piloto automático. 22 mantiene a Flapo
## dentro de la pantalla y le da una trayectoria de dientes de sierra: si
## volara recto, un fantasma roto que se quedara quieto pasaría el test.
const CADA: int = 22
const FRAMES: int = 300

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-243 · Fantasma del récord ---")
	_un_fichero_roto_no_da_fantasma()
	await _sin_fichero_el_juego_arranca_igual()
	await _graba_al_batir_el_record_y_lo_reproduce()
	await _una_partida_peor_no_pisa_el_fantasma()
	await _con_otra_semilla_no_sale()
	await _no_puntua_ni_toca_el_rng()
	_no_tiene_una_sola_forma_de_colision()
	GhostRecord.borrar()
	GhostRecord.borrar(PRUEBA)
	SaveManager.clear()
	quit(h.resumen("T-243"))


func _escribir(bytes: PackedByteArray) -> void:
	var f: FileAccess = FileAccess.open(PRUEBA, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


## Criterio: fichero ausente o corrupto no rompe el arranque.
##
## "No romper" aquí significa devolver `null`, no devolver un fantasma medio
## leído: un fichero cortado por la mitad se leería como un vuelo lleno de
## ceros y el fantasma caería recto al suelo como si eso hubiera pasado.
func _un_fichero_roto_no_da_fantasma() -> void:
	GhostRecord.borrar(PRUEBA)
	h.check("un fichero que no existe no da fantasma", GhostRecord.cargar(PRUEBA) == null, "")

	_escribir("esto no es un fantasma, es texto".to_utf8_buffer())
	h.check("un fichero de basura tampoco", GhostRecord.cargar(PRUEBA) == null, "")

	# Uno bueno, para tener con qué comparar los rotos.
	var bueno := GhostRecord.new()
	bueno.semilla = 4242
	bueno.score = 9
	bueno.posiciones = PackedFloat32Array([100.0, 120.5, 90.25])
	h.check("premisa: un fantasma bueno se guarda", bueno.guardar(PRUEBA), "")
	var leido: GhostRecord = GhostRecord.cargar(PRUEBA)
	h.check("y se vuelve a leer entero", leido != null, "")
	if leido != null:
		h.check(
			"con su semilla, su marca y sus posiciones",
			leido.semilla == 4242 and leido.score == 9 and leido.posiciones == bueno.posiciones,
			"semilla %d, marca %d, %d frames" % [leido.semilla, leido.score, leido.frames()]
		)

	# Truncado: la cabecera dice 3 frames y solo hay dos floats y medio.
	var crudo: PackedByteArray = FileAccess.get_file_as_bytes(PRUEBA)
	_escribir(crudo.slice(0, crudo.size() - 5))
	h.check("un fichero cortado a medias no da fantasma", GhostRecord.cargar(PRUEBA) == null, "")

	# Magia cambiada: cualquier fichero del tamaño justo se colaría sin esto.
	var mala: PackedByteArray = crudo.duplicate()
	mala[0] = 0
	_escribir(mala)
	h.check("un fichero que no es nuestro tampoco", GhostRecord.cargar(PRUEBA) == null, "")

	# Versión futura: se descarta entera en vez de interpretarla a medias.
	var futura: PackedByteArray = crudo.duplicate()
	futura[4] = GhostRecord.VERSION + 1
	_escribir(futura)
	h.check("ni uno de otra versión", GhostRecord.cargar(PRUEBA) == null, "")
	GhostRecord.borrar(PRUEBA)


## Y lo mismo pero con el juego entero montado: sin fichero se juega igual.
func _sin_fichero_el_juego_arranca_igual() -> void:
	GhostRecord.borrar()
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.check("sin fichero no hay fantasma cargado", main.ghost.registro() == null, "")
	main.start_code(CODIGO)
	main.change_state(GameState.State.PLAYING)
	main.bird.collision_mask = 0
	await _volar(main, 60)
	h.check(
		"y la partida corre igual",
		main.get_state() == GameState.State.PLAYING,
		"estado: %s" % GameState.State.keys()[main.get_state()]
	)
	h.check("sin nada que reproducir", not main.ghost.esta_reproduciendo(), "")
	h.check("y sin fantasma en pantalla", not main.ghost.visible, "")
	main.free()


## El corazón del ticket: se graba un vuelo y se vuelve a ver igual.
func _graba_al_batir_el_record_y_lo_reproduce() -> void:
	GhostRecord.borrar()
	SaveManager.clear()
	SaveManager.forget_cache()

	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.start_code(CODIGO)
	main.change_state(GameState.State.PLAYING)
	# Sin colisiones con tuberías: el vuelo tiene que durar lo bastante para
	# que comparar frame a frame signifique algo. Puntúa igual, porque la
	# zona de punto es un `Area2D` y mira la capa de Flapo, no su máscara.
	main.bird.collision_mask = 0
	await _volar(main, FRAMES)
	var puntos: int = main.get_score()
	var vuelo: PackedFloat32Array = main.ghost.grabado().duplicate()
	# Uno menos que los frames esperados es lo normal aquí: el primer
	# `await physics_frame` de un test cae en un frame que ya había empezado
	# cuando se llamó a `change_state`. Da igual, porque le pasa a las dos
	# partidas por igual; por eso abajo se compara contra el contador del
	# propio fantasma y no contra un índice adivinado.
	h.check(
		"premisa: se ha volado de verdad", vuelo.size() >= FRAMES - 1, "%d frames" % vuelo.size()
	)
	h.check(
		"premisa: y la trayectoria sube y baja",
		_recorrido(vuelo) > 40.0,
		"%.1f px" % _recorrido(vuelo)
	)
	h.check("premisa: y ha puntuado, así que es récord", puntos >= 1, "%d puntos" % puntos)
	_morir(main)

	var disco: GhostRecord = GhostRecord.cargar()
	h.check("al batir el récord se guarda el fantasma", disco != null, "")
	if disco == null:
		main.free()
		return
	h.check(
		"con la semilla de esa partida",
		disco.semilla == main.session().seed(),
		"guardada %d, jugada %d" % [disco.semilla, main.session().seed()]
	)
	h.check(
		"y el vuelo entero, tal cual",
		disco.posiciones == vuelo,
		"%d frames guardados de %d" % [disco.frames(), vuelo.size()]
	)
	main.free()

	# Juego nuevo: el fantasma sale del DISCO, no de la copia en memoria.
	var otro: Node = await h.montar(MAIN, {"log_transitions": false})
	h.check("un juego recién abierto lo encuentra", otro.ghost.registro() != null, "")
	otro.start_code(CODIGO)
	otro.change_state(GameState.State.PLAYING)
	otro.bird.collision_mask = 0
	h.check("y con la misma semilla, sale a volar", otro.ghost.esta_reproduciendo(), "")
	h.check("y se ve", otro.ghost.visible, "")

	var desajustes: int = 0
	var comparados: int = 0
	var peor: float = 0.0
	for i in vuelo.size() + 1:
		await physics_frame
		# El fantasma dice por qué frame va: así la comparación no depende de
		# en qué momento exacto arrancó el bucle del test.
		var frame: int = otro.ghost.frames_reproducidos() - 1
		if frame < 0 or frame >= vuelo.size():
			continue
		comparados += 1
		var diferencia: float = absf(otro.ghost.position.y - vuelo[frame])
		peor = maxf(peor, diferencia)
		if diferencia > 0.001:
			desajustes += 1
	h.check(
		"premisa: se han comparado todos los frames del vuelo",
		comparados == vuelo.size(),
		"%d comparados de %d" % [comparados, vuelo.size()]
	)
	h.check(
		"el fantasma repite el vuelo grabado frame a frame",
		desajustes == 0,
		"%d frames descuadrados de %d, el peor por %.4f px" % [desajustes, comparados, peor]
	)
	h.check(
		"y vuela por el carril de Flapo, no por otro sitio",
		is_equal_approx(otro.ghost.position.x, otro.bird.position.x),
		"fantasma x %.2f, Flapo x %.2f" % [otro.ghost.position.x, otro.bird.position.x]
	)
	otro.free()


## El fantasma es el del RÉCORD: una partida peor no lo sustituye.
##
## Sin esto, cada muerte sobrescribiría el fichero y el "fantasma del récord"
## sería en realidad "el fantasma de la última vez", que es otra cosa y
## bastante menos útil.
func _una_partida_peor_no_pisa_el_fantasma() -> void:
	var antes: GhostRecord = GhostRecord.cargar()
	h.check("premisa: hay un fantasma del récord guardado", antes != null, "")
	if antes == null:
		return
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.start_code(CODIGO)
	main.change_state(GameState.State.PLAYING)
	main.bird.collision_mask = 0
	await _volar(main, 40)
	h.check(
		"premisa: esta partida puntúa menos que el récord",
		main.get_score() < SaveManager.get_high_score(),
		"%d puntos frente a un récord de %d" % [main.get_score(), SaveManager.get_high_score()]
	)
	h.check("premisa: y ha grabado un vuelo distinto", main.ghost.grabado().size() > 0, "")
	_morir(main)
	main.free()
	var despues: GhostRecord = GhostRecord.cargar()
	h.check(
		"una partida peor no pisa el fantasma del récord",
		despues != null and despues.posiciones == antes.posiciones,
		(
			"%d frames antes, %d después"
			% [antes.frames(), -1 if despues == null else despues.frames()]
		)
	)


## Con otras tuberías, el vuelo grabado no significa nada: no sale.
func _con_otra_semilla_no_sale() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.check("premisa: hay un fantasma guardado", main.ghost.registro() != null, "")
	main.start_code(OTRO)
	main.change_state(GameState.State.PLAYING)
	await h.ticks(4)
	h.check("con otra semilla el fantasma no sale", not main.ghost.esta_reproduciendo(), "")
	h.check("ni se ve", not main.ghost.visible, "")
	main.free()


## Criterio: el fantasma no colisiona, no puntúa ni toca el RNG.
##
## Se comprueba por comparación y no por inspección: la misma partida, con
## los mismos inputs, una vez con el fantasma volando y otra sin fichero. Si
## el fantasma pidiera un solo número al generador, las tuberías se moverían.
func _no_puntua_ni_toca_el_rng() -> void:
	var con: Array = await _partida_con_huella(true)
	var sin: Array = await _partida_con_huella(false)
	h.check("premisa: el fantasma volaba en la primera", con[2], "")
	h.check("premisa: y no en la segunda", not sin[2], "")
	h.check("premisa: han salido tuberías", con[0].size() > 2, "%d" % con[0].size())
	h.check(
		"con fantasma salen exactamente las mismas tuberías",
		con[0] == sin[0],
		"%s vs %s" % [str(con[0]), str(sin[0])]
	)
	h.check(
		"y la misma puntuación: el fantasma no puntúa",
		con[1] == sin[1],
		"con fantasma %d, sin fantasma %d" % [con[1], sin[1]]
	)


## Criterio: no colisiona. No por un flag apagado, sino porque en toda la
## escena del fantasma no hay una sola forma de colisión que encender.
func _no_tiene_una_sola_forma_de_colision() -> void:
	var nodo: Node = load(GHOST).instantiate()
	var culpables: Array = []
	_buscar_colisiones(nodo, culpables)
	h.check(
		"la escena del fantasma no tiene ninguna forma de colisión",
		culpables.is_empty(),
		"%s" % str(culpables)
	)
	h.check("y no es un cuerpo físico", not nodo is CollisionObject2D, "")
	nodo.free()


func _buscar_colisiones(nodo: Node, culpables: Array) -> void:
	if nodo is CollisionObject2D or nodo is CollisionShape2D or nodo is CollisionPolygon2D:
		culpables.append(nodo.name)
	for hijo in nodo.get_children():
		_buscar_colisiones(hijo, culpables)


## Corre una partida del mismo código con o sin fichero de fantasma, y
## devuelve [secuencia de tuberías, puntuación, si el fantasma volaba].
func _partida_con_huella(con_fantasma: bool) -> Array:
	if not con_fantasma:
		GhostRecord.borrar()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.start_code(CODIGO)
	main.change_state(GameState.State.PLAYING)
	main.bird.collision_mask = 0
	var volaba: bool = main.ghost.esta_reproduciendo()
	var vistas: Dictionary = {}
	var orden: Array = []
	for tick in FRAMES:
		await _tick_volando(main, tick)
		for hijo in main.pipe_spawner.get_children():
			if hijo is Pipe and not vistas.has(hijo.get_instance_id()):
				vistas[hijo.get_instance_id()] = true
				(
					orden
					. append(
						[
							snappedf(hijo.get_base_gap_center(), 0.01),
							hijo.soft,
							hijo.spin,
							snappedf(hijo.oscillation_amplitude, 0.01),
						]
					)
				)
	var resultado: Array = [orden, main.get_score(), volaba]
	main.free()
	return resultado


## El piloto automático: un aleteo cada `CADA` frames, siempre igual.
func _volar(main: Node, frames: int) -> void:
	for tick in frames:
		await _tick_volando(main, tick)


func _tick_volando(_main: Node, tick: int) -> void:
	if tick % CADA == 0:
		h.pulsa(KEY_SPACE)
	elif tick % CADA == 1:
		h.pulsa(KEY_SPACE, false)
	await physics_frame


## Cuánto sube y baja un vuelo. Sirve de premisa: comparar frame a frame una
## línea recta no demostraría nada.
func _recorrido(vuelo: PackedFloat32Array) -> float:
	var alto: float = vuelo[0]
	var bajo: float = vuelo[0]
	for y in vuelo:
		alto = minf(alto, y)
		bajo = maxf(bajo, y)
	return bajo - alto


## Mata a Flapo por la puerta de siempre. `change_state(GAME_OVER)` a secas
## se saltaría `_on_bird_died`, que es justo quien guarda el fantasma.
func _morir(main: Node) -> void:
	main._on_bird_died(Bird.DeathCause.SUELO, false)
