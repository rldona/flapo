class_name Ghost
extends Node2D
## El fantasma del récord: tu mejor vuelo, volando otra vez (T-243).
##
## Hace las dos mitades de lo mismo: **graba** la `y` de Flapo mientras se
## juega y **reproduce** la grabada si la semilla de esta partida es la de
## aquella. Están juntas porque comparten el contador de frames, que es lo
## único que alinea un vuelo con otro; separarlas obligaría a sincronizar dos
## relojes que siempre son el mismo.
##
## **No colisiona porque no puede**, no porque lleve un flag apagado: es un
## `Node2D` con un `AnimatedSprite2D` dentro y ni una sola `CollisionShape2D`
## en toda la escena. Un `Bird` con la máscara a 0 habría sido un flag que
## alguien puede volver a encender por accidente dentro de tres tickets; esto
## no tiene interruptor que encender. Tampoco pide un solo número al
## generador de la partida, así que jugar con fantasma y sin él da
## exactamente las mismas tuberías (ADR-0030).

## Flapo, para saber qué `y` grabar. Se asigna en el inspector.
@export var bird: Bird

## El vuelo cargado del disco, o `null` si no hay ninguno que valga.
var _registro: GhostRecord = null
## El vuelo que se está grabando ahora.
var _grabando := PackedFloat32Array()
## Frame de física desde el primero de `PLAYING`. Es el mismo para grabar y
## para reproducir: por eso los dos vuelos quedan alineados.
var _frame: int = 0
var _semilla: int = 0
var _reproduciendo: bool = false
var _activo: bool = false

@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	_sprite.modulate = GameConfig.GHOST_TINT
	_sprite.modulate.a = GameConfig.GHOST_ALPHA
	visible = false
	# Se lee una vez al arrancar. Si el fichero no está o no vale, `cargar`
	# devuelve `null` y aquí no pasa absolutamente nada más.
	_registro = GhostRecord.cargar()


## Main dice con qué semilla se va a jugar, ya sorteada (T-240).
##
## Se llama en READY, después de sembrar: antes, la semilla de una partida
## libre todavía es 0 y el fantasma no podría saber si le toca salir.
func preparar(semilla: int) -> void:
	_semilla = semilla


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	match to:
		GameState.State.MENU, GameState.State.READY:
			_frame = 0
			_grabando = PackedFloat32Array()
			_activo = false
			_reproduciendo = false
			visible = false
		GameState.State.PLAYING:
			_frame = 0
			_activo = true
			# Solo sale si el vuelo grabado es de ESTAS tuberías. Con otra
			# semilla el fantasma volaría por un hueco que hoy no existe.
			_reproduciendo = _registro != null and _registro.semilla == _semilla
			visible = _reproduciendo
			if _reproduciendo and bird != null:
				position.x = bird.position.x
				position.y = _registro.y_en(0)
		GameState.State.GAME_OVER:
			_activo = false
			# Se queda donde estaba: el fantasma no se muere, simplemente
			# deja de volar. Que siga en pantalla enseña dónde llegó.


func _physics_process(_delta: float) -> void:
	if not _activo:
		return
	if bird != null and _grabando.size() < GameConfig.GHOST_MAX_FRAMES:
		_grabando.append(bird.position.y)
	if _reproduciendo:
		position.y = _registro.y_en(_frame)
	_frame += 1


## Main llama a esto al morir. Graba el vuelo si esta partida ha sido récord.
##
## El criterio es el récord y no "el mejor de esta semilla": si el jugador
## bate su marca, ese es el vuelo que quiere volver a ver, y guardar dos
## fantasmas por criterios distintos sería dos cosas que explicar.
func terminar(score: int, es_record: bool) -> void:
	if not es_record or _grabando.is_empty():
		return
	var rec := GhostRecord.new()
	rec.semilla = _semilla
	rec.score = score
	rec.posiciones = _grabando
	if rec.guardar():
		_registro = rec


## Si el fantasma está volando ahora mismo. Lo usan los tests.
func esta_reproduciendo() -> bool:
	return _reproduciendo


## Cuántos frames lleva reproducidos. Lo usan los tests para comparar sin
## adivinar el desfase: el frame que enseña el fantasma es este menos uno.
func frames_reproducidos() -> int:
	return _frame


## El vuelo cargado, o `null`. Lo usan los tests.
func registro() -> GhostRecord:
	return _registro


## Lo que se lleva grabado de esta partida. Lo usan los tests.
func grabado() -> PackedFloat32Array:
	return _grabando
