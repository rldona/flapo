class_name Version
extends RefCounted
## Calcula la siguiente versión leyendo los Conventional Commits (T-271).
##
## Los mensajes de commit **ya llevan la información**: el repo usa
## Conventional Commits desde T-002, así que decidir la versión a mano es
## copiar a mano un dato que ya está escrito. Nadie edita versiones.
##
## Vive en `tools/` y no en `scripts/` porque no es parte del juego: es una
## herramienta de publicación. Pero la lógica está aquí y no en el YAML del
## workflow a propósito — **en el YAML no se puede probar nada**, y "qué
## versión toca" es exactamente la clase de cuenta que conviene tener bajo
## test antes de que ponga un número equivocado en una release.

## Qué tipo de salto pide un commit. El orden importa: se queda el mayor.
enum Salto { NINGUNO, PARCHE, MENOR, MAYOR }

## El encabezado del fichero de changelog.
const TITULO: String = "# Changelog"

## Tipos que suben la versión. El resto —docs, style, test, chore, ci,
## refactor— no publica nada nuevo para el jugador, así que no mueve el
## número. Un `docs:` no merece una versión.
const TIPOS_MENOR: Array[String] = ["feat"]
const TIPOS_PARCHE: Array[String] = ["fix", "perf"]


## Qué salto pide un commit suelto.
##
## `feat!:` o un `BREAKING CHANGE:` en el cuerpo son mayor, que es la regla de
## Conventional Commits. Se respeta aunque el proyecto esté en 0.x: cuando
## llegue el 1.0 no habrá que cambiar nada.
static func salto_de(mensaje: String) -> Salto:
	var primera: String = mensaje.split("\n")[0].strip_edges()
	if mensaje.contains("BREAKING CHANGE"):
		return Salto.MAYOR
	var dos_puntos: int = primera.find(":")
	if dos_puntos <= 0:
		return Salto.NINGUNO
	var cabeza: String = primera.substr(0, dos_puntos)
	# `feat(ui)!` → rompe. El `!` va justo antes de los dos puntos.
	if cabeza.ends_with("!"):
		return Salto.MAYOR
	# `feat(ui)` → `feat`.
	var parentesis: int = cabeza.find("(")
	var tipo: String = cabeza.substr(0, parentesis) if parentesis > 0 else cabeza
	tipo = tipo.strip_edges().to_lower()
	if TIPOS_MENOR.has(tipo):
		return Salto.MENOR
	if TIPOS_PARCHE.has(tipo):
		return Salto.PARCHE
	return Salto.NINGUNO


## El mayor salto que pide una lista de commits.
static func salto_de_todos(mensajes: PackedStringArray) -> Salto:
	var mayor: Salto = Salto.NINGUNO
	for m in mensajes:
		var s: Salto = salto_de(m)
		if int(s) > int(mayor):
			mayor = s
	return mayor


## La versión siguiente. Devuelve la misma si no hay nada que publicar.
##
## En 0.x un `feat` sube la MENOR y un breaking también, no la mayor: subir a
## 1.0.0 es una decisión de producto y no la consecuencia de un `!` en un
## mensaje de commit. Se documenta en ADR-0041.
static func siguiente(actual: String, mensajes: PackedStringArray) -> String:
	var v: PackedInt32Array = partes(actual)
	match salto_de_todos(mensajes):
		Salto.MAYOR:
			if v[0] == 0:
				return "0.%d.0" % (v[1] + 1)
			return "%d.0.0" % (v[0] + 1)
		Salto.MENOR:
			return "%d.%d.0" % [v[0], v[1] + 1]
		Salto.PARCHE:
			return "%d.%d.%d" % [v[0], v[1], v[2] + 1]
		_:
			return actual


