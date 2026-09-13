class_name Bird
extends CharacterBody2D
## Flapo. Cae siempre, sube solo cuando el jugador aletea.
##
## Es un `CharacterBody2D` y no un `RigidBody2D` a propósito: aquí la física
## no simula, obedece (ver ADR-0006). Toda la lógica vive en
## `_physics_process`, que corre a 60 Hz fijos, así que las constantes en
## px/s significan siempre lo mismo pase lo que pase con los fps.

## Flapo ha chocado. La emite él porque es quien lo detecta; quien decide qué
## significa (pasar a GAME_OVER) es `Main`: "signal up".
##
## Lleva la causa y si llegó sin aliento (T-075): eso lo sabe Flapo en el
## momento del golpe y nadie más puede reconstruirlo después.
signal died(cause: DeathCause, sin_aliento: bool)

## La fatiga ha cambiado (T-049). `aleteos` es cuántos hay en la ventana.
signal fatigue_changed(fatigado: bool, aleteos: int)

## El aliento ha cambiado. La emite Flapo porque es suyo; quien lo enseña es
## el HUD, a través de Main.
signal breath_changed(actual: float, maximo: float)

## Flapo ha aleteado. La emite él porque es quien lee la entrada; quien
## decide que eso suena es Main.
signal flapped

## De qué se ha muerto Flapo (T-075).
##
## Son las causas que el juego tiene **de verdad**. Quedarse sin aliento no
## está aquí porque no mata: a 0 se pierde el planeo, nunca el aleteo
## (ADR-0020). Va como agravante en `died`, no como causa.
enum DeathCause {
	TUBERIA,  ## Se estampó contra una tubería.
	SUELO,  ## Se dio con el suelo.
	VACIO,  ## Se salió por abajo sin llegar a tocar nada.
}

## Capa de obstáculos (tuberías y suelo). Se guarda porque la inmunidad la
## apaga temporalmente y hay que saber a qué volver.
const OBSTACULOS: int = 4

@export_group("Física")
## Aceleración de caída, px/s². Flapo pesa; ver GDD, "Concepto y tono".
@export var gravity: float = 1200.0
## Velocidad vertical que se fija de golpe al aletear, px/s. Negativa porque
## en Godot 2D el eje Y crece hacia abajo.
@export var flap_impulse: float = -380.0
## Tope de velocidad de caída, px/s. Sin él, una caída larga se vuelve
## iningobernable y el aleteo deja de sentirse capaz de salvarte.
@export var max_fall_speed: float = 500.0
## Altura mínima alcanzable, px. Flapo no se sale por arriba.
@export var ceiling_y: float = 0.0
## Altura a la que se da por muerto si nada lo ha parado antes, px.
## Desde T-027 el suelo llega antes que esto: queda como red de seguridad
## por si Flapo acabara fuera del mundo (un hueco en la colisión, un tuneo
## que lo lance muy rápido). No debería dispararse nunca en una partida.
@export var fall_death_y: float = 512.0

@export_group("Colocación")
## Dónde aparece Flapo al empezar cada partida, px. Se toma de la posición
## que tenga en la escena, así que se mueve arrastrándolo en el editor.
@export var start_position: Vector2 = Vector2(72.0, 256.0)

@export_group("Muerte")
## Impulso hacia arriba al chocar, px/s. Lo fija Juice al morir.
@export var bounce_impulse: float = -180.0
## Giro de aturdimiento mientras cae muerto, rad/s.
@export var stun_spin: float = 9.0

@export_group("Planeo")
## Cuánto hay que mantener pulsado para que la pulsación cuente como planeo,
## s. El aleteo NO espera a esto: sale en el mismo frame de la pulsación, o el
## control dejaría de sentirse inmediato. Ver ADR-0020.
@export var glide_hold_time: float = 0.18
## Qué fracción de la gravedad se aplica planeando. 0.25 = cae a un cuarto.
@export_range(0.0, 1.0) var glide_gravity_mult: float = 0.25
## Tope de caída planeando, px/s. Muy por debajo del tope normal: planear es
## descender despacio, no flotar.
@export var glide_max_fall_speed: float = 90.0

@export_group("Animación")
## Frames por segundo del aleteo en reposo (cayendo, planeando).
@export var flap_fps_idle: float = 6.0
## Frames por segundo justo después de aletear. Más rápido = más esfuerzo
## visible, que es el chiste de Flapo (GDD, "Concepto y tono").
@export var flap_fps_burst: float = 20.0
## Cuánto dura el acelerón de la animación tras un aleteo, s.
@export var flap_burst_time: float = 0.18

