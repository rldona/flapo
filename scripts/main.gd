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
	GameState.State.MENU: [GameState.State.READY],
	GameState.State.READY: [GameState.State.PLAYING, GameState.State.MENU],
	GameState.State.PLAYING: [GameState.State.GAME_OVER],
	GameState.State.GAME_OVER: [GameState.State.READY, GameState.State.MENU],
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

## La pantalla de inicio (T-078).
@export var menu_panel: MenuPanel

## El aviso que enseña a planear (T-200).
@export var glide_hint: GlideHint

## El fantasma del récord (T-243). Graba y reproduce; no colisiona ni puntúa.
@export var ghost: Ghost

## El grabador de replays (T-261). Solo escucha el botón; no toca el juego.
@export var replay_recorder: ReplayRecorder

## Las ráfagas de viento (T-064).
@export var wind: Wind

## El vigilante del tamaño de ventana (T-085). No dibuja: solo publica.
@export var layout: LayoutDirector

## La pantalla de estadísticas (T-084).
@export var stats_panel: StatsPanel

## El submenú de opciones (T-087).
@export var options_panel: OptionsPanel

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

## El juego arranca en el menú (T-078), no en READY: la dificultad se elige
## antes de la primera partida, no después.
## Todo lo que la partida sabe de sí misma: semilla, reto, nombre, modo y
## confianza. Vive aparte porque no tiene nada que ver con el bucle de juego.
var _session := GameSession.new()

var _state: GameState.State = GameState.State.MENU
var _score: int = 0
var _high_score: int = 0
## Huecos cruzados en esta partida sin haber planeado nunca (T-200).
var _huecos_sin_planear: int = 0

## La última frase que salió, para no repetirla dos veces seguidas.
var _ultima_frase: String = ""
## De qué murió Flapo la última vez y si llegó sin aliento (T-075). Se
## guardan porque el panel se rellena en `_on_state_changed_results`, un paso
## después de la muerte.
var _death_cause: Bird.DeathCause = Bird.DeathCause.SUELO
var _death_breathless: bool = false
## Generador aparte para lo cosmético (frases al morir). Fuera del RNG de la
## partida a propósito: ver ADR-0030.
var _rng_cosmetico := RandomNumberGenerator.new()
var _is_new_high_score: bool = false


func _ready() -> void:
	_rng_cosmetico.randomize()
	_high_score = SaveManager.get_high_score()
	_session.cargar()
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
	if _state == GameState.State.MENU:
		# En el menú manda la UI: los botones ya consumen sus toques y el
		# resto no debe colarse como un aleteo.
		return
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


## Arranca el reto del día (T-241). Sin argumentos, el de hoy.
##
## Solo cambia la SEMILLA: modo de dificultad, frutas y todo lo demás siguen
## siendo los del juego normal. Un reto que además cambiara las reglas no
## sería el mismo juego para todos, que es justo lo que lo hace comparable.
func start_daily(fecha: Array = []) -> void:
	_session.preparar_reto(fecha)
	change_state(GameState.State.READY)


## Vuelve al juego normal, con semilla sorteada (T-241).
func start_free() -> void:
	_session.preparar_libre()
	change_state(GameState.State.READY)


## Arranca la partida de un código. `false` si el código no vale (T-242).
func start_code(codigo_texto: String) -> bool:
	if not _session.preparar_codigo(codigo_texto):
		return false
	change_state(GameState.State.READY)
	return true


## Lo que esta partida sabe de sí misma: semilla, código, reto, nombre, modo
## y confianza. Ver `GameSession`.
func session() -> GameSession:
	return _session


## Intenta jugar el código que se ha escrito en el menú (T-242).
##
## Un código malo **no rompe nada y no saca del menú**: se enseña un aviso
## corto y ahí se queda, que es lo que dice el criterio del ticket.
func _on_code_pressed(texto: String) -> void:
	if start_code(texto):
		return
	if menu_panel != null:
		menu_panel.set_aviso("Ese código no vale")


## El jugador ha elegido modo en el menú (T-078).
##
## Solo tiene efecto fuera de una partida: cambiarlo a mitad de vuelo movería
## las tuberías que ya están en pantalla.
func _on_difficulty_selected(modo: GameConfig.Difficulty) -> void:
	if _state == GameState.State.PLAYING:
		push_warning("La dificultad no se cambia en mitad de una partida.")
		return
	_session.set_difficulty(modo)
	_apply_difficulty()
	_refrescar_menu()


