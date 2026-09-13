class_name Slipstream
extends Area2D
## La estela que deja el hermano al pasar (T-204).
##
## Planear dentro **no gasta aliento**. No empuja, no sube, no puntúa: el
## rebufo es descanso, no ventaja. El chiste es que él pasa sin esfuerzo y tú
## aprovechas lo que deja.
##
## Se desvanece sola en `SLIPSTREAM_TIME` segundos y se libera: nadie lleva
## una lista de estelas que mantener (ADR-0008).

## Flapo ha entrado o salido.
signal cambiado(dentro: bool)

## Velocidad de scroll, px/s. Se mueve con el mundo, no con el hermano: el
## aire que dejó se queda donde estaba.
@export var scroll_speed: float = GameConfig.SCROLL_SPEED

## Si se mueve. El spawner la congela en GAME_OVER.
@export var moving: bool = true

## Ancho de la estela, px. Lo fija el spawner: es lo que el hermano recorre.
var ancho: float = 320.0

var _restante: float = GameConfig.SLIPSTREAM_TIME

@onready var _forma: CollisionShape2D = $CollisionShape2D
@onready var _dibujo: ColorRect = $Dibujo


func _ready() -> void:
	var rect := RectangleShape2D.new()
	rect.size = Vector2(ancho, GameConfig.SLIPSTREAM_HEIGHT)
	_forma.shape = rect
	_dibujo.size = rect.size
	_dibujo.position = -rect.size * 0.5
	body_entered.connect(func(c: Node2D) -> void: _avisar(c, true))
	body_exited.connect(func(c: Node2D) -> void: _avisar(c, false))


func _physics_process(delta: float) -> void:
	if not moving:
		return
	position.x -= scroll_speed * delta
	_restante -= delta
	# Se apaga desvaneciéndose, no de golpe: una zona que deja de funcionar
	# sin avisar es un bug desde el asiento del jugador.
	_dibujo.modulate.a = clampf(_restante / GameConfig.SLIPSTREAM_TIME, 0.0, 1.0) * 0.5
	if _restante <= 0.0 or position.x < -ancho:
		queue_free()


## Cuánto le queda de vida, s. Lo usan los tests.
func restante() -> float:
	return _restante


func _avisar(cuerpo: Node2D, dentro: bool) -> void:
	if cuerpo is Bird:
		cambiado.emit(dentro)
