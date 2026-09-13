extends SceneTree
## T-066 — Tubería "blandita".
##
## Lo que se comprueba: que es **predecible** (no aleatoria), que se
## **distingue en el dibujo desde que nace** y no solo al chocar, que tocarla
## **no acaba la partida** y que sí **cuesta** aliento y punto — una vez por
## toque, no sesenta veces por segundo mientras se roza.

const MAIN := "res://scenes/Main.tscn"
const PIPE := "res://scenes/Pipe.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-066 · Tubería blandita ---")
	_es_predecible_y_no_aleatoria()
	await _se_distingue_desde_que_nace()
	await _tocarla_no_mata_y_rebota()
	await _cuesta_aliento_y_punto_una_vez_por_toque()
	await _tocar_una_normal_sigue_matando()
	SaveManager.clear()
	quit(h.resumen("T-066"))


## Criterio implícito del ticket: predecible, para poder buscarla a propósito.
func _es_predecible_y_no_aleatoria() -> void:
	var n: int = GameConfig.SOFT_PIPE_INTERVAL
	h.check("la primera tubería nunca es blandita", not GameConfig.is_soft_pipe(0), "")
	h.check("la número %d sí" % n, GameConfig.is_soft_pipe(n), "")
	h.check("la %d también" % (n * 2), GameConfig.is_soft_pipe(n * 2), "")
	var entre: bool = false
	for i in range(1, n):
		if GameConfig.is_soft_pipe(i):
			entre = true
	h.check("y ninguna de las de en medio", not entre, "")


## Criterio: distinguible desde que entra en pantalla, no solo al chocar.
func _se_distingue_desde_que_nace() -> void:
	var escena: PackedScene = load(PIPE)
	var normal: Pipe = escena.instantiate()
	var blandita: Pipe = escena.instantiate()
	# El orden es el del spawner: se marca ANTES de add_child, que es cuando
	# los sprites todavía no existen. Si el tinte solo se aplicara en el
	# setter, la tubería nacería del color normal.
	blandita.soft = true
	root.add_child(normal)
	root.add_child(blandita)
	await process_frame

	h.check(
		"la blandita se dibuja de otro color en su primer frame",
		blandita.tint() != normal.tint(),
		"blandita %s vs normal %s" % [blandita.tint(), normal.tint()]
	)
	h.check(
		"y el color es el declarado en GameConfig",
		blandita.tint().is_equal_approx(GameConfig.SOFT_PIPE_TINT),
		"%s" % blandita.tint()
	)
	# El contraste no lo juzga un test, pero sí que no sean casi el mismo
	# color: eso sí se puede medir.
	var d: float = (
		absf(blandita.tint().r - normal.tint().r)
		+ absf(blandita.tint().g - normal.tint().g)
		+ absf(blandita.tint().b - normal.tint().b)
	)
	h.check("y no es un matiz imperceptible", d > 0.3, "distancia de color: %.2f" % d)
	normal.free()
	blandita.free()


## Criterio: tocarla no dispara GAME_OVER.
func _tocarla_no_mata_y_rebota() -> void:
	var main: Node = await _partida_con_una_blandita()
	var bird: Node = main.bird
	var pipe: Pipe = _primera_pipe(main)
	h.check("premisa: hay una tubería blandita en escena", pipe != null and pipe.soft, "")
	if pipe == null:
		main.free()
		return

	# Se mete a Flapo dentro del tubo de arriba, que con una normal es muerte
	# segura (lo comprueba el último caso de este mismo fichero).
	var top: Node2D = pipe.get_node("Top")
	bird.global_position = top.global_position
	bird.velocity = Vector2.ZERO
	var x_antes: float = bird.global_position.x
	var dentro_y: float = bird.global_position.y
	for tick in 30:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break

	h.check(
		"tocar la blandita no acaba la partida",
		main.get_state() == GameState.State.PLAYING,
		"estado: %d" % main.get_state()
	)
	h.check(
		"sale despedido a la velocidad declarada",
		is_equal_approx(absf(bird.velocity.y), GameConfig.SOFT_PIPE_BOUNCE_SPEED),
		"velocity %s" % bird.velocity
	)
	# El bug que esto vigila: rebotar por la normal del contacto mandaba a
	# Flapo de lado, y Flapo NO tiene eje horizontal. Se iba de la pantalla.
	h.check(
		"y sin moverse ni un píxel en horizontal",
		is_equal_approx(bird.global_position.x, x_antes) and is_zero_approx(bird.velocity.x),
		"x %.1f -> %.1f, velocity.x %.1f" % [x_antes, bird.global_position.x, bird.velocity.x]
	)
	# Y le empuja HACIA el hueco, que es lo que hace que perdone de verdad.
	var centro_hueco: float = pipe.global_position.y + pipe.get_gap_center()
	h.check(
		"y hacia el hueco, no hacia afuera",
		signf(bird.velocity.y) == signf(centro_hueco - dentro_y),
		(
			"velocity.y %.1f, Flapo en y=%.1f, hueco en y=%.1f"
			% [bird.velocity.y, dentro_y, centro_hueco]
		)
	)
	main.free()


