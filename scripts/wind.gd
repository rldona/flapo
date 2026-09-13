class_name Wind
extends Node
## Ráfagas de viento (T-064).
##
## Es **global y no por tubería**, como pedía el ticket: el viento le pasa al
## mundo entero, no a un obstáculo. Por eso vive colgado de `Main` y no del
## spawner.
##
## Ciclo: calma → aviso → soplando → calma. El aviso es obligatorio, no
## decorativo: una ráfaga sin anunciar es una encerrona, y el GDD dice que
## Flapo se ríe con el jugador, no de él.
##
## El reloj es propio y acumulado en `_physics_process`, no un `Timer`. Es la
## misma razón que en T-049 y T-063: así se para con la pausa y con el
## hit-stop, y no hay que acordarse de reiniciar nada. El ticket pedía "Timer
## global, no por tubería"; lo que importaba de esa frase —global— se cumple.
##
## No sabe la puntuación ni calcula velocidades: solo dice si sopla y en qué
## sentido. Quien convierte eso en px/s es Main, que es quien conoce la curva
## ("call down", ADR-0005). Ver ADR-0026.

## Va a soplar dentro de `WIND_WARNING_TIME` segundos.
signal warning_started(a_favor: bool)

## Empieza a soplar.
signal gust_started(a_favor: bool)

## Se acabó. El mundo vuelve solo a su velocidad.
signal gust_ended

enum Fase { CALMA, AVISO, SOPLANDO }

## Semilla. 0 = distinta en cada partida.
@export var random_seed: int = 0

## Si el viento está activo. Main lo apaga por debajo de WIND_MIN_SCORE.
##
## El setter NO reinicia: reiniciar consume números del generador de la
## partida (T-240), y hacerlo aquí metía un consumo extra que dependía de si
## el viento estaba encendido al morir. Dos partidas con la misma semilla
## dejaban de coincidir según cuánto hubieras puntuado en la anterior. Quien
## reinicia es `on_game_state_changed`, que ocurre siempre y una sola vez.
var enabled: bool = false

var _fase: Fase = Fase.CALMA
var _restante: float = 0.0
var _a_favor: bool = true
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	reset()


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	_restante -= delta
	if _restante > 0.0:
		return
	match _fase:
		Fase.CALMA:
			_a_favor = _rng.randf() < 0.5
			_entrar(Fase.AVISO, GameConfig.WIND_WARNING_TIME)
			warning_started.emit(_a_favor)
		Fase.AVISO:
			_entrar(Fase.SOPLANDO, GameConfig.WIND_DURATION)
			gust_started.emit(_a_favor)
		Fase.SOPLANDO:
			_entrar(Fase.CALMA, _calma())
			gust_ended.emit()


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
##
## Fuera de PLAYING no hay viento: en el menú o en el Game Over una ráfaga no
## significa nada, y dejarla correr descuadraría el aviso de la partida
## siguiente.
func on_game_state_changed(to: GameState.State) -> void:
	if to != GameState.State.PLAYING:
		enabled = false
		reset()


## Recibe el generador de la partida (T-240).
func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


## Vuelve a la calma y resortea el reloj. Main lo llama al empezar partida.
func reset() -> void:
	_fase = Fase.CALMA
	_restante = _calma()
	if random_seed != 0:
		_rng.seed = random_seed


## Si está soplando ahora mismo.
func is_blowing() -> bool:
	return _fase == Fase.SOPLANDO


## Si está avisando de que va a soplar.
func is_warning() -> bool:
	return _fase == Fase.AVISO


## Sentido de la ráfaga actual o anunciada.
func is_tailwind() -> bool:
	return _a_favor


## Segundos que le quedan a la fase actual. Lo usan el HUD y los tests.
func time_left() -> float:
	return maxf(_restante, 0.0)


## Salta a la siguiente fase ya. Solo para tests: esperar 12 segundos de
## calma real haría el test lento y dependiente del reloj.
func skip_to_next_phase() -> void:
	_restante = 0.0


func _entrar(fase: Fase, duracion: float) -> void:
	_fase = fase
	_restante = duracion


func _calma() -> float:
	return _rng.randf_range(GameConfig.WIND_CALM_MIN, GameConfig.WIND_CALM_MAX)
