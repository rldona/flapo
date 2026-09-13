class_name Brother
extends Node2D
## El hermano famoso, que pasa por delante sin despeinarse (T-204).
##
## **Puro escenario**: `Node2D` con un sprite y ni una forma de colisión en
## toda la escena. No es un `CharacterBody2D`, no colisiona, no puntúa y no se
## le alcanza. Es un chiste que cruza la pantalla, y el humor es con Flapo,
## nunca contra él (GDD).
##
## Deja una estela detrás. Ese es todo su efecto en el juego: el rebufo.

## Velocidad de scroll del mundo, px/s. Él va más rápido.
@export var scroll_speed: float = GameConfig.SCROLL_SPEED

## Si se mueve. El spawner lo congela en GAME_OVER.
@export var moving: bool = true

@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	# Más esbelto que Flapo, y con el mismo dibujo: la broma es que es el
	# mismo pájaro al que le sale fácil, no otro personaje.
	scale = Vector2(1.0, 0.72)


func _physics_process(delta: float) -> void:
	if not moving:
		return
	position.x -= scroll_speed * AirConfig.BROTHER_SPEED_MULT * delta
	if position.x < -32.0:
		queue_free()


## Si sigue en pantalla. Lo usan los tests.
func en_pantalla() -> bool:
	return position.x > -32.0
