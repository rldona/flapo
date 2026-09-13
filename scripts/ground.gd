class_name Ground
extends Node2D
## Suelo con scroll infinito.
##
## Dos tiles que se desplazan a la izquierda y se recolocan. La colisión NO
## se mueve: es un único `StaticBody2D` quieto que cubre todo el ancho. Mover
## la colisión con los tiles no aportaría nada y sí podría dejar una costura
## por la que Flapo se colara justo en el frame del reciclado. Ver ADR-0010.

## Velocidad de scroll, px/s. La fija Main según la puntuación (ADR-0018).
@export var scroll_speed: float = GameConfig.SCROLL_SPEED

## Si está en marcha. Main lo para en GAME_OVER.
@export var moving: bool = true

## Desplazamiento acumulado dentro de un tile, px. Siempre en [0, ancho).
var _offset: float = 0.0
var _tile_width: float = 0.0

@onready var _tiles: Array[Node2D] = [$Tile0, $Tile1]
@onready var _body: StaticBody2D = $StaticBody2D
@onready var _relleno: ColorRect = $Relleno


func _ready() -> void:
	_tile_width = float(GameConfig.VIEWPORT_SIZE.x)
	_montar_colision()
	_remontar_tiles()
	# La pantalla puede cambiar de tamaño en marcha (T-085) y el suelo tiene
	# que seguir llegando abajo.
	get_viewport().size_changed.connect(_remontar_tiles)


## Vuelve a dimensionar los tiles al alto que haga falta.
func _remontar_tiles() -> void:
	for tile in _tiles:
		_montar_tile(tile)
	_colocar_tiles()
	_montar_relleno()


## Rellena de tierra lisa desde el final del tile hasta el borde de abajo.
func _montar_relleno() -> void:
	if _relleno == null:
		return
	var alto: float = GameConfig.ground_fill_height(get_viewport_rect().size.y, surface_y())
	_relleno.size = Vector2(_tile_width, alto)
	_relleno.position = Vector2(0.0, surface_y() + GameConfig.GROUND_HEIGHT)
	_relleno.visible = alto > 0.0


func _physics_process(delta: float) -> void:
	if not moving:
		return
	# `fmod` en vez de "si se ha salido, súmale el ancho": el offset nunca
	# crece, así que no acumula error de coma flotante por muy larga que sea
	# la partida, y los dos tiles quedan pegados por construcción. Es lo que
	# cumple el criterio de "sin salto visible al reciclar".
	_offset = fmod(_offset + scroll_speed * delta, _tile_width)
	_colocar_tiles()


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	# El suelo sigue corriendo en READY: es lo que da sensación de mundo vivo
	# mientras Flapo espera. Solo se para al morir.
	moving = to != GameState.State.GAME_OVER


## Y de la superficie del suelo, px. Es donde Flapo se estrella.
func surface_y() -> float:
	return GameConfig.playable_height()


func _colocar_tiles() -> void:
	for i in _tiles.size():
		_tiles[i].position = Vector2(-_offset + _tile_width * float(i), surface_y())


func _montar_tile(tile: Node2D) -> void:
	var sprite := tile.get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return
	# Región más ancha que la textura + `texture_repeat`: el tile de 32 px se
	# repite hasta cubrir el ancho de pantalla, sin estirarse.
	sprite.region_rect = Rect2(0.0, 0.0, _tile_width, GameConfig.GROUND_HEIGHT)
	sprite.position = Vector2.ZERO


func _montar_colision() -> void:
	var forma := RectangleShape2D.new()
	# Más ancho que la pantalla: así ningún borde queda dentro del área de
	# juego, ni siquiera con márgenes raros en pantallas altas (T-073).
	forma.size = Vector2(_tile_width * 3.0, GameConfig.GROUND_HEIGHT)
	var cs := _body.get_node("CollisionShape2D") as CollisionShape2D
	cs.shape = forma
	cs.position = Vector2(_tile_width * 0.5, surface_y() + GameConfig.GROUND_HEIGHT * 0.5)
