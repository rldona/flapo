extends SceneTree
## T-073 — Márgenes seguros y pantallas altas.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-073 · Márgenes seguros ---")
	_aritmetica_del_margen()
	_las_barras_no_son_negras()
	await _el_hud_se_coloca_solo()
	SaveManager.clear()
	quit(h.resumen("T-073"))


## En headless no hay pantalla que consultar, así que se prueba la conversión
## con notches inventados. Es la parte que se puede equivocar de verdad.
func _aritmetica_del_margen() -> void:
	var base: float = 24.0

	h.check(
		"sin notch, el margen es el de base",
		is_equal_approx(Hud.margen_seguro(2400, 0, base), base),
		"%.2f px" % Hud.margen_seguro(2400, 0, base)
	)
	h.check(
		"sin pantalla conocida, el margen es el de base",
		is_equal_approx(Hud.margen_seguro(0, 100, base), base),
		"%.2f px" % Hud.margen_seguro(0, 100, base)
	)

	# Móvil 1080x2400 (20:9) con un notch de 100 px reales.
	var m: float = Hud.margen_seguro(2400, 100, base)
	var esperado: float = base + 100.0 * (float(GameConfig.VIEWPORT_SIZE.y) / 2400.0)
	h.check(
		"el notch se convierte a píxeles de juego",
		is_equal_approx(m, esperado),
		"notch de 100 px reales en 2400 -> %.2f px de juego (total %.2f)" % [m - base, m]
	)
	h.check(
		"y el margen queda dentro de la pantalla",
		m < float(GameConfig.VIEWPORT_SIZE.y) * 0.25,
		"%.2f px sobre %d de alto" % [m, GameConfig.VIEWPORT_SIZE.y]
	)

	# Un notch enorme en una pantalla baja seguiría siendo razonable.
	var m2: float = Hud.margen_seguro(1280, 160, base)
	h.check(
		"un notch grande no empuja el HUD fuera de pantalla",
		m2 < float(GameConfig.VIEWPORT_SIZE.y) * 0.5,
		"%.2f px" % m2
	)


## Criterio: el fondo cubre de 16:9 a 21:9.
##
## Con `stretch/aspect = keep` (ADR-0002) el encuadre es idéntico en toda
## pantalla y lo que sobra son barras. La cuestión es de qué color: negras
## dejan un marco muerto en cualquier móvil que no sea 9:16 exacto.
func _las_barras_no_son_negras() -> void:
	var color: Color = ProjectSettings.get_setting(
		"rendering/environment/defaults/default_clear_color"
	)
	h.check(
		"las barras del letterbox son del color del cielo",
		color.r > 0.3 and color.b > color.r,
		"clear color: %s" % color
	)


## Y el HUD se coloca solo al arrancar, sin que nadie se lo pida.
func _el_hud_se_coloca_solo() -> void:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	var etiqueta: Label = main.hud.get_node("Score")
	h.check(
		"el HUD respeta el margen superior",
		etiqueta.offset_top >= main.hud.margen_superior,
		"offset_top %.2f, margen mínimo %.2f" % [etiqueta.offset_top, main.hud.margen_superior]
	)
	h.check(
		"y no invade la zona de juego",
		etiqueta.offset_bottom < GameConfig.playable_height() * 0.3,
		"offset_bottom %.2f" % etiqueta.offset_bottom
	)
	main.free()
