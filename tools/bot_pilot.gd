class_name BotPilot
extends RefCounted
## Un jugador automático con una política fija (T-260).
##
## **La política es solo aletear**, y no por simplificar: en este juego el
## planeo no es un control aparte, es lo que ocurre si mantienes pulsado
## DESPUÉS de aletear (T-200). No se puede planear sin aletear primero. Un bot
## que "planee cuando está por encima del hueco" aletea hacia arriba justo
## cuando quería bajar — se midió: trepaba hasta el techo en todas las
## partidas. Ver ADR-0035.
##
## No mide diversión: eso no se mide. Mide **si la curva es justa**. Si el bot
## —que no se cansa, no se distrae y siempre juega igual— muere una y otra vez
## en la misma tubería, ahí hay un pico en la dificultad y no en el jugador.
##
## Vive en `tools/` y no en `scripts/` porque no es parte del juego: es un
## instrumento de medida. Por lo mismo, sus constantes **no están en
## `GameConfig`**. `GameConfig` define las reglas del juego; si la política del
## bot viviera ahí, tunear el instrumento cambiaría el fichero que define lo
## que se está midiendo.
##
## Pulsa el botón de verdad (`Input.parse_input_event`), como el jugador. Un
## bot que empujara a Flapo por dentro estaría midiendo una física que nadie
## juega.

## Cuánto se adelanta el bot, en segundos. Es el número que hace o rompe la
## política.
##
## La primera versión miraba hasta la tubería entera —hasta 2,5 s— y el bot
## se estrellaba contra el techo en todas las partidas. El motivo es que la
## caída libre va con el cuadrado del tiempo: a 2,5 s predice 3.900 px de
## caída, o sea siete pantallas, así que el bot aleteaba sin parar.
##
## Un jugador tampoco predice dos segundos y medio: mira el frame siguiente y
## 0,03 s son dos frames: "dónde está ahora, con un empujoncito de su
## velocidad". Corto a propósito. Con horizontes largos la predicción se llena
## de una caída que el propio aleteo va a cancelar, y el bot corrige de más:
## a 0,10 s la media se hunde de 17 a 3.
const ANTICIPACION: float = 0.03

## Tope de frames por partida, por si una política mala consigue volar sin
## morirse nunca. A 60 Hz son cinco minutos.
## Dónde apunta el bot dentro del hueco, en subidas de aleteo por debajo del
## centro.
##
## **Es el número que decide la partida**, y por bastante: 0,5 da 15 de media
## y 1,0 da 1,5. Media subida por debajo del centro hace que el arco del
## aleteo *pase* por el centro del hueco en vez de empezar en él.
##
## Calibrado por barrido y validado en semillas distintas; ver ADR-0035.
const APUNTAR: float = 0.5

## Frames mínimos entre dos aleteos. 1 = sin freno.
##
## Es una hipótesis que se probó y salió que no: parecía que frenar al bot
## tenía que ayudar, porque más de cuatro aleteos en 1,2 s es fatiga (T-049) y
## cada aleteo gasta 10 de 100 de aliento (T-048). El barrido dice lo
## contrario — sin freno, 15,07 de media; con 20 frames de freno, mucho menos.
##
## La explicación es que el bot **ya se frena solo**: solo aletea cuando se ve
## por debajo del objetivo, y un aleteo lo sube 60 px de golpe, así que se
## pasa un buen rato sin necesitar otro. La fatiga nunca llega a morder.
##
## Se queda como perilla porque el barrido la usa, no porque haga falta.
## Calibrado en ADR-0035.
const CADENCIA: int = 1

## Tope de frames de una partida, por si una política buena consigue volar sin
## morirse nunca. A 60 Hz son cinco minutos.
const MAX_FRAMES: int = 18000

## Los dos números de la política, en variables y no en constantes: así se
## pueden barrer sin editar el fichero. Arrancan en los valores calibrados.
var anticipacion: float = ANTICIPACION
var apuntar: float = APUNTAR

## Tope de frames de una partida. Variable para poder acortarlo al calibrar:
## un bot que vuela cinco minutos ya ha demostrado lo que había que ver.
var max_frames: int = MAX_FRAMES

