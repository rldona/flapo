extends SceneTree
## Banco de medidas para el tuning de T-040.
##
##     /Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 \
##       --path . -s tools/medir_feel.gd
##
## No es un test: no afirma nada ni falla. Convierte las constantes del juego
## en las magnitudes que el jugador percibe de verdad —cuánto sube un aleteo,
## cuánto tiempo tienes para reaccionar, cuántos píxeles sobran al cruzar—
## para poder tunear con datos en vez de a ojo. La decisión sigue siendo
## humana; esto solo dice qué se está decidiendo.

const MAIN := "res://scenes/Main.tscn"

var _main: Node


func _init() -> void:
	_main = load(MAIN).instantiate()
	_main.log_transitions = false
	root.add_child(_main)
	await process_frame
	print("=== Banco de medidas · T-040 ===\n")
	_constantes()
	await _altura_del_aleteo()
	await _ventana_de_reaccion()
	await _margen_del_hueco()
	await _aleteo_fatigado()
	await _dificultad_de_una_partida()
	_curva_de_dificultad()
	print("\nLas constantes están en scripts/bird.gd (@export) y")
	print("scripts/game_config.gd. Cambia, vuelve a ejecutar, compara.")
	quit()


## La curva de T-045, punto por punto. Es la tabla que hay que mirar al
## tunearla: la columna de aleteos es la que dice si es difícil o injusta.
func _curva_de_dificultad() -> void:
	_cab("Curva de dificultad (T-045)")
	print("  puntos   velocidad   hueco   separación   intervalo   aleteos")
	for score in [0, 5, 10, 15, 20, 25, 30, 60]:
		print(
			(
				"  %6d   %7.1f     %5.1f   %8.1f     %7.2f   %7.2f"
				% [
					score,
					GameConfig.scroll_speed_for(score),
					GameConfig.pipe_gap_for(score),
					GameConfig.pipe_spacing_for(score),
					GameConfig.pipe_spawn_interval_for(score),
					GameConfig.flaps_between_pipes(score),
				]
			)
		)
	print("  por debajo de 3 aleteos el juego pasa de difícil a injusto")


func _cab(t: String) -> void:
	print("\n--- %s" % t)


func _constantes() -> void:
	var b: Node = _main.bird
	_cab("Constantes actuales")
	print("  gravedad            %7.1f px/s²" % b.gravity)
	print("  impulso de aleteo   %7.1f px/s" % b.flap_impulse)
	print("  tope de caída       %7.1f px/s" % b.max_fall_speed)
	print("  velocidad de scroll %7.1f px/s" % GameConfig.SCROLL_SPEED)
	print("  separación tuberías %7.1f px" % GameConfig.PIPE_SPACING)
	print("  hueco               %7.1f px" % GameConfig.PIPE_GAP)
	print("  alto de Flapo         24 px · hitbox radio 8")


## Cuánto sube Flapo con un aleteo y cuánto tarda en volver. Es LA medida:
## si el salto no se lee, el juego no se controla.
func _altura_del_aleteo() -> void:
	var b: Node = _main.bird
	_cab("Un aleteo")
	var y0: float = 256.0
	b.position.y = y0
	b.velocity = Vector2.ZERO
	b.on_game_state_changed(GameState.State.PLAYING)
	b.velocity.y = b.flap_impulse
	var pico: float = y0
	var t_pico: int = 0
	var t: int = 0
	while t < 240:
		await physics_frame
		t += 1
		if b.position.y < pico:
			pico = b.position.y
			t_pico = t
		if b.position.y >= y0 and t > t_pico and t_pico > 0:
			break
	print("  sube                %7.1f px" % (y0 - pico))
	print("  tarda en subir      %7.3f s" % (t_pico / 60.0))
	print("  ida y vuelta        %7.3f s" % (t / 60.0))
	print("  eso son             %7.1f alturas de Flapo" % ((y0 - pico) / 24.0))