@export_group("Rotación")
## Ángulo con el impulso de aleteo a tope (morro arriba).
@export var rotation_up_degrees: float = -25.0
## Ángulo a velocidad de caída máxima (picado).
@export var rotation_down_degrees: float = 90.0
## Cuánto tarda en alcanzar el ángulo objetivo. Más bajo, más perezoso.
@export_range(1.0, 30.0) var rotation_speed: float = 9.0

## Multiplicadores que vienen de las frutas (T-047). Los fija Main; el valor
## neutro es 1.0, así que sin frutas todo se comporta como antes.
var gravity_mult: float = 1.0
var size_mult: float = 1.0:
	set(valor):
		size_mult = valor
		_aplicar_tamano()
var hitbox_mult: float = 1.0:
	set(valor):
		hitbox_mult = valor
		_aplicar_tamano()

## Aliento máximo. Lo fija Main según la confianza acumulada (T-074); por
## defecto, el de salida.
var max_breath: float = GameConfig.MAX_BREATH:
	set(valor):
		max_breath = valor
		_breath = minf(_breath, max_breath)
		breath_changed.emit(_breath, max_breath)

var _state: GameState.State = GameState.State.READY
var _dead: bool = false
## Segundos que le quedan al acelerón de la animación.
var _burst_left: float = 0.0
## Radio original de la hitbox, para poder escalarla y devolverla.
var _radio_base: float = 8.0
## Aliento actual. Vive en Flapo porque es suyo y lo gastan sus acciones; las
## constantes están en GameConfig (T-048).
var _breath: float = GameConfig.MAX_BREATH
## Cuánto lleva pulsado el botón, s. Distingue toque de mantener.
var _held: float = 0.0
var _gliding: bool = false
## Marcas de tiempo de los últimos aleteos, s. Es el historial del que
## `GameConfig.fatigue_impulse_mult()` deriva la fatiga: aquí no hay estado de
## fatiga, solo datos (T-049).
var _flap_times: Array[float] = []
## Reloj propio, acumulado en `_physics_process`.
##
## No se usa `Time.get_ticks_msec()`, que es tiempo REAL: la ventana de fatiga
## seguiría corriendo con el juego en pausa (T-072) y se descuadraría con el
## hit-stop de la muerte (T-042), que pone `Engine.time_scale` a 0. El reloj
## del juego es el único que se para cuando el juego se para.
var _tiempo: float = 0.0
## Segundos que le quedan de no colisionar tras gastar un escudo.
var _invulnerable_left: float = 0.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	start_position = position
	# La forma viene del .tscn y por tanto es el MISMO recurso en todas las
	# instancias (la trampa de la ADR-0008). Como la fruta naranja la
	# redimensiona, hay que quedarse con una copia propia.
	_shape.shape = _shape.shape.duplicate()
	_radio_base = (_shape.shape as CircleShape2D).radius
	_sprite.play("flap")


func _physics_process(delta: float) -> void:
	_tiempo += delta
	match _state:
		# MENU se trata igual que READY: la pantalla de inicio es el mundo
		# quieto con un panel encima, no un sitio aparte (T-078).
		GameState.State.MENU, GameState.State.READY:
			# Flota: ni gravedad ni entrada. El aleteo que arranca la partida
			# lo consume Main; Flapo solo empieza a caer cuando ya es PLAYING.
			velocity = Vector2.ZERO
		GameState.State.PLAYING:
			_actualizar_planeo(delta)
			_apply_gravity(delta)
			# `is_action_just_pressed` es consciente de si lo llamas desde un
			# frame de física o de dibujo, así que aquí no se pierde ni se
			# duplica ninguna pulsación aunque los fps bailen.
			if Input.is_action_just_pressed("flap"):
				velocity.y = flap_impulse * _registrar_aleteo()
				_burst_left = flap_burst_time
				_gastar_aliento(GameConfig.BREATH_DRAIN_FLAP)
				flapped.emit()
		GameState.State.GAME_OVER:
			# Sigue cayendo, pero ya no responde: el batacazo se ve entero.
			_apply_gravity(delta)
			# Gira aturdido en el aire. Al tocar suelo se queda quieto, que
			# es cuando el rebote ya ha terminado.
			if not is_on_floor():
				rotation += stun_spin * delta

	move_and_slide()
	_clamp_to_ceiling()
	# En GAME_OVER manda el giro de aturdimiento y no el ángulo por velocidad:
	# si los dos escribieran `rotation`, se pelearían y el giro no se vería.
	# En READY no se toca la rotación. Si se dejara correr, el ángulo objetivo
	# con velocidad 0 no es 0° sino ~25° (el 0 cae dentro del rango
	# impulso..caída máxima), y Flapo iría cabeceando mientras espera.
	if _state == GameState.State.PLAYING:
		_update_rotation(delta)

	if _invulnerable_left > 0.0:
		_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
		if _invulnerable_left <= 0.0:
			collision_mask = OBSTACULOS

	_update_animation(delta)

	if _state == GameState.State.PLAYING:
		_check_death()


