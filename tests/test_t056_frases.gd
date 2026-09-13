extends SceneTree
## T-056 — Reacciones variables al morir.

const MAIN := "res://scenes/Main.tscn"
const RECURSO := "res://assets/data/death_lines.tres"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-056 · Frases al morir ---")
	_el_recurso_tiene_frases_suficientes()
	_nunca_repite_dos_veces_seguidas()
	_casos_limite_del_selector()
	await _el_panel_ensena_una_frase()
	SaveManager.clear()
	Settings.clear()
	quit(h.resumen("T-056"))


func _lineas() -> DeathLines:
	return load(RECURSO) as DeathLines


## Criterio: 8 frases o más, en un recurso propio.
func _el_recurso_tiene_frases_suficientes() -> void:
	var d: DeathLines = _lineas()
	h.check("el recurso de frases carga", d != null, RECURSO)
	if d == null:
		return
	h.check("hay al menos 8 frases", d.lines.size() >= 8, "%d frases" % d.lines.size())
	var vacias: int = 0
	var largas: int = 0
	for linea in d.lines:
		if linea.strip_edges() == "":
			vacias += 1
		# El panel mide 160 px de ancho: una frase larga se sale o se corta.
		if linea.length() > 34:
			largas += 1
	h.check("ninguna frase está vacía", vacias == 0, "%d vacías" % vacias)
	h.check(
		"ninguna frase se sale del panel", largas == 0, "%d frases de más de 34 caracteres" % largas
	)


## Criterio: no sale la misma frase dos veces seguidas.
func _nunca_repite_dos_veces_seguidas() -> void:
	var d: DeathLines = _lineas()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var ultima: String = ""
	var repeticiones: int = 0
	var distintas: Dictionary = {}
	for i in 500:
		var frase: String = d.pick(rng, ultima)
		if frase == ultima:
			repeticiones += 1
		distintas[frase] = true
		ultima = frase
	h.check(
		"nunca repite dos veces seguidas",
		repeticiones == 0,
		"%d repeticiones en 500 muertes" % repeticiones
	)
	# Y que use el repertorio: si solo saliera media lista, el azar estaría mal.
	h.check(
		"usa todas las frases",
		distintas.size() == d.lines.size(),
		"%d de %d frases vistas en 500 tiradas" % [distintas.size(), d.lines.size()]
	)


## Criterio: el selector no rompe con una lista de un solo elemento.
func _casos_limite_del_selector() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	var una := DeathLines.new()
	una.lines = PackedStringArray(["Solo esta"])
	h.check(
		"con una sola frase la devuelve, aunque se repita",
		una.pick(rng, "Solo esta") == "Solo esta",
		"mejor repetir que dejar el panel en blanco"
	)

	var vacia := DeathLines.new()
	vacia.lines = PackedStringArray()
	h.check(
		"con la lista vacía devuelve cadena vacía y no revienta",
		vacia.pick(rng, "loquesea") == "",
		""
	)

	var dos := DeathLines.new()
	dos.lines = PackedStringArray(["A", "B"])
	h.check("con dos frases alterna", dos.pick(rng, "A") == "B" and dos.pick(rng, "B") == "A", "")


## Y en una partida real la frase llega al panel.
func _el_panel_ensena_una_frase() -> void:
	SaveManager.clear()
	SaveManager.forget_cache()
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 3
	main.fruit_spawner.chance = 0.0
	var titulo: Label = main.game_over_panel.get_node("Root/Box/Title")
	var vistas: Dictionary = {}

	for partida in 6:
		h.jugar(main)
		for tick in 600:
			await physics_frame
			if main.get_state() == GameState.State.GAME_OVER:
				break
		vistas[titulo.text] = true
		h.check(
			"la frase del panel sale del recurso",
			_todas_las_frases().has(titulo.text),
			"'%s'" % titulo.text
		)
		main.restart()
		await h.ticks(2)

	h.check(
		"y cambia entre partidas",
		vistas.size() > 1,
		"%d frases distintas en 6 muertes" % vistas.size()
	)
	main.free()


## Todas las frases del recurso, genéricas y por causa (T-075). Desde T-075
## el panel elige de una lista u otra según cómo se murió, así que
## comprobar solo `lines` daría un falso fallo.
func _todas_las_frases() -> PackedStringArray:
	var r: DeathLines = _lineas()
	var todas: PackedStringArray = PackedStringArray()
	for lista in [r.lines, r.lines_pipe, r.lines_ground, r.lines_void, r.lines_breathless]:
		todas.append_array(lista)
	return todas
