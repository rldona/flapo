class_name Fruit
extends Area2D
## Una fruta flotante (T-047).
##
## `Area2D` y no cuerpo: no frena a Flapo, solo detecta que la ha tocado. Es
## la misma pieza que la zona de puntuación (ADR-0008), con la diferencia de
## que esta se ve.
##
## Se mueve y se libera sola al salir de pantalla, como las tuberías.

## Flapo la ha cogido. Quien decide qué significa es Main.
signal taken(kind: Effects.Kind, puntos: int)

## Qué efecto da.
@export var kind: Effects.Kind = Effects.Kind.INMUNIDAD
## Puntos que suma al cogerla. Las frutas de castigo dan puntos: es lo que las
## convierte en una decisión en vez de en un obstáculo (ADR-0019).
@export var points: int = 0
## Velocidad de scroll, px/s. La fija el spawner.
@export var scroll_speed: float = GameConfig.SCROLL_SPEED
## Amplitud del vaivén vertical, px. Que floten las distingue de las tuberías.
@export var float_amplitude: float = 4.0
## Ciclos de vaivén por segundo.
@export var float_speed: float = 1.6

var _textura: Texture2D = null
var _tomada: bool = false
var _y_base: float = 0.0
var _fase: float = 0.0

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	if _textura != null:
		_sprite.texture = _textura
	_y_base = position.y
	_fase = randf() * TAU
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position.x -= scroll_speed * delta
	_fase += delta * float_speed * TAU
	position.y = _y_base + sin(_fase) * float_amplitude
	if position.x + 8.0 < 0.0:
		queue_free()


## Coloca la fruta y recuerda su altura de reposo.
func place(pos: Vector2) -> void:
	position = pos
	_y_base = pos.y


## Asigna el dibujo. Se puede llamar ANTES de meter la fruta en el árbol.
##
## `_sprite` es `@onready`, así que vale `null` hasta que el nodo entra en el
## árbol. La primera versión hacía `if _sprite != null: ...` y se tragaba la
## asignación en silencio: todas las frutas salían con la textura por defecto
## de la escena, la azul. Guardarla y aplicarla también en `_ready()` quita la
## dependencia del orden de llamada.
func set_texture(tex: Texture2D) -> void:
	_textura = tex
	if _sprite != null:
		_sprite.texture = tex


func _on_body_entered(cuerpo: Node2D) -> void:
	# Una sola vez: Flapo puede rozarla y volver a entrar en el mismo frame.
	if _tomada or not cuerpo is Bird:
		return
	_tomada = true
	taken.emit(kind, points)
	queue_free()