## Parte "1.2.3" en [1, 2, 3]. Lo que no se entienda vale 0: una versión rara
## en `project.godot` no puede dejar la publicación colgada.
static func partes(v: String) -> PackedInt32Array:
	var limpia: String = v.strip_edges().trim_prefix("v")
	var trozos: PackedStringArray = limpia.split(".")
	var salida := PackedInt32Array([0, 0, 0])
	for i in mini(trozos.size(), 3):
		salida[i] = int(trozos[i]) if trozos[i].is_valid_int() else 0
	return salida


## El CHANGELOG en Markdown de una versión.
##
## Agrupado por tipo y no en una lista plana: un changelog es para leerlo, y
## veinte líneas seguidas sin separar no se leen.
static func changelog_md(version: String, fecha: String, mensajes: PackedStringArray) -> String:
	var grupos: Dictionary = {"feat": [], "fix": [], "perf": []}
	for m in mensajes:
		var primera: String = m.split("\n")[0].strip_edges()
		var tipo: String = _tipo_de(primera)
		if grupos.has(tipo):
			grupos[tipo].append(_descripcion_de(primera))
	var titulos: Dictionary = {"feat": "Novedades", "fix": "Arreglos", "perf": "Rendimiento"}
	var texto: String = "## %s — %s\n" % [version, fecha]
	for tipo in ["feat", "fix", "perf"]:
		if (grupos[tipo] as Array).is_empty():
			continue
		texto += "\n### %s\n\n" % titulos[tipo]
		for d in grupos[tipo]:
			texto += "- %s\n" % d
	return texto


## Junta el bloque nuevo con el changelog que ya había.
##
## Está aquí y no en el script que escribe el fichero **porque aquí se puede
## probar**. El primer intento dejaba una línea en blanco de más al final, el
## hook `fix end of files` la quitaba, y CI se ponía en rojo en el push
## siguiente a cada release: un fichero generado que no pasa las reglas del
## propio repositorio.
static func changelog_completo(bloque: String, anterior: String) -> String:
	# El título se le quita al histórico aquí dentro, no fuera. Quien llama no
	# tiene por qué acordarse de una regla del formato, y si se le olvida el
	# fichero sale con dos "# Changelog" — lo pilló el test a la primera.
	var viejo: String = anterior.strip_edges()
	if viejo.begins_with(TITULO):
		viejo = viejo.substr(TITULO.length()).strip_edges()
	var texto: String = TITULO + "\n\n" + bloque.strip_edges() + "\n"
	if viejo != "":
		texto += "\n" + viejo + "\n"
	return texto


## Las dos o tres líneas que enseña el menú al actualizar (T-250).
##
## Solo novedades, y las primeras: quien vuelve al juego quiere saber qué hay
## nuevo, no leerse el registro de arreglos.
static func novedades(mensajes: PackedStringArray, tope: int = 3) -> PackedStringArray:
	var salida := PackedStringArray()
	for m in mensajes:
		if salida.size() >= tope:
			break
		var primera: String = m.split("\n")[0].strip_edges()
		if _tipo_de(primera) == "feat":
			salida.append(_descripcion_de(primera))
	return salida


static func _tipo_de(primera: String) -> String:
	var dos_puntos: int = primera.find(":")
	if dos_puntos <= 0:
		return ""
	var cabeza: String = primera.substr(0, dos_puntos).trim_suffix("!")
	var parentesis: int = cabeza.find("(")
	var tipo: String = cabeza.substr(0, parentesis) if parentesis > 0 else cabeza
	return tipo.strip_edges().to_lower()


## Lo que va después de los dos puntos, con la primera en mayúscula. El
## ámbito —`(ui)`, `(gameplay)`— se tira: al jugador no le dice nada.
static func _descripcion_de(primera: String) -> String:
	var dos_puntos: int = primera.find(":")
	if dos_puntos < 0:
		return primera
	var d: String = primera.substr(dos_puntos + 1).strip_edges()
	return d.substr(0, 1).to_upper() + d.substr(1) if d.length() > 0 else d