## Main llama a esto al emitir `state_changed`: el hijo no busca al padre.
func on_game_state_changed(to: GameState.State) -> void:
	_state = to
	if to == GameState.State.READY or to == GameState.State.MENU:
		# Reinicio completo: si algo de esto se olvidara, Flapo empezaría la
		# partida nueva muerto, girado o cayendo. Ver ADR-0011.
		_dead = false
		velocity = Vector2.ZERO
		rotation = 0.0
		position = start_position
		_burst_left = 0.0
		_held = 0.0
		_gliding = false
		_breath = max_breath
		breath_changed.emit(_breath, max_breath)
		_flap_times.clear()
		fatigue_changed.emit(false, 0)
		gravity_mult = 1.0
		size_mult = 1.0
		hitbox_mult = 1.0
		collision_mask = OBSTACULOS
		_sprite.play("flap")


## La animación va más rápida justo después de aletear y se PARA al morir.
##
## Parar es `pause()` y no `stop()`: `stop()` rebobinaría al primer frame, y
## lo que se quiere es que Flapo se quede congelado en la postura que tenía
## en el momento del golpe.
func _update_animation(delta: float) -> void:
	if _state == GameState.State.GAME_OVER:
		if _sprite.is_playing():
			_sprite.pause()
		return
	if not _sprite.is_playing():
		_sprite.play("flap")
	_burst_left = maxf(_burst_left - delta, 0.0)
	var fps: float = flap_fps_burst if _burst_left > 0.0 else flap_fps_idle
	# `speed_scale` multiplica la velocidad base de la animación (10 fps en
	# el SpriteFrames), así que se divide para que el @export esté en fps
	# reales y se pueda razonar sobre él.
	_sprite.speed_scale = fps / 10.0


## Sobrevive a un golpe: el escudo de la fruta azul (T-047).
##
## Además de no morir, deja de colisionar unos instantes. Si no, seguiría
## dentro de la tubería con la que acaba de chocar y moriría en el frame
## siguiente: el escudo no habría servido de nada.
func survive(segundos: float) -> void:
	_dead = false
	collision_mask = 0
	_invulnerable_left = segundos


func _aplicar_tamano() -> void:
	if _sprite != null:
		_sprite.scale = Vector2(size_mult, size_mult)
	if _shape != null and _shape.shape is CircleShape2D:
		(_shape.shape as CircleShape2D).radius = _radio_base * hitbox_mult


## Decide si Flapo está planeando y cobra el aliento correspondiente.
##
## El planeo se activa manteniendo pulsado el MISMO botón del aleteo: no hay
## input nuevo. Y con el aliento a 0 deja de frenar, pero el aleteo corto
## sigue funcionando siempre: Flapo nunca se queda sin poder aletear.
func _actualizar_planeo(delta: float) -> void:
	if Input.is_action_pressed("flap"):
		_held += delta
	else:
		_held = 0.0
	var quiere: bool = _held >= glide_hold_time
	var antes: bool = _gliding
	_gliding = quiere and _breath > 0.0
	if _gliding:
		_gastar_aliento(GameConfig.BREATH_DRAIN_GLIDE * delta)
		# Planear descansa: es la salida deliberada a la fatiga, y lo que
		# convierte "deja de machacar" en una acción y no en una espera.
		if not antes and not _flap_times.is_empty():
			_flap_times.clear()
			fatigue_changed.emit(false, 0)


## Anota el aleteo y devuelve el multiplicador de impulso que le toca.
##
## El historial se poda a la ventana antes de contar, así que "hace rato que
## no aleteo" y "he dejado de aletear" son lo mismo sin código extra.
func _registrar_aleteo() -> float:
	_flap_times.append(_tiempo)
	_podar_aleteos(_tiempo)
	var mult: float = GameConfig.fatigue_impulse_mult(_flap_times.size())
	fatigue_changed.emit(GameConfig.is_fatigued(_flap_times.size()), _flap_times.size())
	return mult