## Vuelve al menú desde el Game Over o desde READY.
func to_menu() -> void:
	change_state(GameState.State.MENU)


## Las estadísticas que se enseñan (T-084).
##
## Solo una de las cinco filas necesita un contador nuevo (`total_score`); el
## resto se deriva de lo que ya había. Esa es la regla del ticket: no llenar
## el guardado de números que nadie mira.
func stats_rows() -> Array:
	var medalla: GameConfig.Medal = GameConfig.medal_for(SaveManager.get_high_score())
	return [
		["Partidas", str(SaveManager.get_games_played())],
		["Mejor marca", str(SaveManager.get_high_score())],
		["Mejor medalla", GameConfig.medal_name(medalla)],
		["Tuberías cruzadas", str(SaveManager.get_total_score())],
		["Media por partida", "%.1f" % SaveManager.get_average_score()],
	]


## Abre las opciones enseñando el estado real de cada ajuste.
##
## Se rellena al abrir y no al arrancar: el silencio se puede cambiar desde
## la pausa y desde el Game Over, así que el panel no puede fiarse de lo que
## le dijeron una vez.
func _abrir_opciones() -> void:
	if options_panel == null:
		return
	options_panel.set_player_name(_session.player_name())
	options_panel.set_difficulty(_session.difficulty())
	options_panel.set_muted(audio.is_muted() if audio != null else false)
	options_panel.set_ghost_hidden(Settings.is_ghost_hidden())
	options_panel.set_open(true)


## El jugador ha escondido o enseñado el fantasma del récord (T-087).
##
## Tiene efecto en la SIGUIENTE partida, no en la que está en curso: desde el
## menú no hay ninguna en curso, y el fantasma decide si sale al entrar en
## PLAYING.
func _on_ghost_toggled() -> void:
	if options_panel == null:
		return
	options_panel.set_ghost_hidden(Settings.set_ghost_hidden(not Settings.is_ghost_hidden()))
	if audio != null:
		audio.play_button()


## El jugador ha tocado el sonido desde opciones (T-087).
func _on_sound_toggled() -> void:
	if audio == null or options_panel == null:
		return
	options_panel.set_muted(_on_mute_pressed())


func _abrir_estadisticas() -> void:
	if stats_panel == null:
		return
	stats_panel.set_stats(stats_rows())
	stats_panel.set_open(true)


func _refrescar_menu() -> void:
	if menu_panel != null:
		menu_panel.set_high_score(_high_score)
	if options_panel != null:
		options_panel.set_difficulty(_session.difficulty())
		options_panel.set_player_name(_session.player_name())


