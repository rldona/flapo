extends SceneTree
## T-085 — Layout adaptativo por ventana.
##
## Todo el cálculo es una función pura del tamaño de ventana, así que se
## puede probar con tamaños inventados sin ventana de verdad — que es justo
## lo que hace falta en headless.
##
## Lo que se comprueba: escala **siempre entera**, **siempre la mayor que
## cabe**, playfield **centrado en cualquier proporción**, y que el director
## reacciona a cambios de tamaño en vivo emitiendo solo cuando cambia algo.

const MAIN := "res://scenes/Main.tscn"
const W: int = 288
const H: int = 512

## Tamaños de ventana de verdad, incluidas las proporciones raras.
const VENTANAS: Array = [
	Vector2i(288, 512),  # exacto 1x
	Vector2i(576, 1024),  # exacto 2x, el override del proyecto
	Vector2i(1920, 1080),  # 16:9 apaisado
	Vector2i(2560, 1080),  # 21:9 ultrapanorámico
	Vector2i(1024, 768),  # 4:3
	Vector2i(1080, 2400),  # móvil vertical
	Vector2i(390, 844),  # iPhone
	Vector2i(3840, 2160),  # 4K
	Vector2i(300, 2000),  # vertical extremo: manda el ancho
	Vector2i(2000, 300),  # apaisado extremo: manda el alto
	Vector2i(200, 300),  # más pequeña que el playfield
]

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-085 · Layout adaptativo ---")
	_la_escala_es_entera_y_la_mayor_que_cabe()
	_el_playfield_queda_centrado_en_cualquier_proporcion()
	_ventanas_imposibles_no_rompen_nada()
	await _el_director_reacciona_a_los_cambios_en_vivo()
	SaveManager.clear()
	quit(h.resumen("T-085"))


## Criterio: escala entera, sin píxeles fraccionados, y la mayor que cabe.
func _la_escala_es_entera_y_la_mayor_que_cabe() -> void:
	var fallos: Array = []
	for ventana in VENTANAS:
		var s: int = GameConfig.window_scale_for(ventana)
		# Que sea la MAYOR que cabe: la siguiente no debe caber (o estar en
		# el tope). Comprobar solo "cabe" dejaría pasar un 1x para siempre.
		var cabe: bool = W * s <= ventana.x and H * s <= ventana.y
		var siguiente_no_cabe: bool = (
			W * (s + 1) > ventana.x or H * (s + 1) > ventana.y or s >= GameConfig.MAX_WINDOW_SCALE
		)
		var minima: bool = s >= GameConfig.MIN_WINDOW_SCALE
		if not (minima and siguiente_no_cabe and (cabe or s == GameConfig.MIN_WINDOW_SCALE)):
			fallos.append("%s -> %d" % [ventana, s])
	h.check(
		"en %d ventanas la escala es la mayor entera que cabe" % VENTANAS.size(),
		fallos.is_empty(),
		"fallan: %s" % str(fallos)
	)
	# Casos concretos, para que el test diga números y no solo "pasa".
	h.check("576x1024 da 2x", GameConfig.window_scale_for(Vector2i(576, 1024)) == 2, "")
	h.check(
		"1920x1080 da 2x (manda el alto)",
		GameConfig.window_scale_for(Vector2i(1920, 1080)) == 2,
		"%d" % GameConfig.window_scale_for(Vector2i(1920, 1080))
	)
	h.check(
		"2560x1080 también da 2x: lo ancho no ayuda",
		GameConfig.window_scale_for(Vector2i(2560, 1080)) == 2,
		"%d" % GameConfig.window_scale_for(Vector2i(2560, 1080))
	)
	# En 4K manda el alto: 2160/512 = 4, aunque a lo ancho cabrían 13.
	h.check(
		"3840x2160 da 4x, no 13x: el playfield es vertical",
		GameConfig.window_scale_for(Vector2i(3840, 2160)) == 4,
		"%d" % GameConfig.window_scale_for(Vector2i(3840, 2160))
	)
	# Y el tope de GameConfig existe: una pantalla enorme no da 20x.
	h.check(
		"y por muy grande que sea la ventana, no pasa del tope",
		GameConfig.window_scale_for(Vector2i(10000, 10000)) == GameConfig.MAX_WINDOW_SCALE,
		"%d" % GameConfig.window_scale_for(Vector2i(10000, 10000))
	)
	# Un escalado fraccionario daría un tamaño que no es múltiplo del lógico.
	var no_multiplo: Array = []
	for ventana in VENTANAS:
		var caja: Rect2i = GameConfig.playfield_rect_for(ventana)
		if caja.size.x % W != 0 or caja.size.y % H != 0:
			no_multiplo.append("%s -> %s" % [ventana, caja.size])
	h.check(
		"y el playfield siempre mide un múltiplo exacto de 288x512",
		no_multiplo.is_empty(),
		"fallan: %s" % str(no_multiplo)
	)


