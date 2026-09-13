class_name Journey
extends Node
## El final del viaje: Flapo llega al nido (T-209).
##
## A `JOURNEY_END_SCORE` puntos las tuberías paran, hay tres segundos de
## escena sin input y una línea, y **la partida continúa**. Le da un final
## alcanzable a un género que no lo tiene, sin quitarle el bucle infinito a
## quien quiera seguir.
##
## **No es un estado de la máquina** (ADR-0027). Es una pausa del generador de
## tuberías con un cartel encima, igual que las estadísticas son un panel
## encima del menú (T-084). Un quinto estado obligaría a cada pieza del juego
## a saber que existe una pantalla en la que casi todo sigue igual.

## Empieza la escena. Main para lo que haya que parar.
signal started

## Termina. La partida sigue exactamente donde estaba.
signal ended

var _restante: float = 0.0
var _activa: bool = false
## Si ya ha pasado en esta partida. Una vez y no más: el nido es un sitio al
## que se llega, no una parada de autobús.
var _usada: bool = false


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	match to:
		GameState.State.MENU, GameState.State.READY:
			_restante = 0.0
			_activa = false
			_usada = false
		GameState.State.GAME_OVER:
			# Morir cancela la escena. No debería poder pasar —durante la
			# escena no se muere— pero si algún día se puede, el cartel no se
			# queda encima del Game Over.
			if _activa:
				_activa = false
				_restante = 0.0
				ended.emit()


## Main le pasa la puntuación al puntuar. Devuelve `true` si ha arrancado.
##
## Exactamente en `JOURNEY_END_SCORE`, no "a partir de": con un `>=` la escena
## se dispararía en el punto 50 y en todos los siguientes.
func quiza_empezar(score: int) -> bool:
	if _usada or _activa or score != GameConfig.JOURNEY_END_SCORE:
		return false
	_usada = true
	_activa = true
	_restante = GameConfig.JOURNEY_SCENE_TIME
	started.emit()
	return true


func _physics_process(delta: float) -> void:
	if not _activa:
		return
	_restante -= delta
	if _restante <= 0.0:
		_activa = false
		_restante = 0.0
		ended.emit()


## Si la escena está corriendo. Lo usan Main y los tests.
func activa() -> bool:
	return _activa


## Si ya ha pasado en esta partida. Lo usan los tests.
func usada() -> bool:
	return _usada


## Cuánto le queda, s. Lo usan los tests.
func restante() -> float:
	return _restante
