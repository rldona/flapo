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
signal died

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
## Red de seguridad provisional hasta que exista el suelo real (T-027).
@export var fall_death_y: float = 512.0

@export_group("Rotación")
## Ángulo con el impulso de aleteo a tope (morro arriba).
@export var rotation_up_degrees: float = -25.0
## Ángulo a velocidad de caída máxima (picado).
@export var rotation_down_degrees: float = 90.0
## Cuánto tarda en alcanzar el ángulo objetivo. Más bajo, más perezoso.
@export_range(1.0, 30.0) var rotation_speed: float = 9.0

var _state: GameState.State = GameState.State.READY
var _dead: bool = false


func _physics_process(delta: float) -> void:
	match _state:
		GameState.State.READY:
			# Flota: ni gravedad ni entrada. El aleteo que arranca la partida
			# lo consume Main; Flapo solo empieza a caer cuando ya es PLAYING.
			velocity = Vector2.ZERO
		GameState.State.PLAYING:
			_apply_gravity(delta)
			# `is_action_just_pressed` es consciente de si lo llamas desde un
			# frame de física o de dibujo, así que aquí no se pierde ni se
			# duplica ninguna pulsación aunque los fps bailen.
			if Input.is_action_just_pressed("flap"):
				velocity.y = flap_impulse
		GameState.State.GAME_OVER:
			# Sigue cayendo, pero ya no responde: el batacazo se ve entero.
			_apply_gravity(delta)

	move_and_slide()
	_clamp_to_ceiling()
	_update_rotation(delta)

	if _state == GameState.State.PLAYING:
		_check_death()


## Main llama a esto al emitir `state_changed`: el hijo no busca al padre.
func on_game_state_changed(to: GameState.State) -> void:
	_state = to
	if to == GameState.State.READY:
		_dead = false
		velocity = Vector2.ZERO
		rotation = 0.0


func _apply_gravity(delta: float) -> void:
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


func _clamp_to_ceiling() -> void:
	if position.y < ceiling_y:
		position.y = ceiling_y
		# Sin esto, Flapo se queda pegado al techo acumulando velocidad
		# negativa y luego tarda una eternidad en volver a bajar.
		velocity.y = maxf(velocity.y, 0.0)


func _update_rotation(delta: float) -> void:
	# La velocidad vertical se mapea a un ángulo: subiendo, morro arriba;
	# cayendo, picado. Es el truco que hace legible el salto sin animación.
	var fall_ratio: float = clampf(
		inverse_lerp(flap_impulse, max_fall_speed, velocity.y), 0.0, 1.0
	)
	var target: float = deg_to_rad(
		lerpf(rotation_up_degrees, rotation_down_degrees, fall_ratio)
	)
	# Interpolación exponencial: independiente de los fps, a diferencia de un
	# `lerp(rotation, target, 0.2)` a pelo, que va más rápido cuantos más fps.
	rotation = lerp_angle(rotation, target, 1.0 - exp(-rotation_speed * delta))


func _check_death() -> void:
	if _dead:
		return
	if get_slide_collision_count() > 0 or position.y >= fall_death_y:
		_dead = true
		died.emit()
