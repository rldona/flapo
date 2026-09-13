extends SceneTree
## Accesibilidad: contraste y tamaño de los controles (Fase 6).
##
## No tiene número de ticket propio: es el último punto de la Fase 6 del
## ROADMAP. Va como test porque las dos cosas que pide son medibles, y una
## regresión de contraste (cambiar un color de la paleta) es invisible hasta
## que alguien no distingue una tubería del cielo.

const MAIN := "res://scenes/Main.tscn"

## Mínimos de WCAG 2.1. Para elementos de interfaz y texto grande basta 3:1;
## el texto normal pide 4.5:1.
const MIN_UI: float = 3.0
const MIN_TEXTO: float = 4.5

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- Accesibilidad ---")
	_contraste_del_juego()
	await _tamano_de_los_botones()
	SaveManager.clear()
	Settings.clear()
	quit(h.resumen("Accesibilidad"))


## Luminancia relativa según WCAG: no es el brillo ingenuo, porque el ojo no
## pesa igual el rojo, el verde y el azul.
func _luminancia(c: Color) -> float:
	var canales: Array[float] = [c.r, c.g, c.b]
	var lin: Array[float] = []
	for v in canales:
		lin.append(v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


func _contraste(a: Color, b: Color) -> float:
	var la: float = _luminancia(a)
	var lb: float = _luminancia(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _contraste_del_juego() -> void:
	var cielo := Color("7CB3D7")
	var suelo := Color("D0AE62")
	var outline := Color("263B46")
	# Lo que separa una figura del fondo en pixel art es el CONTORNO, no el
	# relleno: el cuerpo de Flapo da 2,36:1 contra el cielo y se ve
	# perfectamente porque su outline da 5,17:1. Por eso lo que se exige a
	# 3:1 es el contorno de cada silueta, más el relleno de los obstáculos,
	# que ocupan mucha área y son lo que mata.
	var pares: Array = [
		["silueta de Flapo sobre el cielo", outline, cielo, MIN_UI],
		["silueta de la tubería sobre el cielo", outline, cielo, MIN_UI],
		["silueta del suelo sobre el cielo", outline, cielo, MIN_UI],
		["relleno de la tubería sobre el cielo", Color("3A5468"), cielo, MIN_UI],
		["relleno de la tubería sobre el suelo", Color("3A5468"), suelo, MIN_UI],
		["tripa de Flapo sobre su cuerpo", Color("F2D9A7"), Color("3F7188"), MIN_UI],
		["cifra del marcador sobre su contorno", Color("F2D9A7"), outline, MIN_TEXTO],
		["contorno de la cifra sobre el cielo", outline, cielo, MIN_TEXTO],
		# El fondo debe quedarse ATRÁS: poco contraste es lo correcto aquí,
		# y pasarse sería el bug (competiría con las tuberías).
		["edificios del fondo, deliberadamente suaves", Color("7C9AB5"), cielo, 1.2],
	]
	for par in pares:
		var r: float = _contraste(par[1], par[2])
		h.check("contraste: %s" % par[0], r >= par[3], "%.2f:1 (mínimo %.1f:1)" % [r, par[3]])


## Criterio del ROADMAP: botones ≥ 48 px en móvil **tras el escalado**.
##
## Con `stretch/scale_mode = integer` (ADR-0002) el factor es entero, así que
## el peor caso no es la pantalla más pequeña sino aquella cuyo factor entero
## queda más bajo. Se comprueban dos móviles reales.
func _tamano_de_los_botones() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	h.jugar(main)
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	for i in 180:
		await process_frame
		if main.game_over_panel.is_ready_for_input():
			break

	var botones: Dictionary = {
		"Otra vez": main.game_over_panel.get_node("Root/Box/Button"),
		"Sonido (Game Over)": main.game_over_panel.get_node("Root/Box/MuteButton"),
		"Seguir (pausa)": main.pause_panel.get_node("Root/Box/Button"),
		"Sonido (pausa)": main.pause_panel.get_node("Root/Box/MuteButton"),
	}
	# El velo de pausa está oculto y un Control oculto no calcula su tamaño.
	main.pause_panel.set_paused(true)
	await process_frame

	for nombre in botones:
		var alto: float = (botones[nombre] as Control).size.y
		h.check("botón '%s' mide 48 px de juego" % nombre, alto >= 48.0, "%.0f px" % alto)

	# Móviles de referencia: gama baja 720×1280 y gama media 1080×2400.
	# El factor entero es el mínimo entre ancho y alto, redondeado hacia abajo.
	for movil in [[720, 1280, 320.0], [1080, 2400, 420.0]]:
		var escala: int = maxi(
			1,
			mini(
				int(float(movil[0]) / float(GameConfig.VIEWPORT_SIZE.x)),
				int(float(movil[1]) / float(GameConfig.VIEWPORT_SIZE.y))
			)
		)
		var px_reales: float = 48.0 * float(escala)
		# dp = px / (dpi / 160). El mínimo táctil de Android es 48 dp.
		var dp: float = px_reales / (movil[2] / 160.0)
		h.check(
			"en %dx%d los botones llegan a 48 dp" % [movil[0], movil[1]],
			dp >= 48.0,
			"escala x%d -> %.0f px reales -> %.1f dp" % [escala, px_reales, dp]
		)
	main.pause_panel.set_paused(false)
	main.free()
