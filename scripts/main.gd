extends Node2D
## Raíz de la partida y dueña de la máquina de estados.
##
## Patrón "call down, signal up" (la recomendación oficial de Godot):
## Main conoce a sus hijos y les conecta señales o les llama métodos; los
## hijos nunca buscan a Main con `get_parent()` ni suben por el árbol. Así
## `Bird.tscn` o `Pipe.tscn` se pueden abrir y probar sueltos con F6.
##
## Main no decide *por qué* se cambia de estado, solo que el cambio es legal
## y lo anuncia. Quien detecta la muerte (T-028) llama a `change_state()`.

## Se emite después de que el estado ya ha cambiado, nunca antes: cuando un
## nodo reacciona, `state` ya devuelve el valor nuevo.
signal state_changed(to: GameState.State)

## Puntuación nueva. La emite Main porque es quien lleva la cuenta; el HUD
## (T-029) se cuelga de aquí en vez de preguntar cada frame.
signal score_changed(score: int)

## Transiciones legales. Tenerlas en una tabla en vez de repartidas en `if`
## convierte un bug de lógica (reiniciar desde PLAYING, morir dos veces) en
## un aviso en consola en lugar de en un estado imposible.
const _TRANSITIONS: Dictionary = {
	GameState.State.READY: [GameState.State.PLAYING],
	GameState.State.PLAYING: [GameState.State.GAME_OVER],
	GameState.State.GAME_OVER: [GameState.State.READY],
}

## Flapo. Se asigna arrastrando el nodo en el inspector, no con una ruta de
## texto: si algún día se mueve o se renombra, Godot actualiza la referencia.
@export var bird: Bird

## El generador de tuberías.
@export var pipe_spawner: PipeSpawner

## El suelo.
@export var ground: Ground

## El panel de Game Over.
@export var game_over_panel: GameOverPanel

## El marcador de la partida en curso.
@export var hud: Hud

## El nodo que reparte el jugo al morir (flash, sacudida, hit-stop).
@export var juice: Juice

## El fondo con parallax.
@export var background: Background

## El fundido de arranque de partida.
@export var fade: Fade

## Las frases que salen al morir (T-056). Es contenido: se edita en
## assets/data/death_lines.tres sin tocar código.
@export var death_lines: DeathLines

## El velo de pausa.
@export var pause_panel: PausePanel

## Los sonidos del juego.
@export var audio: AudioDirector

## Los efectos temporales de las frutas (T-047).
@export var effects: Effects

## El generador de frutas.
@export var fruit_spawner: FruitSpawner

## Segundos sin colisiones tras gastar un escudo, para poder salir de la
## tubería con la que se acaba de chocar.
@export var shield_grace: float = 1.0

## Escribe cada transición en la consola. Útil hasta que exista HUD (T-029).
@export var log_transitions: bool = true

var _state: GameState.State = GameState.State.READY
var _score: int = 0
var _high_score: int = 0
## Escalón de confianza (T-074). Se lee del guardado, no se calcula aquí.
var _confidence: int = 0
## La última frase que salió, para no repetirla dos veces seguidas.
var _ultima_frase: String = ""
## De qué murió Flapo la última vez y si llegó sin aliento (T-075). Se
## guardan porque el panel se rellena en `_on_state_changed_results`, un paso
## después de la muerte.
var _death_cause: Bird.DeathCause = Bird.DeathCause.SUELO
var _death_breathless: bool = false
var _rng_frases := RandomNumberGenerator.new()
var _is_new_high_score: bool = false


func _ready() -> void:
	_rng_frases.randomize()
	_high_score = SaveManager.get_high_score()
	_confidence = SaveManager.get_confidence()
	if log_transitions:
		state_changed.connect(_on_state_changed_log)
	_connect_children()
	# La primera partida también cuenta: `change_state(READY)` no hace nada
	# cuando ya se está en READY, así que sin esta llamada la confianza no se
	# aplicaría hasta después de la primera muerte.
	_aplicar_confianza()
	# Se anuncia el estado inicial para que nadie tenga que suponerlo. Los
	# hijos ya están listos: en Godot `_ready()` corre de abajo arriba.
	state_changed.emit(_state)


## `_unhandled_input` y no `_input`: así la UI (botones de T-071) se queda
## primero con el evento y el juego solo ve lo que nadie ha consumido.
func _unhandled_input(event: InputEvent) -> void:
	if _state == GameState.State.READY and event.is_action_pressed("flap"):
		change_state(GameState.State.PLAYING)
	elif _state == GameState.State.GAME_OVER and event.is_action_pressed("restart"):
		restart()
	elif event.is_action_pressed("pause") and _can_pause():
		set_paused(not get_tree().paused)


## Estado actual. Solo lectura: cambiarlo pasa por `change_state()`, que es
## lo único que garantiza que se emita la señal.
func get_state() -> GameState.State:
	return _state