## Frames mínimos entre aleteos. Variable para poder barrerla.
var cadencia: int = CADENCIA

var _desde_aleteo: int = 999
var _pulsado: bool = false
var _soltar_luego: bool = false


## Corre una partida entera con esa semilla. Devuelve qué pasó.
##
## El guardado se limpia antes de cada partida a propósito: la confianza
## (T-074) alarga la barra de aliento con las partidas jugadas, así que sin
## limpiar, la partida 180 se jugaría con más aliento que la 2 y el
## histograma mediría el progreso del guardado en vez de la curva.
func jugar(tree: SceneTree, main: Node, semilla: int) -> Dictionary:
	SaveManager.clear()
	SaveManager.forget_cache()
	_pulsado = false
	_soltar_luego = false
	_desde_aleteo = 999
	main.session().set_seed(semilla)
	main.change_state(GameState.State.READY)
	# Un frame entre READY y PLAYING, y no es un adorno: READY libera las
	# tuberías de la partida anterior con `queue_free()`, que no borra hasta
	# el final del frame. Sin esta espera, las tuberías viejas siguen en el
	# árbol durante el primer frame de la nueva partida y matan a Flapo antes
	# de empezar. Se midió: partidas que terminaban en 1 frame con 0 puntos.
	await tree.physics_frame
	main.change_state(GameState.State.PLAYING)
	var frames: int = 0
	while main.get_state() == GameState.State.PLAYING and frames < max_frames:
		_decidir(main)
		await tree.physics_frame
		frames += 1
	_soltar()
	return {
		"semilla": semilla,
		"score": main.get_score(),
		"frames": frames,
		"agotado": frames >= max_frames,
	}


## Decide qué hacer este frame y lo pulsa.
func _decidir(main: Node) -> void:
	if _soltar_luego:
		_soltar()
		_soltar_luego = false
		return
	var previsto: float = _y_prevista(main, _tiempo_hasta(main))
	# Se apunta por DEBAJO del centro, media subida de aleteo. Apuntando al
	# centro exacto el bot se pasa siempre: un aleteo sube 60 px y la mitad
	# del hueco son 59, así que cada corrección lo dejaba fuera por arriba y
	# acababa pegado al techo. Apuntando bajo, el arco del aleteo pasa por el
	# centro en vez de empezar en él.
	_desde_aleteo += 1
	if previsto > _objetivo(main) + _subida(main) * apuntar and _desde_aleteo >= cadencia:
		_desde_aleteo = 0
		_aletear()
	else:
		_soltar()


## Cuánto sube un aleteo, en píxeles, con las constantes de Flapo de ahora.
##
## Sale de la física y no de un número escrito a mano: si mañana cambia el
## impulso o la gravedad en el tuning de T-040, el bot se recalibra solo. Un
## bot con la subida hardcodeada mediría la curva vieja.
func _subida(main: Node) -> float:
	var g: float = maxf(main.bird.gravity * main.bird.gravity_mult, 1.0)
	return main.bird.flap_impulse * main.bird.flap_impulse / (2.0 * g)


## Hacia dónde va Flapo: su posición más su velocidad por el horizonte.
##
## **Extrapolación lineal, sin el término de la gravedad**, y no es un
## descuido. La primera versión incluía el `0.5·g·t²` completo y el bot trepó
## hasta el techo en las 200 partidas: a 0,30 s ese término son 54 px fijos
## que se suman siempre, así que la predicción caía por debajo del hueco
## incluso flotando quieto en el centro, y el bot aleteaba sin parar.
##
## La gravedad es justo lo que el aleteo viene a compensar. Metiéndola en la
## predicción, el bot se pasa la partida corrigiendo una caída que su propia
## corrección ya evita.
func _y_prevista(main: Node, t: float) -> float:
	return main.bird.position.y + main.bird.velocity.y * t


