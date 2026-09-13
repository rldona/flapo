extends SceneTree
## T-024 — Par de tuberías con hueco.

const PIPE := "res://scenes/Pipe.tscn"
const BIRD := "res://scenes/Bird.tscn"

var h: Harness
## Los lambdas de GDScript capturan las locales POR VALOR: asignar dentro del
## lambda no cambia la variable de fuera. Por eso el flag es un miembro.
var _choco: bool = false


func _init() -> void:
	h = Harness.new(self)
	print("--- T-024 · Pipe ---")
	await _hueco_y_rango_exportados()
	await _hueco_aleatorio_dentro_del_rango()
	await _cada_tuberia_tiene_su_propia_forma()
	await _flapo_choca_con_el_tubo_y_pasa_por_el_hueco()
	await _no_deja_nodos_huerfanos()
	quit(h.resumen("T-024"))


## Criterio: hueco y rango como `@export`.
func _hueco_y_rango_exportados() -> void:
	var pipe: Node = await h.montar(PIPE)
	var exportadas: Array[String] = []
	for prop in pipe.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_EDITOR:
			exportadas.append(prop.name)
	for nombre in ["gap", "gap_center_min_ratio", "gap_center_max_ratio"]:
		h.check("`%s` es @export" % nombre, exportadas.has(nombre), "")
	pipe.free()


## El centro del hueco nunca cae fuera del rango, ni siquiera en 500 sorteos.
func _hueco_aleatorio_dentro_del_rango() -> void:
	var pipe: Node = await h.montar(PIPE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var minimo: float = INF
	var maximo: float = -INF
	for i in 500:
		pipe.randomize_gap(rng)
		minimo = minf(minimo, pipe.get_gap_center())
		maximo = maxf(maximo, pipe.get_gap_center())
	var limite_bajo: float = pipe.gap_center_min_ratio * pipe.playable_height
	var limite_alto: float = pipe.gap_center_max_ratio * pipe.playable_height
	h.check(
		"el hueco cae dentro del rango",
		minimo >= limite_bajo and maximo <= limite_alto,
		"centros en [%.1f, %.1f], rango [%.1f, %.1f]" % [minimo, maximo, limite_bajo, limite_alto]
	)
	# Mismo generador, misma semilla, misma partida: hace falta para T-080.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345
	pipe.randomize_gap(rng2)
	var primero: float = pipe.get_gap_center()
	rng2.seed = 12345
	pipe.randomize_gap(rng2)
	h.check(
		"sortear es reproducible con la misma semilla",
		is_equal_approx(primero, pipe.get_gap_center()),
		"%.3f vs %.3f" % [primero, pipe.get_gap_center()]
	)
	pipe.free()


## Trampa de los sub-recursos: si la forma viviera en el .tscn, sería la misma
## en todas las instancias y cambiar una las cambiaría todas.
func _cada_tuberia_tiene_su_propia_forma() -> void:
	var a: Node = await h.montar(PIPE)
	var b: Node = await h.montar(PIPE)
	var forma_a: Shape2D = a.get_node("Top/CollisionShape2D").shape
	var forma_b: Shape2D = b.get_node("Top/CollisionShape2D").shape
	h.check(
		"cada tubería tiene su propia forma de colisión",
		forma_a != forma_b,
		"rid_a=%s rid_b=%s" % [forma_a.get_rid(), forma_b.get_rid()]
	)
	a.free()
	b.free()


## Lo que de verdad importa: el tubo mata y el hueco deja pasar.
func _flapo_choca_con_el_tubo_y_pasa_por_el_hueco() -> void:
	for caso in [{"y": 60.0, "choca": true}, {"y": 256.0, "choca": false}]:
		var mundo := Node2D.new()
		root.add_child(mundo)
		var pipe: Node = load(PIPE).instantiate()
		pipe.moving = false
		pipe.position = Vector2(100.0, 0.0)
		mundo.add_child(pipe)
		var bird: Node = load(BIRD).instantiate()
		bird.gravity = 0.0
		bird.position = Vector2(40.0, caso["y"])
		mundo.add_child(bird)
		await process_frame
		pipe.set_gap_center(256.0)

		_choco = false
		bird.died.connect(_on_died)
		bird._state = GameState.State.PLAYING
		for i in 120:
			bird.velocity = Vector2(120.0, 0.0)
			await physics_frame
			if _choco:
				break
		h.check(
			"a y=%.0f Flapo %s" % [caso["y"], "choca" if caso["choca"] else "pasa"],
			_choco == caso["choca"],
			"x final %.1f, chocó=%s" % [bird.position.x, _choco]
		)
		mundo.free()


func _on_died() -> void:
	_choco = true


## Criterio: no quedan nodos huérfanos tras 5 minutos.
##
## 5 min reales a 60 Hz son 18 000 ticks. Se simulan de verdad: es la ventaja
## de headless sobre mirar el monitor de nodos con paciencia (ADR-0007).
func _no_deja_nodos_huerfanos() -> void:
	var mundo := Node2D.new()
	root.add_child(mundo)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var escena: PackedScene = load(PIPE)
	var intervalo: int = int(round(GameConfig.pipe_spawn_interval() * 60.0))
	var total_ticks: int = 18000
	var creadas: int = 0
	var pico: int = 0

	for tick in total_ticks:
		if tick % intervalo == 0:
			var pipe: Node = escena.instantiate()
			pipe.position = Vector2(float(GameConfig.VIEWPORT_SIZE.x) + 32.0, 0.0)
			mundo.add_child(pipe)
			pipe.randomize_gap(rng)
			creadas += 1
		await physics_frame
		pico = maxi(pico, mundo.get_child_count())

	var vivas: int = mundo.get_child_count()
	# En pantalla caben 288/160 + margen: nunca debería haber más de 4 vivas.
	h.check(
		"las tuberías se liberan al salir de pantalla",
		vivas <= 4,
		"creadas %d en 5 min, vivas al final %d, pico %d" % [creadas, vivas, pico]
	)
	h.check(
		"el número de tuberías vivas se estabiliza",
		pico <= 4,
		"pico de tuberías simultáneas: %d" % pico
	)
	mundo.free()
	# Godot cuenta como huérfano todo nodo creado y no liberado.
	var huerfanos: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	h.check("sin nodos huérfanos", huerfanos == 0, "huérfanos: %d" % huerfanos)
