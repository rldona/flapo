extends SceneTree
## Calcula la versión, escribe los ficheros y dice qué tag toca (T-271).
##
##     godot --headless --path . -s tools/versionar.gd
##
## No crea el tag ni hace push: eso lo hace el workflow, que es quien tiene
## permiso. Este script solo **decide y escribe**, y deja el número en la
## salida para que CI lo lea. Separarlo así permite ejecutarlo en local y ver
## qué versión saldría antes de publicarla.
##
## Escribe tres cosas:
##   - `application/config/version` en `project.godot`
##   - `CHANGELOG.md`, con la versión nueva arriba
##   - `assets/data/changelog.tres`, que es lo que lee el menú (T-250)

const CHANGELOG := "res://CHANGELOG.md"
const NOVEDADES := "res://assets/data/changelog.tres"


func _init() -> void:
	var actual: String = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var mensajes: PackedStringArray = _commits_desde_el_ultimo_tag()
	var nueva: String = Version.siguiente(actual, mensajes)

	print("actual:    ", actual)
	print("commits:   ", mensajes.size())
	print("siguiente: ", nueva)

	if nueva == actual:
		# Nada que publicar no es un error: un push de solo documentación no
		# tiene por qué crear una versión.
		print("NADA_QUE_PUBLICAR")
		quit(0)
		return

	_escribir_version(nueva)
	_escribir_changelog(nueva, mensajes)
	_escribir_novedades(mensajes)
	# Lo lee el workflow para poner el tag. Formato fijo y en su propia línea.
	print("VERSION=%s" % nueva)
	quit(0)


## Los commits desde el último tag, o todos si no hay ninguno.
func _commits_desde_el_ultimo_tag() -> PackedStringArray:
	var ultimo: String = _git(["describe", "--tags", "--abbrev=0"]).strip_edges()
	var rango: String = "%s..HEAD" % ultimo if ultimo != "" else "HEAD"
	# Se pide el mensaje ENTERO (`%B`), no solo el asunto: `BREAKING CHANGE`
	# puede ir en el cuerpo. Como el cuerpo trae saltos de línea, los commits
	# se separan con el carácter de control 30 (record separator), que no
	# aparece en un mensaje de commit escrito por una persona.
	var sep: String = char(30)
	var crudo: String = _git(["log", rango, "--no-merges", "--pretty=format:%B%x1e"])
	var salida := PackedStringArray()
	for trozo in crudo.split(sep):
		var m: String = trozo.strip_edges()
		if m != "":
			salida.append(m)
	return salida


## Ejecuta git y devuelve su salida, o "" si falló.
##
## **Sin `read_stderr`, y mirando el código de salida.** Con stderr mezclado,
## un `git describe` en un repo sin tags devuelve "fatal: no tags can
## describe..." y eso se colaba como si fuera el nombre del último tag: el
## rango salía corrupto, `git log` fallaba, y el script decidía que no había
## nada que publicar. Un error convertido en dato, sin avisar.
func _git(args: PackedStringArray) -> String:
	var salida: Array = []
	var todos := PackedStringArray(["-C", ProjectSettings.globalize_path("res://")])
	todos.append_array(args)
	var codigo: int = OS.execute("git", todos, salida, false)
	if codigo != 0 or salida.is_empty():
		return ""
	return str(salida[0])


func _escribir_version(nueva: String) -> void:
	# Se edita el fichero como texto en vez de con `ProjectSettings.save()`:
	# guardar desde código reescribe `project.godot` entero, reordena y se
	# come los comentarios. Aquí se toca una línea.
	var ruta: String = ProjectSettings.globalize_path("res://project.godot")
	var texto: String = FileAccess.get_file_as_string(ruta)
	var lineas: PackedStringArray = texto.split("\n")
	var hecho: bool = false
	for i in lineas.size():
		if lineas[i].begins_with("config/version="):
			lineas[i] = 'config/version="%s"' % nueva
			hecho = true
			break
	if not hecho:
		push_error("No se ha encontrado config/version en project.godot")
		return
	var f: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	f.store_string("\n".join(lineas))
	f.close()


func _escribir_changelog(nueva: String, mensajes: PackedStringArray) -> void:
	var fecha: Dictionary = Time.get_date_dict_from_system()
	var hoy: String = "%04d-%02d-%02d" % [fecha["year"], fecha["month"], fecha["day"]]
	var bloque: String = Version.changelog_md(nueva, hoy, mensajes)
	var ruta: String = ProjectSettings.globalize_path(CHANGELOG)
	var anterior: String = ""
	if FileAccess.file_exists(ruta):
		anterior = FileAccess.get_file_as_string(ruta).trim_prefix("# Changelog\n")
	var f: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	# Lo nuevo arriba: un changelog se lee por el principio.
	f.store_string("# Changelog\n\n%s\n%s" % [bloque, anterior.strip_edges()])
	f.close()


## El recurso que lee el menú (T-250). Se escribe como `.tres` a mano porque
## es un `Resource` de tres líneas y no merece una clase propia todavía.
func _escribir_novedades(mensajes: PackedStringArray) -> void:
	var lineas: PackedStringArray = Version.novedades(mensajes)
	var comillas := PackedStringArray()
	for l in lineas:
		comillas.append('"%s"' % l.replace('"', "'"))
	var texto: String = '[gd_resource type="Resource" format=3]\n\n[resource]\n'
	texto += "lineas = PackedStringArray(%s)\n" % ", ".join(comillas)
	var ruta: String = ProjectSettings.globalize_path(NOVEDADES)
	var f: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	f.store_string(texto)
	f.close()
