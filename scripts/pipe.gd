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

## Flapo ha cruzado por la franja central del hueco (T-048). Va aparte de
## `scored` porque son dos cosas distintas: puntuar es pasar, esto es pasar
## bien.
signal centered

@export_group("Hueco")
## Alto del hueco, px. Es la constante que más cambia la dificultad.
@export var gap: float = GameConfig.PIPE_GAP:
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
## Velocidad a la que se desplaza, px/s. La fija PipeSpawner al crearla, según
## la curva de dificultad (ADR-0018). El valor por defecto es el de inicio,
## para que la escena se pueda probar suelta con F6.
@export var scroll_speed: float = GameConfig.SCROLL_SPEED

## Si está en marcha. `PipeSpawner` lo pone a false en GAME_OVER (T-025).
@export var moving: bool = true

@export_group("Blandita (T-066)")
## Si esta tubería no mata (T-066). Se tiñe al ponerla, para que se distinga
## desde que entra en pantalla y no solo al chocar.
@export var soft: bool = false:
	set(valor):
		soft = valor
		_aplicar_tinte()

@export_group("Tramo especial (T-067)")
## Si esta tubería es del tramo de celebración (T-067). Se tiñe al ponerla,
## igual que la blandita: el tramo tiene que verse llegar, no descubrirse al
## chocar.
@export var special: bool = false:
	set(valor):
		special = valor
		_aplicar_tinte()

@export_group("Giratoria (T-065)")
## Si las bocas de esta tubería giran (T-065).
##
## El giro es **solo del dibujo**: gira cada `Cap` sobre su propio centro,
## nunca el `StaticBody2D` que lo contiene. Girar el cuerpo giraría también
## su `CollisionShape2D` y el hueco real dejaría de coincidir con el que se
## ve, que es exactamente lo que el ticket dice que no puede pasar.
##
## Y se giran las bocas y no el cuerpo del tubo porque el cuerpo es un
## rectángulo repetido de 512 px: girarlo se vería roto, no giratorio.
@export var spin: bool = false

@export_group("Oscilación (T-063)")
## Amplitud vertical, px (la mitad del recorrido). 0 = tubería normal, quieta.
##
## La calcula `GameConfig.moving_pipe_amplitude()` a partir del hueco y su
## altura, así que el hueco COMPLETO cabe siempre en la zona jugable. Ver
## ADR-0023.
@export var oscillation_amplitude: float = 0.0:
	set(valor):
		oscillation_amplitude = maxf(valor, 0.0)
## Segundos de una oscilación completa.
@export var oscillation_period: float = GameConfig.MOVING_PIPE_PERIOD
## Desfase inicial, rad. Se siembra por tubería para que no oscilen todas a la
## vez, que se leería como un temblor de la pantalla y no como tuberías.
@export var oscillation_phase: float = 0.0

var _gap_center: float = 256.0
## Altura alrededor de la cual oscila. `_gap_center` es dónde está ahora;
## esto es dónde debería estar en reposo.
var _base_gap_center: float = 256.0
## Reloj propio de la oscilación. Se acumula en `_physics_process` y no se
## lee de `Time`: así se para con la pausa y con el hit-stop, igual que la
## ventana de fatiga de T-049.
var _osc_tiempo: float = 0.0
## Reloj propio del giro (T-065), por lo mismo que el de la oscilación.
var _spin_tiempo: float = 0.0
var _ya_puntuada: bool = false

@onready var _top: StaticBody2D = $Top
@onready var _bottom: StaticBody2D = $Bottom
@onready var _score_zone: Area2D = $ScoreZone
@onready var _band: ColorRect = $Band


func _ready() -> void:
	_band.color = GameConfig.BREATH_BAND_TINT
	_aplicar_tinte()
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
	position.x -= scroll_speed * delta
	_oscilar(delta)
	_girar(delta)
	# Se libera cuando su borde derecho ha pasado el borde izquierdo de la
	# pantalla. Sin esto, cada partida acumularía tuberías invisibles para
	# siempre: el criterio de nodos huérfanos de T-024 es exactamente esto.
	if position.x + width * 0.5 < 0.0:
		queue_free()


## Coloca el centro del hueco a una altura concreta, px.
##
## Fija también la altura de reposo: quien llama está diciendo dónde va esta
## tubería, y la oscilación es un vaivén alrededor de ahí.
func set_gap_center(y: float) -> void:
	_gap_center = y
	_base_gap_center = y
	_apply_layout()


## Tiñe los dos tubos si es blandita, y los deja como estaban si no.
##
## El tinte va en los `Sprite2D`, no en la raíz: `modulate` en el `Node2D`
## también teñiría la zona de puntuación si algún día tuviera dibujo, y lo
## que tiene que verse distinto es el tubo.
func _aplicar_tinte() -> void:
	# El orden importa: una tubería del tramo especial que además sea blandita
	# se pinta de blandita. Lo que el jugador necesita saber en ese momento no
	# es que está en un tramo bonito, es que esa no le mata.
	var color: Color = Color.WHITE
	if special:
		color = GameConfig.SPECIAL_PIPE_TINT
	if soft:
		color = GameConfig.SOFT_PIPE_TINT
	for cuerpo in [_top, _bottom]:
		if cuerpo == null:
			continue
		for nombre in ["Body", "Cap"]:
			var sprite := (cuerpo as Node).get_node_or_null(nombre) as Sprite2D
			if sprite != null:
				sprite.modulate = color


