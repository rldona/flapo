extends SceneTree
## T-240 — Semilla determinista.
##
## La promesa del ticket es fuerte: **con la misma semilla y los mismos
## inputs, la partida es idéntica**. Así que el test no compara "parecido":
## graba la posición y el hueco de cada tubería frame a frame en dos partidas
## y exige que coincidan exactamente.
##
## Y comprueba lo contrario, que es igual de importante: **semillas distintas
## dan partidas distintas**. Sin ese caso, un juego que ignorara la semilla y
## generara siempre lo mismo pasaría el test.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-240 · Semilla determinista ---")
	_no_queda_aleatoriedad_suelta_en_scripts()
	await _la_misma_semilla_da_la_misma_partida()
	await _semillas_distintas_dan_partidas_distintas()
	await _reiniciar_repite_la_misma_partida()
	await _la_partida_libre_sortea_y_recuerda_su_semilla()
	SaveManager.clear()
	quit(h.resumen("T-240"))


## Criterio: `grep -r "randi\\|randf" scripts/` solo encuentra usos del RNG
## inyectado. Se comprueba aquí, y no en el `run.sh`, para que el criterio
## viva junto al resto de este ticket.
func _no_queda_aleatoriedad_suelta_en_scripts() -> void:
	var sueltos: Array = []
	var dir: DirAccess = DirAccess.open("res://scripts")
	for nombre in dir.get_files():
		if not nombre.ends_with(".gd"):
			continue
		# `juice.gd` queda fuera a propósito: la sacudida de cámara es
		# cosmética y no toca la simulación. Ver ADR-0030.
		if nombre == "juice.gd":
			continue
		var texto: String = FileAccess.get_file_as_string("res://scripts/" + nombre)
		var linea: int = 0
		for l in texto.split("\n"):
			linea += 1
			var limpia: String = l.strip_edges()
			if limpia.begins_with("#"):
				continue
			for patron in ["randi()", "randf()", "randf_range(", "randi_range(", "randomize()"]:
				# La regla: toda llamada tiene que salir de una variable
				# llamada `rng` — la de la partida o una inyectada como
				# parámetro. Lo que no menciona ningún `rng` es aleatoriedad
				# global, que es justo lo que este ticket elimina.
				if limpia.contains(patron) and not limpia.contains("rng"):
					sueltos.append("%s:%d %s" % [nombre, linea, limpia])
	h.check(
		"no queda aleatoriedad fuera del generador inyectado",
		sueltos.is_empty(),
		"%s" % str(sueltos)
	)


## La promesa: misma semilla, misma partida.
func _la_misma_semilla_da_la_misma_partida() -> void:
	var a: Array = await _grabar(12345)
	var b: Array = await _grabar(12345)
	h.check("premisa: se ha grabado algo", a.size() > 20, "%d muestras" % a.size())
	h.check(
		"premisa: y han salido tuberías de verdad",
		_tuberias_vistas(a) > 2,
		"%d tuberías" % _tuberias_vistas(a)
	)
	h.check(
		"dos partidas con la misma semilla son idénticas frame a frame",
		a == b,
		"%d muestras, primera diferencia en %d" % [a.size(), _primera_diferencia(a, b)]
	)


## Y el contrario, que es lo que evita un test que se cumple solo.
func _semillas_distintas_dan_partidas_distintas() -> void:
	var a: Array = await _grabar(12345)
	var c: Array = await _grabar(99999)
	h.check(
		"dos semillas distintas dan partidas distintas", a != c, "iguales pese a cambiar la semilla"
	)


