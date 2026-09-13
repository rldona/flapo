class_name Pipe
extends Node2D
## Par de tuberías con un hueco por el que pasa Flapo.
##
## Los dos tubos son `StaticBody2D` y no `Area2D`: Flapo detecta la muerte
## con `get_slide_collision_count()`, que solo cuenta colisiones reales, y un
## área no frena ni colisiona. Ver ADR-0008.
##
## Se mueve solo, hacia la izquierda, y se libera al salir de pantalla. Quién
## lo crea y cuándo es asunto de `PipeSpawner` (T-025).

## Flapo ha cruzado el hueco. Se emite UNA sola vez por tubería.
signal scored

@export_group("Hueco")
## Alto del hueco, px. Es la constante que más cambia la dificultad.
@export var gap: float = 100.0:
	set(valor):
		gap = valor
		_apply_layout()
## Rango donde puede caer el centro del hueco, como fracción de la altura
## jugable. Evita huecos pegados al techo o al suelo.
@export_range(0.0, 1.0) var gap_center_min_ratio: float = 0.20
@export_range(0.0, 1.0) var gap_center_max_ratio: float = 0.80

@export_group("Geometría")
## Ancho del tubo, px. Ver docs/art-guide.md.
@export var width: float = 26.0
## Largo de cada tubo, px. Basta con que llegue a salirse de pantalla.
@export var body_length: float = 512.0

@export_group("Movimiento")
## Si está en marcha. `PipeSpawner` lo pone a false en GAME_OVER (T-025).
@export var moving: bool = true

var _gap_center: float = 256.0
var _ya_puntuada: bool = false

@onready var _top: StaticBody2D = $Top
@onready var _bottom: StaticBody2D = $Bottom
@onready var _score_zone: Area2D = $ScoreZone


func _ready() -> void:
	# Las formas se crean por instancia. Un `RectangleShape2D` guardado en el
	# .tscn sería el MISMO recurso en todas las tuberías: cambiar el tamaño de
	# una las cambiaría todas. Es la trampa clásica de los sub-recursos.
	_asignar_forma(_top)
	_asignar_forma(_bottom)
	_asignar_forma_zona()
	_score_zone.body_entered.connect(_on_score_zone_body_entered)
	_apply_layout()


func _physics_process(delta: float) -> void:
	if not moving:
		return
	position.x -= GameConfig.SCROLL_SPEED * delta
	# Se libera cuando su borde derecho ha pasado el borde izquierdo de la
	# pantalla. Sin esto, cada partida acumularía tuberías invisibles para
	# siempre: el criterio de nodos huérfanos de T-024 es exactamente esto.
	if position.x + width * 0.5 < 0.0:
		queue_free()


## Coloca el centro del hueco a una altura concreta, px.
func set_gap_center(y: float) -> void:
	_gap_center = y
	_apply_layout()


## Centro del hueco, px.
func get_gap_center() -> float:
	return _gap_center


## Sortea la altura del hueco dentro del rango permitido.
##
## El generador se inyecta en vez de usar el global: así `PipeSpawner` puede
## sembrarlo y una partida es reproducible en un test (T-080).
func randomize_gap(rng: RandomNumberGenerator) -> void:
	var ratio: float = rng.randf_range(gap_center_min_ratio, gap_center_max_ratio)
	# La altura jugable la comparten suelo y tuberías, así que sale de
	# GameConfig y no es un ajuste propio de la tubería (ADR-0003).
	set_gap_center(ratio * GameConfig.playable_height())


## Puntúa una vez y solo una.
##
## `body_entered` se dispara cada vez que Flapo entra, y Flapo oscila: sube y
## baja mientras cruza, y puede salir y volver a entrar por el mismo lado. El
## flag es lo que cumple el criterio de T-026; sin él, un aleteo dentro del
## hueco daría dos puntos.
func _on_score_zone_body_entered(cuerpo: Node2D) -> void:
	if _ya_puntuada or not cuerpo is Bird:
		return
	_ya_puntuada = true
	scored.emit()


func _asignar_forma(cuerpo: StaticBody2D) -> void:
	var forma := RectangleShape2D.new()
	forma.size = Vector2(width, body_length)
	(cuerpo.get_node("CollisionShape2D") as CollisionShape2D).shape = forma


func _asignar_forma_zona() -> void:
	var forma := RectangleShape2D.new()
	forma.size = Vector2(width, gap)
	(_score_zone.get_node("CollisionShape2D") as CollisionShape2D).shape = forma


func _apply_layout() -> void:
	if _top == null or _bottom == null:
		return  # Todavía no ha corrido `_ready()`; ya se llamará desde allí.
	var media_luz: float = gap * 0.5
	# Cada tubo se centra en su propio punto medio, de ahí el medio largo.
	_top.position.y = _gap_center - media_luz - body_length * 0.5
	_bottom.position.y = _gap_center + media_luz + body_length * 0.5
	_colocar_placeholder(_top)
	_colocar_placeholder(_bottom)
	# La zona de puntuación ES el hueco: mismo centro, mismo alto.
	_score_zone.position.y = _gap_center
	var forma := (_score_zone.get_node("CollisionShape2D") as CollisionShape2D).shape
	if forma is RectangleShape2D:
		(forma as RectangleShape2D).size = Vector2(width, gap)


func _colocar_placeholder(cuerpo: StaticBody2D) -> void:
	var rect := cuerpo.get_node_or_null("BodyPlaceholder") as ColorRect
	if rect == null:
		return
	rect.offset_left = -width * 0.5
	rect.offset_right = width * 0.5
	rect.offset_top = -body_length * 0.5
	rect.offset_bottom = body_length * 0.5