## El color con el que se está dibujando. Lo usan los tests: comprobar que
## "se distingue" mirando el dibujo y no una bandera.
func tint() -> Color:
	var sprite := _top.get_node_or_null("Body") as Sprite2D if _top != null else null
	return sprite.modulate if sprite != null else Color.WHITE


## Gira las bocas, y solo las bocas (T-065).
func _girar(delta: float) -> void:
	if not spin:
		return
	_spin_tiempo += delta
	var angulo: float = _spin_tiempo * GameConfig.SPIN_PIPE_TURNS_PER_SECOND * TAU
	for cuerpo in [_top, _bottom]:
		if cuerpo == null:
			continue
		var cap := (cuerpo as Node).get_node_or_null("Cap") as Sprite2D
		if cap != null:
			cap.rotation = angulo


## Alto real del brillo de la franja, px. Lo usan los tests.
func band_height() -> float:
	return _band.size.y if _band != null else 0.0


## Centro del brillo en coordenadas locales, px. Lo usan los tests.
func band_center() -> float:
	return _band.position.y + _band.size.y * 0.5 if _band != null else 0.0


## Ángulo actual de las bocas, rad. Lo usan los tests.
func spin_angle() -> float:
	if _top == null:
		return 0.0
	var cap := _top.get_node_or_null("Cap") as Sprite2D
	return cap.rotation if cap != null else 0.0


## Si esta tubería oscila. Lo usan los tests y T-067.
func is_oscillating() -> bool:
	return oscillation_amplitude > 0.0


## Altura de reposo del hueco, px.
func get_base_gap_center() -> float:
	return _base_gap_center


## Mueve el hueco arriba y abajo (T-063).
##
## Los tubos son `StaticBody2D` y se mueven cambiando su `position`, sin
## `constant_linear_velocity`. No hace falta: para Flapo, cualquier contacto
## con una tubería es la muerte (`get_slide_collision_count() > 0`), así que
## no existe el roce en el que un cuerpo estático móvil arrastraría a otro.
## Ver ADR-0023.
func _oscilar(delta: float) -> void:
	if oscillation_amplitude <= 0.0 or oscillation_period <= 0.0:
		return
	_osc_tiempo += delta
	var angulo: float = oscillation_phase + _osc_tiempo * TAU / oscillation_period
	_gap_center = _base_gap_center + sin(angulo) * oscillation_amplitude
	_recolocar()


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
	# Solo la mitad central del hueco recupera aliento. Si valiera pasar por
	# cualquier sitio, recuperar sería automático y el recurso no existiría.
	var margen: float = GameConfig.breath_band_half(gap)
	if absf(cuerpo.global_position.y - global_position.y - _gap_center) <= margen:
		centered.emit()


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
	_vestir(_top, false)
	_vestir(_bottom, true)
	var forma := (_score_zone.get_node("CollisionShape2D") as CollisionShape2D).shape
	if forma is RectangleShape2D:
		(forma as RectangleShape2D).size = Vector2(width, gap)
	_recolocar()


## Solo lo que depende de la altura del hueco.
##
## Va aparte de `_apply_layout` porque una tubería que oscila lo llama en
## cada frame de física: repetir ahí el vestido de los sprites (regiones,
## cabezas) sería trabajo tirado 60 veces por segundo.
func _recolocar() -> void:
	if _top == null or _bottom == null:
		return
	var media_luz: float = gap * 0.5
	# Cada tubo se centra en su propio punto medio, de ahí el medio largo.
	_top.position.y = _gap_center - media_luz - body_length * 0.5
	_bottom.position.y = _gap_center + media_luz + body_length * 0.5
	# La zona de puntuación ES el hueco: mismo centro, mismo alto.
	_score_zone.position.y = _gap_center
	# Y el brillo ES la franja que recupera aliento, con el mismo cálculo que
	# la usa de verdad: no hay dos números que puedan desincronizarse (T-202).
	if _band != null:
		var alto: float = GameConfig.breath_band_half(gap) * 2.0
		_band.size = Vector2(width, alto)
		_band.position = Vector2(-width * 0.5, _gap_center - alto * 0.5)


## Estira el cuerpo del tubo y coloca la cabeza en su boca.
##
## El cuerpo es un `Sprite2D` con `region_enabled` y `texture_repeat`: la
## región es más alta que la textura, así que el motor la repite en vez de
## estirarla. Es lo que cumple el criterio de T-051 (se estira a cualquier
## altura sin deformar la cabeza), y sale más barato que un NinePatchRect.
func _vestir(cuerpo: StaticBody2D, hacia_abajo: bool) -> void:
	var body := cuerpo.get_node_or_null("Body") as Sprite2D
	var cap := cuerpo.get_node_or_null("Cap") as Sprite2D
	if body == null or cap == null:
		return
	body.region_rect = Rect2(0.0, 0.0, width, body_length)
	body.position = Vector2.ZERO
	var media: float = body_length * 0.5
	var alto_cabeza: float = cap.texture.get_height()
	# La cabeza va en el extremo que mira al hueco, y del revés en el tubo de
	# arriba para que la boca apunte hacia abajo.
	if hacia_abajo:
		cap.position = Vector2(0.0, -media + alto_cabeza * 0.5)
		cap.flip_v = false
	else:
		cap.position = Vector2(0.0, media - alto_cabeza * 0.5)
		cap.flip_v = true
