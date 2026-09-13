extends SceneTree
## T-271 — Versionado semántico automático.
##
## La cuenta de "qué versión toca" vive en GDScript y no en el YAML del
## workflow **para poder probarla**. Un número de versión equivocado no se ve
## hasta que ya está publicado, y entonces no se puede quitar.
##
## Se comprueban las tres cosas que decide: el salto que pide cada tipo de
## commit, el número que sale, y el texto que acaba leyendo el jugador.

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-271 · Versionado automático ---")
	_cada_tipo_pide_su_salto()
	_manda_el_salto_mayor_de_todos()
	_el_numero_sale_bien()
	_en_cero_algo_no_se_salta_a_uno()
	_una_version_rara_no_cuelga_la_publicacion()
	_el_changelog_se_agrupa_y_se_lee()
	_las_novedades_son_para_el_jugador()
	quit(h.resumen("T-271"))


## Criterio: `feat` → minor, `fix` → patch. Y lo que no publica nada, nada.
func _cada_tipo_pide_su_salto() -> void:
	var casos: Array = [
		["feat: enseña a planear", Version.Salto.MENOR],
		["feat(ui): submenú de opciones", Version.Salto.MENOR],
		["fix: el fantasma se va cuando lo superas", Version.Salto.PARCHE],
		["fix(ci): permisos del job de release", Version.Salto.PARCHE],
		["perf: menos nodos por tubería", Version.Salto.PARCHE],
		["docs: registro de ADRs", Version.Salto.NINGUNO],
		["chore: uid del test", Version.Salto.NINGUNO],
		["style: gdformat", Version.Salto.NINGUNO],
		["test: caso que faltaba", Version.Salto.NINGUNO],
		["refactor(core): saca GameSession de Main", Version.Salto.NINGUNO],
		["feat!: la partida ya no se guarda igual", Version.Salto.MAYOR],
		["feat(core)!: otro formato de replay", Version.Salto.MAYOR],
		["fix: algo\n\nBREAKING CHANGE: cambia el guardado", Version.Salto.MAYOR],
		["sin tipo ni dos puntos", Version.Salto.NINGUNO],
		["", Version.Salto.NINGUNO],
	]
	var malos: Array = []
	for c in casos:
		if Version.salto_de(c[0]) != c[1]:
			malos.append(
				"%s → %d (esperado %d)" % [c[0].split("\n")[0], Version.salto_de(c[0]), c[1]]
			)
	h.check("cada tipo de commit pide el salto que le toca", malos.is_empty(), "%s" % str(malos))
	h.check(
		"un refactor no publica versión: no cambia nada para el jugador",
		Version.salto_de("refactor: mueve cosas") == Version.Salto.NINGUNO,
		""
	)


## Con veinte commits mezclados manda el mayor, no el último ni el primero.
func _manda_el_salto_mayor_de_todos() -> void:
	var mezcla := PackedStringArray(
		["docs: algo", "fix: otra cosa", "chore: nada", "feat: novedad", "style: comas"]
	)
	h.check(
		"con un feat entre parches, manda el feat",
		Version.salto_de_todos(mezcla) == Version.Salto.MENOR,
		"%d" % Version.salto_de_todos(mezcla)
	)
	var solo_ruido := PackedStringArray(["docs: a", "chore: b", "style: c"])
	h.check(
		"y si no hay nada publicable, no hay salto",
		Version.salto_de_todos(solo_ruido) == Version.Salto.NINGUNO,
		""
	)
	h.check(
		"una lista vacía tampoco salta",
		Version.salto_de_todos(PackedStringArray()) == Version.Salto.NINGUNO,
		""
	)


