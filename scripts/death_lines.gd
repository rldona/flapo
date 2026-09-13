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

## Las frases genéricas. Cortas: caben en el panel a 288 px de ancho.
##
## Siguen siendo la red de seguridad: si una lista por causa se queda vacía,
## se tira de aquí. Ninguna muerte deja el panel mudo.
@export var lines: PackedStringArray = PackedStringArray()

@export_group("Por causa (T-075)")
## Se estampó contra una tubería.
@export var lines_pipe: PackedStringArray = PackedStringArray()
## Se dio con el suelo.
@export var lines_ground: PackedStringArray = PackedStringArray()
## Se salió por abajo sin tocar nada.
@export var lines_void: PackedStringArray = PackedStringArray()
## Llegó al golpe con el aliento a cero. No es una causa —sin aliento no se
## muere (ADR-0020)— sino un agravante, y por eso tiene prioridad sobre la
## causa: es lo que mejor explica la muerte.
@export var lines_breathless: PackedStringArray = PackedStringArray()


## La frase que toca para esta muerte concreta (T-075).
##
## El orden es deliberado: **primero el agotamiento, luego la causa, luego lo
## genérico**. Si Flapo llega sin fuelle, eso es lo que hay que contar; contra
## qué se dio después es un detalle. Y cualquier lista vacía cae en la
## siguiente, así que se pueden dejar sin rellenar sin romper nada.
func pick_for(
	causa: Bird.DeathCause, sin_aliento: bool, rng: RandomNumberGenerator, ultima: String = ""
) -> String:
	var candidatas: PackedStringArray = lines
	if sin_aliento and not lines_breathless.is_empty():
		candidatas = lines_breathless
	else:
		var por_causa: PackedStringArray = _lista_de(causa)
		if not por_causa.is_empty():
			candidatas = por_causa
	return _elegir(candidatas, rng, ultima)


func _lista_de(causa: Bird.DeathCause) -> PackedStringArray:
	match causa:
		Bird.DeathCause.TUBERIA:
			return lines_pipe
		Bird.DeathCause.SUELO:
			return lines_ground
		Bird.DeathCause.VACIO:
			return lines_void
	return PackedStringArray()


## Devuelve una frase distinta de `ultima`.
##
## Con una sola frase devuelve esa, aunque se repita: es preferible a
## devolver vacío y dejar el panel sin texto. Con la lista vacía devuelve "",
## y quien llame decide qué hacer.
func pick(rng: RandomNumberGenerator, ultima: String = "") -> String:
	return _elegir(lines, rng, ultima)


func _elegir(lista: PackedStringArray, rng: RandomNumberGenerator, ultima: String) -> String:
	if lista.is_empty():
		return ""
	if lista.size() == 1:
		return lista[0]
	# Se sortea entre las que NO son la última, en vez de sortear y repetir
	# hasta acertar: así el coste es fijo y no hay bucle que pueda alargarse.
	var candidatas: PackedStringArray = PackedStringArray()
	for linea in lista:
		if linea != ultima:
			candidatas.append(linea)
	if candidatas.is_empty():
		return lista[0]
	return candidatas[rng.randi_range(0, candidatas.size() - 1)]