## Pausa o reanuda.
##
## `get_tree().paused` congela el árbol entero salvo lo que tenga
## `process_mode = ALWAYS`. Como la física también se para, al reanudar NO
## hay delta acumulado: Flapo sigue exactamente donde estaba, que es el
## criterio de T-072. Es la diferencia con pausar a mano con un flag.
func set_paused(paused: bool) -> void:
	if paused and not _can_pause():
		return
	get_tree().paused = paused
	if pause_panel != null:
		pause_panel.set_paused(paused)


## Solo se puede pausar jugando: pausar en READY o con el panel de muerte
## delante no significa nada y complica el reinicio.
func _can_pause() -> bool:
	return _state == GameState.State.PLAYING


## Vuelve a dejarlo todo listo para jugar.
##
## No recarga la escena: cada sistema se reinicia al recibir READY. Ver
## ADR-0011 sobre por qué, y el test de 50 reinicios que lo respalda.
func _on_restart_pressed() -> void:
	if audio != null:
		audio.play_button()
	restart()


func restart() -> void:
	# Reiniciar con el juego pausado lo dejaría todo congelado y sin velo.
	set_paused(false)
	change_state(GameState.State.READY)


## Puntuación de la partida en curso.
func get_score() -> int:
	return _score


## Mejor puntuación de siempre.
func get_high_score() -> int:
	return _high_score


## Si la partida que se acaba de perder ha batido el récord.
func is_new_high_score() -> bool:
	return _is_new_high_score


## Escalón de confianza acumulado (T-074).
func get_confidence() -> int:
	return _confidence


## Traslada la confianza guardada a Flapo (T-074).
##
## Es lo único que la progresión toca del juego, y se hace al empezar cada
## partida: el jugador la nota en una barra de aliento más larga, no en un
## menú ni en un mensaje. Ver ADR-0021.
func _aplicar_confianza() -> void:
	bird.max_breath = GameConfig.max_breath_for(_confidence)


## Intenta pasar a `to`. Ignora el cambio si no es una transición legal.
func change_state(to: GameState.State) -> void:
	if to == _state:
		return
	if not _TRANSITIONS[_state].has(to):
		push_warning("Transición ilegal: %s -> %s" % [_state_name(_state), _state_name(to)])
		return
	_state = to
	# La puntuación se reinicia al volver a READY, no al morir: el panel de
	# Game Over (T-071) tiene que poder seguir enseñándola.
	if to == GameState.State.READY:
		_score = 0
		_is_new_high_score = false
		effects.clear()
		_aplicar_confianza()
		bird.gravity_mult = 1.0
		bird.size_mult = 1.0
		bird.hitbox_mult = 1.0
		_apply_difficulty()
		score_changed.emit(_score)
	state_changed.emit(to)


## "Call down, signal up": el padre cablea, los hijos no se buscan entre sí.
##
## Todas las piezas escuchan `state_changed` por igual, así que el cableado
## común es un bucle sobre una tabla. Lo que va aparte son las conexiones
## propias de cada una, abajo.
func _connect_children() -> void:
	var piezas: Dictionary = {
		"Bird": bird,
		"PipeSpawner": pipe_spawner,
		"Ground": ground,
		"GameOverPanel": game_over_panel,
		"Hud": hud,
		"Juice": juice,
		"Background": background,
		"Fade": fade,
		"FruitSpawner": fruit_spawner,
	}
	if pause_panel == null:
		push_error("Main no tiene asignado el nodo PausePanel en el inspector.")
		return
	pause_panel.resume_pressed.connect(set_paused.bind(false))
	if audio == null:
		push_error("Main no tiene asignado el nodo Audio en el inspector.")
		return
	pause_panel.mute_pressed.connect(_on_mute_pressed)
	game_over_panel.mute_pressed.connect(_on_mute_pressed)
	bird.flapped.connect(audio.play_flap)
	if effects == null:
		push_error("Main no tiene asignado el nodo Effects en el inspector.")
		return
	fruit_spawner.taken.connect(_on_fruit_taken)
	pipe_spawner.pipe_spawned.connect(fruit_spawner.on_pipe_spawned)
	effects.changed.connect(_on_effects_changed)
	effects.shield_changed.connect(hud.set_shield)
	for nombre in piezas:
		if piezas[nombre] == null:
			push_error("Main no tiene asignado el nodo %s en el inspector." % nombre)
			return
		state_changed.connect(piezas[nombre].on_game_state_changed)

	bird.died.connect(_on_bird_died)
	pipe_spawner.scored.connect(_on_scored)
	pipe_spawner.centered.connect(_on_centered)
	bird.breath_changed.connect(hud.set_breath)
	bird.fatigue_changed.connect(hud.set_fatigued)
	score_changed.connect(hud.set_score)
	score_changed.connect(game_over_panel.set_score)
	game_over_panel.restart_pressed.connect(_on_restart_pressed)
	game_over_panel.share_pressed.connect(_on_share_pressed)
	state_changed.connect(_on_state_changed_results)
	# Los paneles arrancan enseñando el estado real del silencio.
	pause_panel.set_muted(audio.is_muted())
	game_over_panel.set_muted(audio.is_muted())


## Rellena el panel al morir. Va aparte de `_on_bird_died` porque el panel
## debe enterarse igual si algún día se llega a GAME_OVER por otra vía.
## Android avisa al mandar la app a segundo plano. Sin esto, el jugador
## vuelve de atender una llamada y se encuentra a Flapo ya estrellado.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if _can_pause():
			set_paused(true)