## Cuánto falta para llegar a la siguiente tubería, en segundos.
## Cuánto mira hacia adelante este frame: la anticipación, o menos si la
## tubería está tan cerca que mirar más allá sería mirar detrás de ella.
func _tiempo_hasta(main: Node) -> float:
	var pipe: Pipe = _siguiente_tuberia(main)
	if pipe == null:
		return anticipacion
	var velocidad: float = maxf(main.pipe_spawner.scroll_speed, 1.0)
	var falta: float = maxf((pipe.position.x - main.bird.position.x) / velocidad, 0.0)
	return minf(falta, anticipacion)


## Dónde quiere estar: el centro del hueco que viene, o media pantalla si no
## hay ninguno a la vista.
func _objetivo(main: Node) -> float:
	var pipe: Pipe = _siguiente_tuberia(main)
	if pipe == null:
		return GameConfig.playable_height() * 0.5
	# `get_gap_center` y no `get_base_gap_center`: si la tubería oscila
	# (T-063), lo que hay que cruzar es donde está el hueco, no su media.
	return pipe.global_position.y + pipe.get_gap_center()


## La tubería más cercana que Flapo todavía no ha pasado.
func _siguiente_tuberia(main: Node) -> Pipe:
	var mejor: Pipe = null
	for hijo in main.pipe_spawner.get_children():
		if not hijo is Pipe:
			continue
		var pipe: Pipe = hijo
		# Media anchura de margen: una tubería que Flapo ya está cruzando
		# sigue siendo la que importa hasta que la deja atrás del todo.
		if pipe.position.x + pipe.width * 0.5 < main.bird.position.x:
			continue
		if mejor == null or pipe.position.x < mejor.position.x:
			mejor = pipe
	return mejor


## Un aleteo necesita un flanco: si ya estaba pulsado, primero hay que soltar.
func _aletear() -> void:
	if _pulsado:
		_soltar()
		_soltar_luego = false
		return
	_pulsar()
	_soltar_luego = true


func _pulsar() -> void:
	_evento(true)
	_pulsado = true


func _soltar() -> void:
	if not _pulsado:
		return
	_evento(false)
	_pulsado = false


func _evento(pulsada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	ev.pressed = pulsada
	Input.parse_input_event(ev)


## El informe: media, mediana e histograma de muertes por índice de tubería.
##
## Estático y devolviendo texto, no imprimiendo: así el test puede comprobar
## que el informe se genera sin tener que leer la salida por consola.
static func informe(resultados: Array) -> String:
	if resultados.is_empty():
		return "Sin partidas."
	var scores: Array = []
	for r in resultados:
		scores.append(int(r["score"]))
	scores.sort()
	var suma: int = 0
	for s in scores:
		suma += s
	var media: float = float(suma) / float(scores.size())
	var mediana: float = _mediana(scores)
	var texto: String = "Partidas: %d\n" % scores.size()
	texto += "Media:    %.2f\n" % media
	texto += "Mediana:  %.1f\n" % mediana
	texto += "Peor:     %d\nMejor:    %d\n" % [scores[0], scores[-1]]
	texto += "\nMuertes por índice de tubería:\n"
	texto += _histograma(scores)
	return texto


static func _mediana(ordenados: Array) -> float:
	var n: int = ordenados.size()
	if n % 2 == 1:
		return float(ordenados[n / 2])
	return (float(ordenados[n / 2 - 1]) + float(ordenados[n / 2])) * 0.5


## La tira de muertes. El índice es la tubería que el bot NO consiguió pasar,
## o sea la siguiente a su puntuación: morir con 6 puntos es morir en la 7ª.
##
## Un pico aquí es el hallazgo del ticket: si el bot muere siempre en la
## misma, esa tubería tiene algo que las de al lado no tienen.
static func _histograma(scores: Array) -> String:
	var cuenta: Dictionary = {}
	var tope: int = 0
	for s in scores:
		var indice: int = int(s) + 1
		cuenta[indice] = int(cuenta.get(indice, 0)) + 1
		tope = maxi(tope, int(cuenta[indice]))
	var indices: Array = cuenta.keys()
	indices.sort()
	var texto: String = ""
	for indice in indices:
		var n: int = int(cuenta[indice])
		var barra: int = int(round(float(n) / float(tope) * 40.0))
		texto += "  %3d | %s %d\n" % [indice, "#".repeat(barra), n]
	return texto
