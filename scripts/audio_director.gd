class_name AudioDirector
extends Node
## Todos los sonidos del juego en un sitio.
##
## No es autoload: con el reinicio en sitio (ADR-0011) la escena no se
## recarga, así que no hay nada que deba sobrevivirle. Y un `class_name` se
## resuelve en compilación mientras que un autoload no (ADR-0009).
##
## Cada efecto tiene su propio `AudioStreamPlayer`. Compartir uno haría que
## un aleteo cortara el sonido del punto, que es justo cuando más se solapan.

## Volumen de cada efecto, en decibelios. Ajustable sin tocar los ficheros.
@export var flap_db: float = -6.0
@export var point_db: float = -3.0
@export var hit_db: float = 0.0
@export var fall_db: float = -6.0
@export var button_db: float = -8.0

@onready var _flap: AudioStreamPlayer = $Flap
@onready var _point: AudioStreamPlayer = $Point
@onready var _hit: AudioStreamPlayer = $Hit
@onready var _fall: AudioStreamPlayer = $Fall
@onready var _button: AudioStreamPlayer = $Button


func _ready() -> void:
	_flap.volume_db = flap_db
	_point.volume_db = point_db
	_hit.volume_db = hit_db
	_fall.volume_db = fall_db
	_button.volume_db = button_db
	# El silencio se lee del disco al arrancar: el criterio de T-061 es que
	# sobreviva a cerrar y abrir el juego.
	apply_muted(Settings.is_muted())


func play_flap() -> void:
	_flap.play()


func play_point() -> void:
	_point.play()


## El golpe y la caída van juntos: el batacazo del GDD es un sonido seco
## seguido del silbido de Flapo cayendo.
func play_hit() -> void:
	_hit.play()
	_fall.play()


func play_button() -> void:
	_button.play()


## Silencia o restaura el bus de efectos. No toca el volumen de cada
## reproductor: así al quitar el mute todo vuelve como estaba.
func apply_muted(muted: bool) -> void:
	for bus in ["SFX", "Music"]:
		var i: int = AudioServer.get_bus_index(bus)
		if i >= 0:
			AudioServer.set_bus_mute(i, muted)


## Alterna el silencio, lo guarda y lo aplica. Devuelve el valor nuevo.
func toggle_muted() -> bool:
	var nuevo: bool = not Settings.is_muted()
	Settings.set_muted(nuevo)
	apply_muted(nuevo)
	return nuevo


## Si el juego está silenciado ahora mismo.
func is_muted() -> bool:
	return Settings.is_muted()