## Criterio: y sí aplica el coste definido, una sola vez por toque.
func _cuesta_aliento_y_punto_una_vez_por_toque() -> void:
	var main: Node = await _partida_con_una_blandita()
	var bird: Node = main.bird
	var pipe: Pipe = _primera_pipe(main)
	if pipe == null:
		h.check("premisa: hay tubería blandita", false, "no ha salido ninguna")
		main.free()
		return

	# Un marcador de partida, para poder ver el punto que se pierde.
	for punto in 5:
		main._on_scored()
	var puntos_antes: int = main.get_score()
	var aliento_antes: float = bird.breath()

	# Un Array y no un int: los lambdas de GDScript capturan las variables
	# locales POR VALOR, así que un `toques += 1` dentro incrementaría una
	# copia y el contador se quedaría a 0 para siempre.
	var toques: Array = [0]
	bird.soft_hit.connect(func() -> void: toques[0] += 1)
	var top: Node2D = pipe.get_node("Top")
	bird.global_position = top.global_position
	bird.velocity = Vector2.ZERO
	# Medio segundo: dentro del enfriamiento, así que por muchos frames que
	# esté rozando solo puede cobrar una vez.
	for tick in 30:
		await physics_frame

	h.check(
		"cobra una sola vez, no en cada frame", toques[0] == 1, "%d cobros en 30 frames" % toques[0]
	)
	h.check(
		"cuesta aliento",
		bird.breath() < aliento_antes,
		"%.1f -> %.1f" % [aliento_antes, bird.breath()]
	)
	h.check(
		"y exactamente el declarado en GameConfig",
		is_equal_approx(aliento_antes - bird.breath(), GameConfig.SOFT_PIPE_BREATH_COST),
		"%.1f de coste" % (aliento_antes - bird.breath())
	)
	h.check(
		"y cuesta el punto declarado",
		main.get_score() == puntos_antes - GameConfig.SOFT_PIPE_SCORE_COST,
		"%d -> %d" % [puntos_antes, main.get_score()]
	)
	h.check(
		"pero la partida sigue viva",
		main.get_state() == GameState.State.PLAYING,
		"estado: %d" % main.get_state()
	)

	# Y el marcador nunca baja de 0: un negativo no se puede recuperar.
	# Se cobra más veces de las que hay puntos, a propósito.
	bird.collision_mask = 0
	var minimo: int = main.get_score()
	for i in main.get_score() + 3:
		main._on_soft_hit()
		minimo = mini(minimo, main.get_score())
	h.check(
		"el marcador nunca baja de 0, por muchos golpes que reciba",
		minimo == 0 and main.get_score() == 0,
		"mínimo visto %d, final %d" % [minimo, main.get_score()]
	)
	main.free()


## La contraprueba: una tubería normal en el mismo sitio sí mata. Sin esto,
## el caso de arriba podría estar pasando porque Flapo no toca nada.
func _tocar_una_normal_sigue_matando() -> void:
	var main: Node = await _partida(0)  # Sin blanditas: la primera es normal.
	var pipe: Pipe = _primera_pipe(main)
	h.check("premisa: la tubería NO es blandita", pipe != null and not pipe.soft, "")
	if pipe == null:
		main.free()
		return
	var top: Node2D = pipe.get_node("Top")
	main.bird.global_position = top.global_position
	main.bird.velocity = Vector2.ZERO
	for tick in 30:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	h.check(
		"una tubería normal en el mismo sitio sí mata",
		main.get_state() == GameState.State.GAME_OVER,
		"estado: %d" % main.get_state()
	)
	main.free()


## Monta una partida y espera a que salga la primera tubería.
##
## `soft_forzada` fuerza que esa primera sea blandita o no, sin tocar el
## intervalo: probar el comportamiento no debería exigir esperar siete
## tuberías.
func _partida(soft_forzada: int) -> Node:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.fruit_spawner.chance = 0.0
	main.pipe_spawner.random_seed = 3
	h.jugar(main)
	# Después de arrancar: entrar en READY le devuelve la máscara a Flapo.
	main.bird.gravity = 0.0
	for tick in 300:
		await physics_frame
		var pipe: Pipe = _primera_pipe(main)
		if pipe != null:
			pipe.soft = soft_forzada == 1
			return main
	return main


func _partida_con_una_blandita() -> Node:
	return await _partida(1)


func _primera_pipe(main: Node) -> Pipe:
	for hijo in main.pipe_spawner.get_children():
		if hijo is Pipe:
			return hijo as Pipe
	return null
