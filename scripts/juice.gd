class_name Juice
extends Node
## Todo el "jugo" del momento de morir, en un solo sitio.
##
## Flash blanco, sacudida de cámara, hit-stop, rebote de Flapo y giro de
## aturdimiento. Está junto porque son un mismo golpe: si cada efecto viviera
## en su nodo, ajustar "cuánto duele morir" obligaría a tocar cinco sitios.
##
## Todas las intensidades son `@export`, que es el criterio de T-042.

@export_group("Flash")
## Opacidad máxima del fogonazo blanco.
@export_range(0.0, 1.0) var flash_alpha: float = 0.75
## Cuánto tarda en apagarse, s.
@export var flash_time: float = 0.28

@export_group("Sacudida de cámara")
## Desplazamiento máximo, px. Flapo sacude más fuerte que un Flappy normal
## (GDD, "Concepto y tono"): pesa el doble.
@export var shake_strength: float = 7.0
## Cuánto tarda en calmarse, s.
@export var shake_time: float = 0.45
## Sacudidas por segundo. Bajo = temblor lento; alto = vibración.
@export var shake_frequency: float = 34.0

@export_group("Hit-stop")
## Congelación al golpear, s. El GDD pide 60-100 ms.
@export_range(0.0, 0.3) var hit_stop_time: float = 0.08

@export_group("Rebote")
## Impulso hacia arriba al chocar, px/s. Negativo = hacia arriba.
@export var bounce_impulse: float = -180.0
## Giro de aturdimiento, rad/s. Placeholder de los ojos en espiral del GDD
## hasta que exista el sprite (T-050).
@export var stun_spin: float = 9.0

## La cámara a sacudir. Sin ella, el resto del jugo sigue funcionando.
@export var camera: Camera2D
## El ColorRect del fogonazo.
@export var flash_rect: ColorRect

var _shake_left: float = 0.0
var _flash_left: float = 0.0
## Frames de dibujo que le quedan a la congelación. Ver `_hit_stop()`.
var _hit_stop_frames: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_reset()


func _process(delta: float) -> void:
	_update_hit_stop()
	_update_shake(delta)
	_update_flash(delta)


## Red de seguridad: si este nodo desaparece a media congelación (cambio de
## escena, cierre del juego), el reloj se queda parado para todo el motor.
func _exit_tree() -> void:
	if _hit_stop_frames > 0:
		Engine.time_scale = 1.0


## Main llama a esto al morir Flapo.
func punch() -> void:
	_shake_left = shake_time
	_flash_left = flash_time
	_hit_stop()


## Main llama a esto al volver a READY: el jugo no debe sobrevivir al
## reinicio (criterio "no rompe el reinicio" de T-042).
func on_game_state_changed(to: GameState.State) -> void:
	if to == GameState.State.READY:
		_reset()


func _reset() -> void:
	_shake_left = 0.0
	_flash_left = 0.0
	_hit_stop_frames = 0
	Engine.time_scale = 1.0
	if camera != null:
		camera.offset = Vector2.ZERO
	if flash_rect != null:
		flash_rect.color.a = 0.0


## Congela el juego un instante para que el golpe se sienta.
##
## Se cuenta en FRAMES DE DIBUJO, no con un `await` sobre un temporizador.
## Un `await` está atado a la vida del nodo: si el nodo se libera antes de que
## venza, la corrutina no se reanuda nunca y `Engine.time_scale` se queda en 0
## para todo el motor — el juego congelado sin remedio. Contar frames no
## depende de nada externo, y `_process` sigue corriendo aunque el reloj de
## la simulación esté parado, porque el tiempo escalado solo afecta a `delta`.
func _hit_stop() -> void:
	if hit_stop_time <= 0.0:
		return
	_hit_stop_frames = maxi(int(round(hit_stop_time * 60.0)), 1)
	Engine.time_scale = 0.0


func _update_hit_stop() -> void:
	if _hit_stop_frames <= 0:
		return
	_hit_stop_frames -= 1
	if _hit_stop_frames <= 0:
		Engine.time_scale = 1.0


func _update_shake(delta: float) -> void:
	if camera == null:
		return
	if _shake_left <= 0.0:
		camera.offset = Vector2.ZERO
		return
	_shake_left = maxf(_shake_left - delta, 0.0)
	# La intensidad decae con lo que queda: empieza fuerte y se calma sola.
	var intensidad: float = shake_strength * (_shake_left / shake_time)
	var fase: float = _shake_left * shake_frequency
	camera.offset = Vector2(
		sin(fase) * intensidad, cos(fase * 1.37) * intensidad * 0.6
	)


func _update_flash(delta: float) -> void:
	if flash_rect == null:
		return
	if _flash_left <= 0.0:
		flash_rect.color.a = 0.0
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	flash_rect.color.a = flash_alpha * (_flash_left / flash_time)