## Traslada la confianza guardada a Flapo (T-074).
##
## Es lo único que la progresión toca del juego, y se hace al empezar cada
## partida: el jugador la nota en una barra de aliento más larga, no en un
## menú ni en un mensaje. Ver ADR-0021.
func _aplicar_confianza() -> void:
	bird.max_breath = _session.max_breath()


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
	if to == GameState.State.MENU:
		_score = 0
		_refrescar_menu()
	else:
		# Salir del menú cierra lo que hubiera abierto encima: si no, se
		# quedaría delante de la partida.
		if stats_panel != null:
			stats_panel.set_open(false)
		if options_panel != null:
			options_panel.set_open(false)
	if to == GameState.State.READY:
		_score = 0
		_is_new_high_score = false
		effects.clear()
		_aplicar_confianza()
		# Antes que nada: los sistemas tienen que recibir el generador ya
		# sembrado antes de que su propio `on_game_state_changed` los
		# reinicie y empiece a pedirle números.
		_session.sembrar([pipe_spawner, fruit_spawner, wind])
		# Después de sembrar: hasta ahí, la semilla de una partida libre
		# todavía es 0 y el fantasma no sabría si le toca salir (T-243).
		if ghost != null:
			ghost.preparar(_session.seed())
		if replay_recorder != null:
			replay_recorder.preparar(_session.seed(), _session.difficulty(), _session.confidence())
		_huecos_sin_planear = 0
		bird.gravity_mult = 1.0
		bird.size_mult = 1.0
		bird.hitbox_mult = 1.0
		_apply_difficulty()
		score_changed.emit(_score)
	_actualizar_aviso_planeo()
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
		"MenuPanel": menu_panel,
		"Wind": wind,
		"Ghost": ghost,
		"ReplayRecorder": replay_recorder,
	}
	if pause_panel == null:
		push_error("Main no tiene asignado el nodo PausePanel en el inspector.")
		return
	pause_panel.resume_pressed.connect(set_paused.bind(false))
	pause_panel.save_replay_pressed.connect(_on_save_replay_pressed)
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
	bird.soft_hit.connect(_on_soft_hit)
	bird.breath_recovered.connect(_on_breath_recovered)
	bird.glided.connect(_on_glided)
	if wind != null:
		wind.warning_started.connect(_on_wind_warning)
		wind.gust_started.connect(_on_wind_gust)
		wind.gust_ended.connect(_on_wind_ended)
	game_over_panel.menu_pressed.connect(to_menu)
	if menu_panel != null:
		menu_panel.play_pressed.connect(start_free)
		menu_panel.stats_pressed.connect(_abrir_estadisticas)
		menu_panel.options_pressed.connect(_abrir_opciones)
		# Jugar normal sortea semilla; el reto usa la de hoy (T-241).
		menu_panel.daily_pressed.connect(start_daily.bind([]))
		menu_panel.code_pressed.connect(_on_code_pressed)
	if stats_panel != null:
		stats_panel.back_pressed.connect(func() -> void: stats_panel.set_open(false))
	if options_panel != null:
		options_panel.back_pressed.connect(func() -> void: options_panel.set_open(false))
		options_panel.name_changed.connect(_session.set_player_name)
		options_panel.difficulty_selected.connect(_on_difficulty_selected)
		options_panel.sound_toggled.connect(_on_sound_toggled)
		options_panel.ghost_toggled.connect(_on_ghost_toggled)
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
		game_over_panel.set_player_name(_session.player_name())
		game_over_panel.set_challenge(_session.daily.nombre())
		game_over_panel.set_code("" if _session.daily.activo() else _session.codigo())
		game_over_panel.show_results(_score, _high_score, _is_new_high_score)
		game_over_panel.set_line(_siguiente_frase())


