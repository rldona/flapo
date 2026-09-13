class_name DeathLines
extends Resource
## Las frases que salen al morir (T-056).
##
## Es un `Resource` y no un array en la escena por dos motivos: se edita en el
## inspector sin abrir código, y **es contenido**, no lógica. El tono lo revisa
## una persona (GDD, "Concepto y tono"): ánimo torpe, nunca burla al jugador.
##
## Añadir una frase es escribirla en `assets/data/death_lines.tres`. No hace
## falta tocar nada más.

## Las frases. Cortas: caben en el panel a 288 px de ancho.
@export var lines: PackedStringArray = PackedStringArray()


## Devuelve una frase distinta de `ultima`.
##
## Con una sola frase devuelve esa, aunque se repita: es preferible a
## devolver vacío y dejar el panel sin texto. Con la lista vacía devuelve "",
## y quien llame decide qué hacer.
func pick(rng: RandomNumberGenerator, ultima: String = "") -> String:
	if lines.is_empty():
		return ""
	if lines.size() == 1:
		return lines[0]
	# Se sortea entre las que NO son la última, en vez de sortear y repetir
	# hasta acertar: así el coste es fijo y no hay bucle que pueda alargarse.
	var candidatas: PackedStringArray = PackedStringArray()
	for linea in lines:
		if linea != ultima:
			candidatas.append(linea)
	if candidatas.is_empty():
		return lines[0]
	return candidatas[rng.randi_range(0, candidatas.size() - 1)]