## Criterio: centrado en cualquier proporción.
func _el_playfield_queda_centrado_en_cualquier_proporcion() -> void:
	var descentradas: Array = []
	for ventana in VENTANAS:
		var caja: Rect2i = GameConfig.playfield_rect_for(ventana)
		# Lo que sobra a un lado y al otro no puede diferir en más de 1 px:
		# con tamaños impares uno de los dos lados se lleva el píxel suelto.
		var izq: int = caja.position.x
		var der: int = ventana.x - (caja.position.x + caja.size.x)
		var arr: int = caja.position.y
		var aba: int = ventana.y - (caja.position.y + caja.size.y)
		if absi(izq - der) > 1 or absi(arr - aba) > 1:
			descentradas.append("%s: h %d/%d, v %d/%d" % [ventana, izq, der, arr, aba])
	h.check(
		"centrado en las %d proporciones" % VENTANAS.size(),
		descentradas.is_empty(),
		"descentradas: %s" % str(descentradas)
	)
	# Y el margen publicado es el de UN lado, no la suma: es lo que decide
	# si cabe un panel al lado (T-086).
	var ancha := Vector2i(2560, 1080)
	var caja: Rect2i = GameConfig.playfield_rect_for(ancha)
	h.check(
		"el margen publicado es el de un lado",
		GameConfig.layout_margin_for(ancha).x == caja.position.x,
		"margen %d, borde izquierdo %d" % [GameConfig.layout_margin_for(ancha).x, caja.position.x]
	)
	h.check(
		"y en 21:9 sobra sitio de verdad a los lados",
		GameConfig.layout_margin_for(ancha).x > 0,
		"%d px" % GameConfig.layout_margin_for(ancha).x
	)
	# En un móvil también sobra algo, pero un orden de magnitud menos: es esa
	# diferencia la que T-086 convertirá en umbrales, no un sí/no.
	var movil: int = GameConfig.layout_margin_for(Vector2i(390, 844)).x
	h.check(
		"y en un móvil sobra mucho menos que en 21:9",
		movil > 0 and movil < GameConfig.layout_margin_for(ancha).x / 10,
		"móvil %d px frente a 21:9 %d px" % [movil, GameConfig.layout_margin_for(ancha).x]
	)
	# Que quepa el playfield entero es la condición que no se negocia.
	var no_cabe: Array = []
	for ventana in VENTANAS:
		var c: Rect2i = GameConfig.playfield_rect_for(ventana)
		if ventana.x >= W and ventana.y >= H:
			if c.position.x < 0 or c.position.y < 0:
				no_cabe.append("%s -> %s" % [ventana, c])
	h.check(
		"y en toda ventana que da de sí, el playfield cabe entero",
		no_cabe.is_empty(),
		"fallan: %s" % str(no_cabe)
	)


## Una ventana de 0 px o más pequeña que el playfield no puede reventar.
func _ventanas_imposibles_no_rompen_nada() -> void:
	for ventana in [Vector2i(0, 0), Vector2i(-100, -100), Vector2i(1, 1)]:
		h.check(
			"%s no baja de la escala mínima" % ventana,
			GameConfig.window_scale_for(ventana) == GameConfig.MIN_WINDOW_SCALE,
			"%d" % GameConfig.window_scale_for(ventana)
		)
	h.check(
		"y con la ventana más pequeña que el playfield el margen es 0, no negativo",
		GameConfig.layout_margin_for(Vector2i(200, 300)) == Vector2i.ZERO,
		"%s" % GameConfig.layout_margin_for(Vector2i(200, 300))
	)


## Criterio: recalcula EN VIVO, no solo al arrancar.
func _el_director_reacciona_a_los_cambios_en_vivo() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	var director: LayoutDirector = main.layout
	h.check("premisa: Main tiene el director cableado", director != null, "")
	if director == null:
		main.free()
		return

	var avisos: Array = []
	director.layout_changed.connect(
		func(e: int, caja: Rect2i, m: Vector2i) -> void: avisos.append([e, caja, m])
	)

	# Se simula el arrastre del borde de la ventana.
	director.update_for(Vector2i(576, 1024))
	h.check("un tamaño nuevo avisa", avisos.size() == 1, "%d avisos" % avisos.size())
	h.check("con la escala que toca", director.scale_factor() == 2, "%d" % director.scale_factor())

	# El mismo tamaño otra vez no vuelve a avisar: arrastrar un borde dispara
	# size_changed en cada píxel y la escala entera cambia una vez cada 288.
	director.update_for(Vector2i(576, 1024))
	h.check("repetir el mismo tamaño no avisa", avisos.size() == 1, "%d avisos" % avisos.size())

	# Un cambio pequeño que no cambia ni la escala ni el centrado tampoco.
	director.update_for(Vector2i(577, 1025))
	var avisos_tras_pequeno: int = avisos.size()
	director.update_for(Vector2i(1200, 1600))
	h.check(
		"pero un cambio que sí mueve el layout avisa otra vez",
		avisos.size() > avisos_tras_pequeno,
		"%d avisos" % avisos.size()
	)
	h.check(
		"y a 1200x1600 la escala sube a 3",
		director.scale_factor() == 3,
		"%d" % director.scale_factor()
	)
	h.check(
		"el playfield publicado coincide con el cálculo puro",
		director.playfield() == GameConfig.playfield_rect_for(Vector2i(1200, 1600)),
		"%s" % director.playfield()
	)
	# Y volver atrás vuelve a bajar: no es un trinquete.
	director.update_for(Vector2i(576, 1024))
	h.check(
		"encoger la ventana vuelve a bajar la escala",
		director.scale_factor() == 2,
		"%d" % director.scale_factor()
	)
	main.free()