func _podar_aleteos(ahora: float) -> void:
	while not _flap_times.is_empty() and ahora - _flap_times[0] > GameConfig.FATIGUE_WINDOW:
		_flap_times.remove_at(0)


## Cuántos aleteos cuentan ahora mismo para la fatiga.
func recent_flaps() -> int:
	_podar_aleteos(_tiempo)
	return _flap_times.size()


## Si Flapo está fatigado ahora mismo.
func is_fatigued() -> bool:
	return GameConfig.is_fatigued(recent_flaps())


func _gastar_aliento(cantidad: float) -> void:
	_ajustar_aliento(-cantidad)


func _ajustar_aliento(delta_aliento: float) -> void:
	var antes: float = _breath
	_breath = clampf(_breath + delta_aliento, 0.0, max_breath)
	if not is_equal_approx(antes, _breath):
		breath_changed.emit(_breath, max_breath)


## Recupera aliento. Lo llama Main al cruzar el centro de un hueco.
func recover_breath(cantidad: float) -> void:
	_ajustar_aliento(cantidad)


## Aliento actual, en las unidades de GameConfig.MAX_BREATH.
func breath() -> float:
	return _breath


## Si Flapo está planeando ahora mismo.
func is_gliding() -> bool:
	return _gliding


func _apply_gravity(delta: float) -> void:
	# Planeando cae a una fracción de la gravedad y con un tope mucho más
	# bajo: es descender despacio, no flotar.
	if _gliding:
		velocity.y = minf(
			velocity.y + gravity * gravity_mult * glide_gravity_mult * delta, glide_max_fall_speed
		)
		return
	velocity.y = minf(velocity.y + gravity * gravity_mult * delta, max_fall_speed)


func _clamp_to_ceiling() -> void:
	if position.y < ceiling_y:
		position.y = ceiling_y
		# Sin esto, Flapo se queda pegado al techo acumulando velocidad
		# negativa y luego tarda una eternidad en volver a bajar.
		velocity.y = maxf(velocity.y, 0.0)


func _update_rotation(delta: float) -> void:
	# La velocidad vertical se mapea a un ángulo: subiendo, morro arriba;
	# cayendo, picado. Es el truco que hace legible el salto sin animación.
	var fall_ratio: float = clampf(inverse_lerp(flap_impulse, max_fall_speed, velocity.y), 0.0, 1.0)
	var target: float = deg_to_rad(lerpf(rotation_up_degrees, rotation_down_degrees, fall_ratio))
	# Interpolación exponencial: independiente de los fps, a diferencia de un
	# `lerp(rotation, target, 0.2)` a pelo, que va más rápido cuantos más fps.
	rotation = lerp_angle(rotation, target, 1.0 - exp(-rotation_speed * delta))


func _check_death() -> void:
	if _dead:
		return
	var choque: bool = get_slide_collision_count() > 0
	if not choque and position.y < fall_death_y:
		return
	_dead = true
	# El rebote se aplica aquí y no en Juice: es física de Flapo, y así
	# ocurre en el mismo tick del golpe, sin un frame de retraso.
	velocity.y = bounce_impulse
	var causa: DeathCause = _causa_del_choque() if choque else DeathCause.VACIO
	# Sin aliento no mata, pero sí explica: es la diferencia entre "se
	# estampó" y "llegó agotado y se estampó".
	died.emit(causa, is_zero_approx(_breath))


## Contra qué se ha dado. Tuberías y suelo comparten capa de colisión, así
## que no basta con la máscara: hay que mirar quién es el cuerpo tocado.
##
## Se sube por los ancestros porque el cuerpo con forma es un hijo
## (`Pipe/Top`, `Ground/StaticBody2D`) y el tipo vive en la raíz de la escena.
func _causa_del_choque() -> DeathCause:
	# Se recorren TODAS las colisiones antes de decidir: la tubería gana si se
	# tocan las dos a la vez, porque es la que cuenta la historia; el suelo
	# solo estaba ahí debajo.
	for i in get_slide_collision_count():
		var nodo: Object = get_slide_collision(i).get_collider()
		while nodo is Node:
			if nodo is Pipe:
				return DeathCause.TUBERIA
			nodo = (nodo as Node).get_parent()
	# Cualquier otra cosa en la capa de obstáculos es el suelo. Si algún día
	# hubiera un tercer obstáculo, este es el sitio donde añadirlo.
	return DeathCause.SUELO