func _el_numero_sale_bien() -> void:
	var casos: Array = [
		["0.3.1", ["feat: x"], "0.4.0"],
		["0.3.1", ["fix: x"], "0.3.2"],
		["0.3.1", ["docs: x"], "0.3.1"],
		["1.2.3", ["feat: x"], "1.3.0"],
		["1.2.3", ["fix: x"], "1.2.4"],
		["1.2.3", ["feat!: x"], "2.0.0"],
	]
	var malos: Array = []
	for c in casos:
		var salio: String = Version.siguiente(c[0], PackedStringArray(c[1]))
		if salio != c[2]:
			malos.append("%s + %s → %s (esperado %s)" % [c[0], str(c[1]), salio, c[2]])
	h.check("el número siguiente sale bien", malos.is_empty(), "%s" % str(malos))
	h.check(
		"sin nada que publicar, la versión no se mueve",
		Version.siguiente("0.3.1", PackedStringArray(["docs: x"])) == "0.3.1",
		""
	)


## En 0.x un breaking sube la menor, no la mayor: llegar a 1.0.0 es una
## decisión de producto, no la consecuencia de un `!` en un mensaje.
func _en_cero_algo_no_se_salta_a_uno() -> void:
	h.check(
		"en 0.x un breaking sube la menor, no salta a 1.0.0",
		Version.siguiente("0.5.2", PackedStringArray(["feat!: rompe"])) == "0.6.0",
		"%s" % Version.siguiente("0.5.2", PackedStringArray(["feat!: rompe"]))
	)
	h.check(
		"pero a partir de 1.x sí sube la mayor",
		Version.siguiente("1.5.2", PackedStringArray(["feat!: rompe"])) == "2.0.0",
		"%s" % Version.siguiente("1.5.2", PackedStringArray(["feat!: rompe"]))
	)


## Regla de oro del repo: nunca reventar. Una versión rara en project.godot
## no puede dejar la publicación colgada.
func _una_version_rara_no_cuelga_la_publicacion() -> void:
	var raras: Array = ["", "v1.2.3", "hola", "1", "1.2.3.4.5", "1.x.3"]
	var malos: Array = []
	for r in raras:
		var salio: String = Version.siguiente(r, PackedStringArray(["feat: x"]))
		if salio.split(".").size() != 3:
			malos.append("%s → %s" % [r, salio])
	h.check("ninguna versión rara rompe el cálculo", malos.is_empty(), "%s" % str(malos))
	h.check(
		"y la 'v' delante se entiende, que es como se escriben los tags",
		Version.siguiente("v1.2.3", PackedStringArray(["fix: x"])) == "1.2.4",
		"%s" % Version.siguiente("v1.2.3", PackedStringArray(["fix: x"]))
	)


func _el_changelog_se_agrupa_y_se_lee() -> void:
	var commits := PackedStringArray(
		[
			"feat(ui): submenú de opciones",
			"fix: el fantasma se va cuando lo superas",
			"docs: no debería salir",
			"feat: térmicas",
			"perf: menos nodos"
		]
	)
	var md: String = Version.changelog_md("0.4.0", "2026-09-09", commits)
	h.check(
		"el changelog lleva versión y fecha", md.contains("0.4.0") and md.contains("2026-09-09"), ""
	)
	for titulo in ["Novedades", "Arreglos", "Rendimiento"]:
		h.check("y agrupa por '%s'" % titulo, md.contains(titulo), "")
	h.check("los docs no salen: no son para el jugador", not md.contains("no debería salir"), "")
	h.check(
		"el ámbito entre paréntesis se tira: al jugador no le dice nada",
		md.contains("Submenú de opciones") and not md.contains("(ui)"),
		"%s" % md
	)


## Lo que acaba leyendo el jugador en el menú (T-250).
func _las_novedades_son_para_el_jugador() -> void:
	var commits := PackedStringArray(
		["feat: una", "fix: un arreglo", "feat: dos", "feat: tres", "feat: cuatro"]
	)
	var n: PackedStringArray = Version.novedades(commits)
	h.check("son como mucho tres líneas", n.size() == 3, "%d líneas" % n.size())
	h.check("y solo novedades, no arreglos", not "Un arreglo" in Array(n), "%s" % str(n))
	h.check(
		"en el orden en que se hicieron",
		n[0] == "Una" and n[1] == "Dos" and n[2] == "Tres",
		"%s" % str(n)
	)
	h.check(
		"sin nada nuevo, ninguna línea",
		Version.novedades(PackedStringArray(["fix: a", "docs: b"])).is_empty(),
		""
	)