## Lo mismo que `_altura_del_aleteo`, pero con Flapo fatigado (T-049).
##
## La comparación es lo que importa: si la diferencia no se ve en píxeles, la
## penalización no se nota jugando y no sirve de nada.
func _aleteo_fatigado() -> void:
	var b: Node = _main.bird
	_cab("Un aleteo fatigado")
	var mult: float = GameConfig.fatigue_impulse_mult(GameConfig.FATIGUE_FLAP_COUNT + 1)
	var y0: float = 256.0
	b.position.y = y0
	b.velocity = Vector2.ZERO
	b.on_game_state_changed(GameState.State.PLAYING)
	b.velocity.y = b.flap_impulse * mult
	var pico: float = y0
	var t: int = 0
	while t < 240:
		await physics_frame
		t += 1
		pico = minf(pico, b.position.y)
		if b.position.y >= y0 and t > 10:
			break
	print(
		(
			"  umbral               %5d aleteos en %.1f s"
			% [GameConfig.FATIGUE_FLAP_COUNT, GameConfig.FATIGUE_WINDOW]
		)
	)
	print("  penalización         %5.0f %%" % (GameConfig.FATIGUE_PENALTY * 100.0))
	print("  sube                 %5.1f px  (sano: ver arriba)" % (y0 - pico))
	print("  ratio de altura      %5.2f  (el impulso baja x%.2f)" % [mult * mult, mult])
	print("  la altura cae con el CUADRADO del impulso: media penalización de")
	print("  impulso es bastante menos de media altura")


## Cuánto tiempo pasa entre que ves una tubería y la cruzas.
func _ventana_de_reaccion() -> void:
	_cab("Ventana de reacción")
	var ancho: float = float(GameConfig.VIEWPORT_SIZE.x)
	var x_flapo: float = 72.0
	var v: float = GameConfig.SCROLL_SPEED
	print("  aparece a %.0f px y Flapo está en %.0f" % [ancho, x_flapo])
	print("  tiempo desde que entra hasta que llega: %.2f s" % ((ancho - x_flapo) / v))
	print("  tiempo entre dos tuberías:              %.2f s" % GameConfig.pipe_spawn_interval())
	print(
		"  aleteos que caben entre tuberías:       %.1f" % (GameConfig.pipe_spawn_interval() / 0.35)
	)


## Cuánto margen sobra al pasar por el centro del hueco.
func _margen_del_hueco() -> void:
	_cab("Margen del hueco")
	var hueco: float = GameConfig.PIPE_GAP
	var diametro: float = 16.0  # hitbox radio 8
	print("  hueco                    %5.1f px" % hueco)
	print("  hitbox de Flapo          %5.1f px" % diametro)
	print(
		(
			"  margen total             %5.1f px (%.1f arriba y abajo)"
			% [hueco - diametro, (hueco - diametro) / 2.0]
		)
	)
	print("  el dibujo mide 24 px, así que sobresale 4 px por lado sin matar")


## Cuánto dura una partida sin tocar nada, y cuánto con un aleteo por tubería.
func _dificultad_de_una_partida() -> void:
	_cab("Dificultad")
	# Se coloca a Flapo donde empieza de verdad: la prueba anterior lo dejó
	# a media caída y la medida salía casi el doble de optimista.
	_main.bird.position = _main.bird.start_position
	_main.bird.velocity = Vector2.ZERO
	_main.bird.on_game_state_changed(GameState.State.READY)
	await physics_frame
	_main.change_state(GameState.State.PLAYING)
	var t: int = 0
	while t < 1200 and _main.get_state() != GameState.State.GAME_OVER:
		await physics_frame
		t += 1
	print(
		(
			"  desde y=%.0f hasta el suelo (y=%.0f)"
			% [_main.bird.start_position.y, _main.ground.surface_y()]
		)
	)
	print("  sin tocar nada, Flapo cae al suelo en %.2f s" % (t / 60.0))
	print(
		(
			"  a esa velocidad, eso es %.1f tuberías sin puntuar"
			% ((t / 60.0) / GameConfig.pipe_spawn_interval())
		)
	)
