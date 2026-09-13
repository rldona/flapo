class_name Ground
extends Node2D
## Suelo con scroll infinito.
##
## Dos tiles que se desplazan a la izquierda y se recolocan. La colisión NO
## se mueve: es un único `StaticBody2D` quieto que cubre todo el ancho. Mover
## la colisión con los tiles no aportaría nada y sí podría dejar una costura
## por la que Flapo se colara justo en el frame del reciclado. Ver ADR-0010.

## Si está en marcha. Main lo para en GAME_OVER.
@export var moving: bool = true

## Desplazamiento acumulado dentro de un tile, px. Siempre en [0, ancho).
var _offset: float = 0.0
var _tile_width: float = 0.0

@onready var _tiles: Array[Node2D] = [$Tile0, $Tile1]
@onready var _body: StaticBody2D = $StaticBody2D


func _ready() -> void:
	_tile_width = float(GameConfig.VIEWPORT_SIZE.x)
	_montar_colision()
	for tile in _tiles:
		_montar_tile(tile)
	_colocar_tiles()


func _physics_process(delta: float) -> void:
	if not moving:
		return
	# `fmod` en vez de "si se ha salido, súmale el ancho": el offset nunca
	# crece, así que no acumula error de coma flotante por muy larga que sea
	# la partida, y los dos tiles quedan pegados por construcción. Es lo que
	# cumple el criterio de "sin salto visible al reciclar".
	_offset = fmod(_offset + GameConfig.SCROLL_SPEED * delta, _tile_width)
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
	var rect := tile.get_node_or_null("Placeholder") as ColorRect
	if rect == null:
		return
	rect.offset_left = 0.0
	rect.offset_right = _tile_width
	rect.offset_top = 0.0
	rect.offset_bottom = GameConfig.GROUND_HEIGHT


func _montar_colision() -> void:
	var forma := RectangleShape2D.new()
	# Más ancho que la pantalla: así ningún borde queda dentro del área de
	# juego, ni siquiera con márgenes raros en pantallas altas (T-073).
	forma.size = Vector2(_tile_width * 3.0, GameConfig.GROUND_HEIGHT)
	var cs := _body.get_node("CollisionShape2D") as CollisionShape2D
	cs.shape = forma
	cs.position = Vector2(_tile_width * 0.5, surface_y() + GameConfig.GROUND_HEIGHT * 0.5)