## Elige la frase de esta muerte, distinta de la anterior (T-056) y acorde a
## cómo se murió (T-075).
func _siguiente_frase() -> String:
	if death_lines == null:
		return ""
	var frase: String = death_lines.pick_for(
		_death_cause, _death_breathless, _rng_cosmetico, _ultima_frase
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
	if not _session.has_glided():
		_huecos_sin_planear += 1
		_actualizar_aviso_planeo()
	if wind != null:
		wind.enabled = _score >= GameConfig.WIND_MIN_SCORE
	if audio != null:
		audio.play_point()
	_apply_difficulty()
	score_changed.emit(_score)


## Empieza el aviso de ráfaga (T-064). Todavía no sopla: esto es el tiempo
## que tiene el jugador para colocarse.
func _on_wind_warning(a_favor: bool) -> void:
	if hud != null:
		hud.set_wind("aviso", a_favor)


func _on_wind_gust(a_favor: bool) -> void:
	if hud != null:
		hud.set_wind("sopla", a_favor)
	_apply_difficulty()


## El viento se deshace solo: no hay estado que limpiar, basta con recalcular
## la dificultad, que es función pura de la puntuación (ADR-0018).
func _on_wind_ended() -> void:
	if hud != null:
		hud.set_wind("", true)
	_apply_difficulty()


## Flapo ha planeado (T-200). La primera vez es la que importa: se guarda y
## el aviso no vuelve a salir jamás.
func _on_glided() -> void:
	_session.marcar_planeo()
	_actualizar_aviso_planeo()


## Decide qué aviso de planeo toca, si es que toca alguno (T-200).
##
## Todo el "¿toca?" son funciones puras de GameConfig; aquí solo se junta el
## estado y se llama. Así la regla se puede probar sin montar el juego.
func _actualizar_aviso_planeo() -> void:
	if glide_hint == null:
		return
	var partidas: int = SaveManager.get_games_played()
	if _state == GameState.State.READY:
		var pict: bool = GameConfig.show_glide_pictogram(_session.has_glided(), partidas)
		glide_hint.mostrar("pictograma" if pict else "")
		return
	if _state == GameState.State.PLAYING:
		var aviso: bool = GameConfig.show_glide_hint(
			_session.has_glided(), partidas, _huecos_sin_planear
		)
		glide_hint.mostrar("aviso" if aviso else "")
		return
	glide_hint.mostrar("")


## Flapo ha cogido aire (T-202). El sonido va aquí y no en Flapo porque el
## audio lo gobierna Main, como el resto ("call down", ADR-0005).
func _on_breath_recovered(_cantidad: float) -> void:
	if audio != null:
		audio.play_breath()


## Flapo ha rebotado en una tubería blandita (T-066).
##
## El aliento ya se lo ha cobrado él —es suyo—; aquí se cobra el punto, que
## es del marcador. Nunca baja de 0: quedarse en negativo sería un castigo
## que no se puede recuperar, y la blandita existe justo para no castigar así.
func _on_soft_hit() -> void:
	if audio != null:
		audio.play_fruit_bad()
	if juice != null:
		juice.punch()
	var antes: int = _score
	_score = maxi(_score - GameConfig.SOFT_PIPE_SCORE_COST, 0)
	if _score == antes:
		return
	_apply_difficulty()
	score_changed.emit(_score)


## El factor de viento de este instante (T-064).
##
## Se pregunta a `GameConfig` en vez de guardarlo: la dirección que de verdad
## cabe depende de la puntuación, que cambia mientras sopla.
func _wind_factor() -> float:
	if wind == null or not wind.is_blowing():
		return 1.0
	return GameConfig.wind_factor_for(_score, _session.difficulty(), wind.is_tailwind())


## Empuja la dificultad de la puntuación actual a quien la necesita.
##
## "Call down" (ADR-0005): los sistemas no consultan la puntuación, la reciben.
## Al ser funciones puras de la puntuación (ADR-0018), volver a READY con el
## marcador a 0 restaura la dificultad inicial sin código de reinicio.
func _apply_difficulty() -> void:
	# El orden importa. Primero la curva, luego el viento ACOTADO al sobre de
	# la curva (T-064), y solo al final el modificador de la fruta violeta,
	# que sí puede bajar del mínimo: ese es su efecto, y el criterio del
	# viento no debía llevárselo por delante.
	var velocidad: float = GameConfig.wind_speed_for(_score, _session.difficulty(), _wind_factor())
	velocidad *= effects.speed_mult()
	var hueco: float = GameConfig.pipe_gap_for(_score, _session.difficulty())
	var separacion: float = GameConfig.pipe_spacing_for(_score, _session.difficulty())
	if pipe_spawner != null:
		pipe_spawner.set_difficulty(velocidad, hueco, separacion)
		# La probabilidad de tubería móvil es una función pura de la
		# puntuación, como el resto de la curva (T-063).
		pipe_spawner.moving_chance = GameConfig.moving_pipe_chance(_score)
		pipe_spawner.spin_chance = GameConfig.spin_pipe_chance(_score)
	if ground != null:
		ground.scroll_speed = velocidad
	if background != null:
		background.scroll_speed = velocidad
	if fruit_spawner != null:
		fruit_spawner.set_difficulty(velocidad, hueco, separacion)


## Guarda una copia del replay desde la pausa (T-261).
##
## La partida sigue viva: el fichero recoge lo jugado hasta aquí, que es lo
## que quiere quien acaba de ver algo raro y pausa para conservarlo.
func _on_save_replay_pressed() -> void:
	if replay_recorder == null:
		return
	var ruta: String = replay_recorder.guardar_copia(_score)
	pause_panel.set_aviso("Guardada" if ruta != "" else "No se ha podido guardar")


## Alterna el silencio y lo cuenta a los dos paneles que lo enseñan.
func _on_mute_pressed() -> bool:
	if audio == null:
		return false
	var muted: bool = audio.toggle_muted()
	audio.play_button()
	pause_panel.set_muted(muted)
	game_over_panel.set_muted(muted)
	return muted


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
	# En el reto, la marca va a SU clave. El récord general no se toca: son
	# dos cosas que se comparan con gente distinta (T-241).
	_is_new_high_score = _session.registrar_partida(_score)
	_high_score = SaveManager.get_high_score()
	# Antes de cambiar de estado, mientras el vuelo grabado sigue completo.
	if ghost != null:
		ghost.terminar(_score, _is_new_high_score)
	# Siempre, no solo si pasa algo raro: un replay solo sirve si ya estaba
	# grabado cuando apareció el bug (T-261).
	if replay_recorder != null:
		replay_recorder.terminar(_score)
	change_state(GameState.State.GAME_OVER)


func _on_state_changed_log(to: GameState.State) -> void:
	print("[Main] estado -> ", _state_name(to))


func _state_name(state: GameState.State) -> String:
	return GameState.State.keys()[state]
