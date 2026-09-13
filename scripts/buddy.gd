class_name Buddy
extends Node2D
## El compañero silencioso: un pájaro que va contigo y no hace nada (T-058).
##
## No se controla, no puntúa, no colisiona y **no cambia una sola cosa de la
## partida**. Está para que Flapo no vuele solo, y para que el mundo reaccione
## a lo que haces sin tener que decírtelo con texto.
##
## **No colisiona porque no puede**, igual que el fantasma (T-243): es un
## `Node2D` con un `AnimatedSprite2D` dentro y ni una `CollisionShape2D` en
## toda la escena. Un `CharacterBody2D` con la máscara a 0 sería un
## interruptor que alguien puede volver a encender sin querer.
##
## Y **no le pide un solo número al generador**: su vuelo es función
## determinista de dónde está Flapo. Si sorteara algo —un aleteo al azar, un
## desvío— movería la secuencia de tuberías y dos partidas con la misma
## semilla dejarían de ser la misma (ADR-0030).
##
## Va **detrás y arriba** de Flapo. Entre Flapo y el hueco que hay que cruzar
## no puede haber nada que mirar; es el criterio del ticket y manda sobre
## cualquier cosa mona que se pudiera hacer con él.

## Qué está haciendo. `NADA` es volar y ya.
enum Reaccion { NADA, SUSTO, APLAUSO }

## Flapo, para saber a quién seguir. Se asigna en el inspector.
@export var bird: Bird

var _reaccion: Reaccion = Reaccion.NADA
var _restante: float = 0.0
var _tiempo: float = 0.0
var _activo: bool = false

@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	_sprite.modulate = GameConfig.BUDDY_TINT
	scale = Vector2.ONE * GameConfig.BUDDY_SCALE
	visible = false


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	_reaccion = Reaccion.NADA
	_restante = 0.0
	_tiempo = 0.0
	match to:
		GameState.State.MENU:
			_activo = false
			visible = false
		GameState.State.READY, GameState.State.PLAYING:
			_activo = true
			visible = true
			if bird != null:
				position = bird.position + GameConfig.BUDDY_OFFSET
		GameState.State.GAME_OVER:
			# Se queda quieto donde iba. Que siga revoloteando mientras Flapo
			# está espachurrado en el suelo sería el peor chiste del juego.
			_activo = false


func _physics_process(delta: float) -> void:
	if not _activo or bird == null:
		return
	_tiempo += delta
	if _restante > 0.0:
		_restante = maxf(_restante - delta, 0.0)
		if _restante <= 0.0:
			_reaccion = Reaccion.NADA
	position = position.lerp(_destino(), _peso(delta))
	_animar()


## Dónde quiere estar este frame: al lado de Flapo, más lo que le haga la
## reacción de turno.
func _destino() -> Vector2:
	var destino: Vector2 = bird.position + GameConfig.BUDDY_OFFSET
	destino.y += sin(_tiempo * TAU / GameConfig.BUDDY_BOB_PERIOD) * GameConfig.BUDDY_BOB
	match _reaccion:
		Reaccion.SUSTO:
			# Se aparta hacia arriba y hacia atrás: el susto se lee como
			# "quítate", no como "mírame".
			destino += Vector2(-GameConfig.BUDDY_SCARE_JUMP, -GameConfig.BUDDY_SCARE_JUMP)
		Reaccion.APLAUSO:
			# Rebota. Sin sprite de aplauso, el bote es lo que se entiende.
			destino.y -= absf(sin(_tiempo * TAU * 3.0)) * GameConfig.BUDDY_CLAP_BOUNCE
	return destino


## Cuánto se acerca a su destino este frame.
##
## `1 - exp(-dt/lag)` en vez de un `lerp` con factor fijo: así el seguimiento
## no depende de los fps. Con factor fijo, el compañero iría más pegado o más
## suelto según lo que rindiera el móvil.
func _peso(delta: float) -> float:
	if GameConfig.BUDDY_LAG <= 0.0:
		return 1.0
	return 1.0 - exp(-delta / GameConfig.BUDDY_LAG)


func _animar() -> void:
	_sprite.speed_scale = 2.0 if _reaccion != Reaccion.NADA else 1.0


## Se ha pasado rozando el borde de un hueco (T-058).
func asustarse() -> void:
	if not _activo:
		return
	_reaccion = Reaccion.SUSTO
	_restante = GameConfig.BUDDY_SCARE_TIME


## Medalla nueva: toca celebrar.
func aplaudir() -> void:
	if not _activo:
		return
	_reaccion = Reaccion.APLAUSO
	_restante = GameConfig.BUDDY_CLAP_TIME


## Qué está haciendo ahora mismo. Lo usan los tests.
func reaccion() -> Reaccion:
	return _reaccion
