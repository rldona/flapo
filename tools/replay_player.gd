class_name ReplayPlayer
extends RefCounted
## Vuelve a jugar una partida grabada (T-261).
##
## Vive en `tools/` y no en `scripts/` porque el juego no necesita saber
## reproducirse a sí mismo: graba, y ya. Reproducir es una herramienta de
## diagnóstico, y meterla en el juego sería enviar a cada jugador código que
## solo usamos nosotros.
##
## Inyecta las pulsaciones por la puerta de siempre (`Input.parse_input_event`)
## y deja que el juego haga el resto. No fuerza posiciones ni estados: si el
## replay no reproduce, es que algo ha cambiado de verdad, que es justo lo que
## queremos que salte.

## Margen de frames que se dejan correr después del último flanco, para que la
## partida termine sola. Lo normal es que muera mucho antes.
const COLA: int = 600


## Reproduce el replay sobre un `Main` ya montado. Devuelve qué salió.
func reproducir(tree: SceneTree, main: Node, rep: Replay) -> Dictionary:
	# El perfil del jugador forma parte de la partida, no del adorno: el modo
	# cambia el mundo y la confianza cambia cuánto aliento hay (ADR-0036).
	SaveManager.clear()
	SaveManager.forget_cache()
	main.session().set_difficulty(rep.modo)
	_sembrar_confianza(rep.confianza)
	main.session().cargar()
	main.session().set_seed(rep.semilla)
	main.change_state(GameState.State.READY)
	# Un frame entre READY y PLAYING: READY libera las tuberías anteriores con
	# `queue_free()`, que no borra hasta el final del frame (ADR-0035).
	await tree.physics_frame
	main.change_state(GameState.State.PLAYING)

	var siguiente: int = 0
	var frame: int = 0
	var pulsado: bool = false
	var tope: int = (rep.frames[-1] if rep.eventos() > 0 else 0) + COLA
	while main.get_state() == GameState.State.PLAYING and frame <= tope:
		# `frame + 1` y no `frame`: un evento inyectado con
		# `Input.parse_input_event` no lo ve el juego hasta el frame
		# siguiente. El grabador anota **cuándo se vio** la pulsación, así
		# que para que se vea en el frame N hay que soltarla en el N-1.
		#
		# Medido: sin esta corrección el replay iba un frame tarde y la
		# partida terminaba con 17 puntos en vez de 22. Un frame de 16 ms
		# basta para cambiar la partida entera, que es exactamente lo que
		# hace útil un replay y lo que lo hace delicado.
		while siguiente < rep.eventos() and rep.frames[siguiente] == frame + 1:
			pulsado = rep.pulsado[siguiente] == 1
			_evento(pulsado)
			siguiente += 1
		await tree.physics_frame
		frame += 1
	if pulsado:
		_evento(false)
	return {
		"score": main.get_score(),
		"esperado": rep.score,
		"frames": frame,
		"cuadra": main.get_score() == rep.score,
	}


## Deja el guardado con esa confianza, que es lo que el replay necesita.
##
## La confianza no se escribe a mano: se deriva de las partidas jugadas, y
## `record_game` nunca la baja. Así que se juegan partidas en seco hasta
## llegar al escalón, que es la única forma de dejar el guardado en un estado
## que el juego considere legítimo.
func _sembrar_confianza(nivel: int) -> void:
	if nivel <= 0:
		return
	var partidas: int = nivel * GameConfig.CONFIDENCE_STEP
	for i in partidas:
		SaveManager.record_game(0)


func _evento(pulsada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	ev.pressed = pulsada
	Input.parse_input_event(ev)