func _on_state_changed_results(to: GameState.State) -> void:
	if to == GameState.State.GAME_OVER:
		game_over_panel.show_results(_score, _high_score, _is_new_high_score)
		game_over_panel.set_line(_siguiente_frase())


## Elige la frase de esta muerte, distinta de la anterior (T-056) y acorde a
## cómo se murió (T-075).
func _siguiente_frase() -> String:
	if death_lines == null:
		return ""
	var frase: String = death_lines.pick_for(
		_death_cause, _death_breathless, _rng_frases, _ultima_frase
	)
	if frase != "":
		_ultima_frase = frase
	return frase


## Compartir en Android. El intent nativo de texto necesita un plugin, que
## está fuera del alcance de v1 (GDD, "Fuera de alcance"): de momento se deja
## la marca en el portapapeles, que es lo que se puede hacer sin plugin.
func _on_share_pressed(texto: String) -> void:
	DisplayServer.clipboard_set(texto)


func _on_scored() -> void:
	_score += 1
	if audio != null:
		audio.play_point()
	_apply_difficulty()
	score_changed.emit(_score)


## Empuja la dificultad de la puntuación actual a quien la necesita.
##
## "Call down" (ADR-0005): los sistemas no consultan la puntuación, la reciben.
## Al ser funciones puras de la puntuación (ADR-0018), volver a READY con el
## marcador a 0 restaura la dificultad inicial sin código de reinicio.
func _apply_difficulty() -> void:
	# La velocidad del mundo es la curva de dificultad POR el modificador de
	# la fruta violeta: una cosa sube con la puntuación y la otra es temporal.
	var velocidad: float = GameConfig.scroll_speed_for(_score) * effects.speed_mult()
	if pipe_spawner != null:
		pipe_spawner.set_difficulty(
			velocidad, GameConfig.pipe_gap_for(_score), GameConfig.pipe_spacing_for(_score)
		)
	if ground != null:
		ground.scroll_speed = velocidad
	if background != null:
		background.scroll_speed = velocidad
	if fruit_spawner != null:
		fruit_spawner.set_difficulty(
			velocidad, GameConfig.pipe_gap_for(_score), GameConfig.pipe_spacing_for(_score)
		)


## Alterna el silencio y lo cuenta a los dos paneles que lo enseñan.
func _on_mute_pressed() -> void:
	if audio == null:
		return
	var muted: bool = audio.toggle_muted()
	audio.play_button()
	pause_panel.set_muted(muted)
	game_over_panel.set_muted(muted)


## Flapo ha cogido una fruta.
func _on_fruit_taken(kind: Effects.Kind, puntos: int) -> void:
	effects.apply(kind)
	bird.gravity_mult = effects.gravity_mult()
	bird.size_mult = effects.size_mult()
	bird.hitbox_mult = effects.hitbox_mult()
	_apply_difficulty()
	if audio != null:
		if puntos > 0:
			audio.play_fruit_bad()
		else:
			audio.play_fruit_good()
	# Los castigos pagan en puntos: es lo que los convierte en una decisión
	# en vez de en un obstáculo disfrazado de premio (ADR-0019).
	for i in puntos:
		_on_scored()


## El efecto activo ha cambiado o ha caducado: hay que reflejarlo en el mundo.
func _on_effects_changed(kind: Effects.Kind, restante: float) -> void:
	if hud != null:
		hud.set_effect(effects.kind_name(kind), restante)
	bird.gravity_mult = effects.gravity_mult()
	bird.size_mult = effects.size_mult()
	bird.hitbox_mult = effects.hitbox_mult()
	_apply_difficulty()


## Flapo ha cruzado por el centro de un hueco: recupera aliento (T-048).
func _on_centered() -> void:
	bird.recover_breath(GameConfig.BREATH_RECOVER_ON_GAP)


func _on_bird_died(cause: Bird.DeathCause, sin_aliento: bool) -> void:
	# El escudo de la fruta azul absorbe el golpe antes que nada más.
	if effects != null and effects.consume_shield():
		bird.survive(shield_grace)
		if audio != null:
			audio.play_fruit_good()
		return
	# Se apunta ya, aunque el panel lo lea un paso después: en GAME_OVER la
	# colisión ya no existe y la causa no se podría reconstruir.
	_death_cause = cause
	_death_breathless = sin_aliento
	if juice != null:
		juice.punch()
	if audio != null:
		audio.play_hit()
	# Se registra ANTES de cambiar de estado: el panel lee el récord al
	# recibir GAME_OVER y tiene que ver ya el dato de esta partida.
	_is_new_high_score = SaveManager.record_game(_score)
	_high_score = SaveManager.get_high_score()
	_confidence = SaveManager.get_confidence()
	change_state(GameState.State.GAME_OVER)


func _on_state_changed_log(to: GameState.State) -> void:
	print("[Main] estado -> ", _state_name(to))


func _state_name(state: GameState.State) -> String:
	return GameState.State.keys()[state]