## Reiniciar tiene que repetir la partida, no jugar otra: por eso el
## generador se resiembra en READY y no en `_ready()`.
##
## Aquí se compara la SECUENCIA de tuberías generadas, no su x frame a frame.
## No es una rebaja: es exactamente lo que la semilla determina. La x depende
## además de en qué frame arranca PLAYING, y al reiniciar a media sesión esa
## alineación cambia — medido: 1,67 px, justo un frame de scroll. Ver
## ADR-0030, "qué garantiza y qué no".
func _reiniciar_repite_la_misma_partida() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.set_seed(777)
	var primera: Array = await _secuencia(main)
	main.change_state(GameState.State.GAME_OVER)
	main.restart()
	await h.ticks(2)
	var segunda: Array = await _secuencia(main)
	h.check("premisa: se han generado tuberías", primera.size() > 2, "%d" % primera.size())
	h.check(
		"reiniciar genera exactamente la misma secuencia de tuberías",
		primera == segunda,
		"%s vs %s" % [str(primera), str(segunda)]
	)
	main.free()


## Con semilla 0 se sortea una, y se puede leer: es lo que hace posible
## T-242 (compartir el código de la partida que acabas de jugar).
func _la_partida_libre_sortea_y_recuerda_su_semilla() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var semillas: Array = []
	for intento in 3:
		var main: Node = await h.montar(MAIN, {"log_transitions": false})
		main.set_seed(GameConfig.SEED_ALEATORIA)
		h.jugar(main)
		await h.ticks(2)
		semillas.append(main.get_seed())
		main.free()
	h.check(
		"la partida libre se queda con una semilla concreta",
		not semillas.has(GameConfig.SEED_ALEATORIA),
		"%s" % str(semillas)
	)
	h.check(
		"y no es siempre la misma",
		semillas[0] != semillas[1] or semillas[1] != semillas[2],
		"%s" % str(semillas)
	)


## Corre una partida con esa semilla y devuelve su huella.
func _grabar(semilla: int) -> Array:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.set_seed(semilla)
	var huella: Array = await _correr(main)
	main.free()
	return huella


## La huella de una partida: qué tuberías hay, dónde y cómo, frame a frame.
##
## Se graban también las variantes (móvil, giratoria, blandita) y las frutas,
## porque son justo lo que el ticket dice que tiene que salir del mismo
## generador.
func _correr(main: Node) -> Array:
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	var huella: Array = []
	for tick in 420:
		await physics_frame
		var frame: Array = []
		for hijo in main.pipe_spawner.get_children():
			if hijo is Pipe:
				var p: Pipe = hijo
				(
					frame
					. append(
						[
							snappedf(p.position.x, 0.01),
							snappedf(p.get_base_gap_center(), 0.01),
							p.soft,
							p.spin,
							snappedf(p.oscillation_amplitude, 0.01),
						]
					)
				)
		for hijo in main.fruit_spawner.get_children():
			if hijo is Fruit:
				frame.append(["fruta", hijo.kind, snappedf(hijo.position.x, 0.01)])
		huella.append(frame)
	return huella


## La secuencia de tuberías tal y como se van creando: altura del hueco y
## variantes. Todo esto sale del generador, así que es lo que la semilla
## determina, independientemente del frame en que arranque la partida.
func _secuencia(main: Node) -> Array:
	h.jugar(main)
	main.bird.collision_mask = 0
	main.bird.gravity = 0.0
	var vistas: Dictionary = {}
	var orden: Array = []
	for tick in 420:
		await physics_frame
		for hijo in main.pipe_spawner.get_children():
			if hijo is Pipe and not vistas.has(hijo.get_instance_id()):
				vistas[hijo.get_instance_id()] = true
				var p: Pipe = hijo
				(
					orden
					. append(
						[
							snappedf(p.get_base_gap_center(), 0.01),
							p.soft,
							p.spin,
							snappedf(p.oscillation_amplitude, 0.01),
						]
					)
				)
	return orden


func _tuberias_vistas(huella: Array) -> int:
	var maximo: int = 0
	for frame in huella:
		maximo = maxi(maximo, (frame as Array).size())
	return maximo


func _primera_diferencia(a: Array, b: Array) -> int:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return i
	return -1
