class_name Thermal
extends Area2D
## Una columna de aire ascendente (T-203).
##
## Dentro, **planear sube** en vez de caer despacio. El aleteo no cambia: la
## térmica le da un segundo uso al planeo —no solo ahorrar aliento, también
## trepar— sin tocar el control que ya se sabe.
##
## `Area2D` y no un cuerpo, ni la gravedad de área de Godot: ver ADR-0026. Se
## mueve y se libera sola al salir de pantalla, como las tuberías (ADR-0008).

## Flapo ha entrado o salido. Quien decide qué significa es Main.
signal cambiado(dentro: bool)

## Velocidad de scroll, px/s. La fija el spawner.
@export var scroll_speed: float = GameConfig.SCROLL_SPEED

## Si se mueve. El spawner la congela en GAME_OVER.
@export var moving: bool = true

@onready var _forma: CollisionShape2D = $CollisionShape2D
@onready var _particulas: CPUParticles2D = $Particulas


func _ready() -> void:
	var rect := RectangleShape2D.new()
	rect.size = GameConfig.THERMAL_SIZE
	_forma.shape = rect
	_particulas.emission_rect_extents = Vector2(
		GameConfig.THERMAL_SIZE.x * 0.5, GameConfig.THERMAL_SIZE.y * 0.5
	)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if not moving:
		return
	position.x -= scroll_speed * delta
	# Se libera sola cuando ya no puede verse ni tocarse (ADR-0008): el
	# spawner no lleva ninguna lista que mantener.
	if position.x < -GameConfig.THERMAL_SIZE.x:
		queue_free()


func _on_body_entered(cuerpo: Node2D) -> void:
	if cuerpo is Bird:
		cambiado.emit(true)


func _on_body_exited(cuerpo: Node2D) -> void:
	if cuerpo is Bird:
		cambiado.emit(false)
