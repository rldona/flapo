class_name GameConfig
extends RefCounted
## Constantes de juego compartidas entre varias escenas.
##
## No es un autoload: es un contenedor de constantes que no se instancia
## nunca. Un autoload solo se registra al arrancar el juego, así que
## `--check-only` y los scripts lanzados con `-s` no lo ven (ADR-0009).
## Como aquí no hay estado, no hace falta que sea un nodo.
##
## Aquí vive lo que más de un sistema necesita saber:
## si la velocidad de scroll estuviera duplicada en Pipe, Ground y Parallax,
## tunearla significaría tocar tres sitios y olvidarse de uno.
##
## Regla del proyecto: lo compartido vive aquí; lo que se tunea a ojo en un
## nodo concreto se expone con `@export` en ese nodo. Los valores de esta
## tabla salen de docs/GDD.md y se cierran en T-040.

## Medallas. Con nombre de comida, como pide el GDD ("Concepto y tono"):
## croqueta de bronce, tortilla de plata, jamón de oro.
## Los tres modos que se eligen en el menú. NORMAL es el juego tal y como se
## diseñó: los otros dos son ese mismo juego escalado, no tablas aparte.
enum Difficulty {
	FACIL,
	NORMAL,
	DIFICIL,
}

## Cómo de ahogado está Flapo (T-201).
enum Pant {
	NINGUNO,  ## Respira bien: nada que enseñar.
	JADEO,  ## Va justo: alas temblando, mejillas y sudor.
	AGOTADO,  ## A cero: además, vaho.
}

enum Medal { NINGUNA, CROQUETA, TORTILLA, JAMON }

# --- Pantalla -----------------------------------------------------------
## Tamaño lógico del viewport, en píxeles. Coincide con
## display/window/size/viewport_{width,height} de project.godot.
const VIEWPORT_SIZE := Vector2i(288, 512)

# La física de Flapo (gravedad, impulso, techo) no está aquí: vive como
# `@export` en `scripts/bird.gd` porque es lo que se tunea a ojo en T-040.
# Ver ADR-0003.

## Alto del suelo, px. Se lo restan las tuberías para saber por dónde pueden
## sortear su hueco, y lo usa Ground para su propia colisión.
const GROUND_HEIGHT: float = 64.0

# --- Mundo --------------------------------------------------------------
## Velocidad a la que el mundo se desplaza hacia la izquierda, px/s.
## La usan tuberías, suelo y parallax.
const SCROLL_SPEED: float = 100.0
## Distancia horizontal entre dos pares de tuberías consecutivos, px.
const PIPE_SPACING: float = 160.0

# --- Curva de dificultad (T-045) ----------------------------------------
## Puntuación a la que la dificultad llega a su tope. A partir de ahí el juego
## no sube más: lo que queda es aguantar.
const DIFFICULTY_CAP: int = 30
## Velocidad de scroll en el tope, px/s.
const SCROLL_SPEED_MAX: float = 145.0
## Hueco en el tope, px. Sigue siendo cinco veces la hitbox de Flapo.
const PIPE_GAP_MIN: float = 82.0
## Separación en el tope, px. Sube un poco a propósito: ver ADR-0018.
const PIPE_SPACING_MAX: float = 172.0
## Segundos que dura un aleteo completo, medido con tools/medir_feel.gd.
const FLAP_CYCLE: float = 0.35
## Alto del hueco al empezar la partida, px. Es la base de la curva de
## dificultad; el rango vertical del hueco sigue siendo `@export` de Pipe.
##
## Arranca por encima de los 100 px "de género" a propósito: los primeros
## diez segundos de alguien que no ha jugado nunca son los que deciden si
## sigue. Se estrecha hasta PIPE_GAP_MIN con la puntuación (ADR-0018).
const PIPE_GAP: float = 118.0

# --- Aliento (T-048) ----------------------------------------------------
## Aliento máximo. La escala es arbitraria —lo que importa son las
## proporciones entre gasto y recuperación—, pero 100 se lee como porcentaje
## y hace las cuentas evidentes al tunear.
const MAX_BREATH: float = 100.0

## Lo que cuesta un aleteo. A un ritmo normal de ~2,5 aleteos por segundo son
## 25 de gasto por segundo, algo por encima de lo que se recupera cruzando
## huecos: machacar el botón se paga.
const BREATH_DRAIN_FLAP: float = 10.0

## Lo que cuesta planear, por segundo. Menos que aletear sostenido, que es lo
## que hace del planeo la opción "barata" y le da sentido al recurso.
const BREATH_DRAIN_GLIDE: float = 15.0

## Lo que se recupera al cruzar el hueco **por el centro**. Con un hueco cada
## 1,6 s son ~15,6 por segundo: sostiene el planeo continuo, pero no el
## aleteo continuo. Volar bien se premia; martillear, no.
const BREATH_RECOVER_ON_GAP: float = 25.0

## Qué fracción central del hueco cuenta como "por el centro". Solo la mitad
## central: si valiera todo el hueco, recuperar sería automático y el recurso
## dejaría de existir.
const BREATH_BAND_RATIO: float = 0.5

# --- Modos de dificultad (T-078) ----------------------------------------
## Multiplicador del hueco. Es la palanca que más se nota: el margen de paso
## va de 51 px por lado en fácil a 28 en difícil (hitbox de radio 8).
const DIFFICULTY_GAP_MULT: Array[float] = [1.18, 1.0, 0.88]

## Multiplicador de la velocidad del mundo. Cambia el tiempo de reacción
## desde que la tubería entra en pantalla: 2,5 s en fácil, 1,9 s en difícil.
const DIFFICULTY_SPEED_MULT: Array[float] = [0.85, 1.0, 1.15]

# --- Tuberías móviles (T-063) -------------------------------------------
## A partir de qué puntuación puede salir un par oscilante. Coincide con el
## final de la rampa de entrada del GDD: los primeros quince puntos son para
## aprender a volar, y meter aquí una tubería que se mueve rompería eso.
const MOVING_PIPE_MIN_SCORE: int = 15

## Probabilidad de par móvil al llegar al mínimo y en el tope de la curva.
## Nunca llega a 1: un tramo entero de tuberías móviles deja de ser una
## variante y pasa a ser otro juego.
const MOVING_PIPE_CHANCE_MIN: float = 0.15
const MOVING_PIPE_CHANCE_MAX: float = 0.45

## Amplitud máxima de la oscilación, px (la mitad del recorrido total). Se
## recorta por tubería si el hueco se saldría de la zona jugable.
const MOVING_PIPE_AMPLITUDE: float = 22.0

## Segundos que tarda en dar una oscilación completa. 2,4 s con 22 px de
## amplitud son 58 px/s de punta, un 15 % de lo que da un aleteo (380 px/s):
## Flapo siempre puede más que la tubería, que es lo que la hace justa.
const MOVING_PIPE_PERIOD: float = 2.4

# --- Ráfagas de viento (T-064) ------------------------------------------
## Segundos de aviso antes de que empiece a soplar. Es la constante que
## decide si el viento es un reto o una encerrona: a 2 s caben casi 6
## aleteos, tiempo de sobra para recolocarse.
const WIND_WARNING_TIME: float = 2.0

## Cuánto sopla una ráfaga, s. Corta a propósito: el viento es un tramo, no
## un estado del juego.
const WIND_DURATION: float = 5.0

## Calma entre ráfagas, s. Al azar dentro del rango para que no se pueda
## contar el compás, pero nunca seguidas.
const WIND_CALM_MIN: float = 12.0
const WIND_CALM_MAX: float = 22.0

## Cuánto multiplica la velocidad del mundo, a favor y en contra.
const WIND_FACTOR_TAIL: float = 1.25
const WIND_FACTOR_HEAD: float = 0.80

## Puntuación a partir de la cual puede soplar. Como con las tuberías
## móviles: la rampa de entrada se deja limpia.
const WIND_MIN_SCORE: int = 10

# --- Layout adaptativo (T-085) ------------------------------------------
## Escala mínima. Por debajo de 1 el pixel art se destruiría: antes que
## encoger el playfield se prefiere que se salga y la ventana lo recorte.
const MIN_WINDOW_SCALE: int = 1

## Escala máxima. Existe para que en un monitor 4K el juego no ocupe la
## pantalla entera a 7x, que se ve absurdo en un juego de 288 px de ancho.
const MAX_WINDOW_SCALE: int = 6

# --- Tubería giratoria (T-065) ------------------------------------------
## A partir de qué puntuación puede salir una giratoria. Como el resto de
## variantes: la rampa de entrada se deja limpia.
const SPIN_PIPE_MIN_SCORE: int = 12

## Probabilidad de que un par gire, al llegar al mínimo y en el tope.
const SPIN_PIPE_CHANCE_MIN: float = 0.12
const SPIN_PIPE_CHANCE_MAX: float = 0.35

## Vueltas por segundo de las bocas. Despacio: girar rápido lee como un
## error de dibujo, no como una tubería que gira.
const SPIN_PIPE_TURNS_PER_SECOND: float = 0.35

# --- Tubería blandita (T-066) -------------------------------------------
## Cada cuántas tuberías sale una blandita. NO es aleatorio a propósito: al
## ser predecible se puede contar y buscarla, y eso la convierte en una
## decisión ("me la juego en la séptima") en vez de en un golpe de suerte.
const SOFT_PIPE_INTERVAL: int = 7

## Lo que cuesta tocarla. Aliento y un punto, nunca la partida: el GDD dice
## que Flapo se ríe con el jugador, no de él, y perder 40 puntos por rozar
## sería exactamente lo contrario.
const SOFT_PIPE_BREATH_COST: float = 35.0
const SOFT_PIPE_SCORE_COST: int = 1

## Segundos de gracia entre dos cobros. Sin esto, quedarse apoyado contra
## ella cobraría 60 veces por segundo.
const SOFT_PIPE_COOLDOWN: float = 0.8

## Con qué fuerza sale despedido, px/s. Va en la dirección de la normal del
## contacto, así que rebota hacia afuera de la tubería que ha tocado.
const SOFT_PIPE_BOUNCE_SPEED: float = 260.0

## Tinte de la blandita. Un verde apagado que no usa ni el escenario ni las
## frutas: tiene que leerse como "esta es distinta" en cuanto entra, no al
## chocar. Ver docs/art-guide.md.
const SOFT_PIPE_TINT: Color = Color("#7FA37B")

# --- Nombre de jugador (T-079) ------------------------------------------
## Cuántos caracteres caben. Corto a propósito: el nombre va en el texto de
## compartir y en el menú, a 288 px de ancho, y un nombre largo desborda las
## dos cosas.
const PLAYER_NAME_MAX_LEN: int = 12

## El que se usa cuando no hay nombre. No se pide nunca: jugar sin poner
## nombre tiene que ser posible, y este es el nombre de quien no lo pone.
const PLAYER_NAME_DEFAULT: String = "Flapo"

# --- Confianza (T-074) --------------------------------------------------
## Partidas jugadas por cada escalón de confianza. Se cuentan PARTIDAS, no
## puntos: mejora quien insiste, no quien ya juega bien. Es lo que hace la
## progresión narrativa en vez de competitiva ("va cogiendo el truco").
const CONFIDENCE_STEP: int = 10

## Tope de escalones. La progresión termina: un juego que mejora sin límite
## acaba jugándose solo, y a las 50 partidas Flapo ya ha cogido el truco.
const CONFIDENCE_MAX_LEVEL: int = 5

## Aliento extra por escalón. Pequeño a propósito: 8 sobre 100 no se nota en
## una partida, pero la barra es visiblemente más larga a las 50.
const CONFIDENCE_BREATH_BONUS: float = 8.0

# --- Bocanada (T-202) ---------------------------------------------------
## Color del brillo que marca la franja que recupera aliento. El mismo crema
## de la tripa de Flapo (docs/art-guide.md), muy transparente: tiene que
## leerse como aire, no como una fruta ni como el tramo especial de T-067.
const BREATH_BAND_TINT: Color = Color(0.949, 0.851, 0.655, 0.16)

# --- Jadeo visible (T-201) ----------------------------------------------
## Por debajo de esta fracción del aliento, Flapo jadea: alas temblando,
## mejillas rojas y sudor. 0,3 y no 0,5 porque el jadeo tiene que significar
## "voy justo", no "he gastado un poco".
const BREATH_LOW_RATIO: float = 0.30

## Cuánto se acelera el aleteo al jadear. Temblor, no prisa: x1,6 se lee como
## esfuerzo; más se leería como que Flapo vuela mejor cansado.
const PANT_FLAP_FPS_MULT: float = 1.6

## Color al que tira Flapo con las mejillas encendidas. Es el mismo
## `#D98972` de las mejillas de la paleta (docs/art-guide.md), aplicado como
## modulación: no hay sprites nuevos.
const PANT_TINT: Color = Color("#F2B3A0")

## Cuánto se mezcla ese color como mucho, con el aliento a 0. Bajo a
## propósito: teñir del todo a Flapo lo haría irreconocible, y la silueta es
## lo que lo identifica (docs/art-guide.md).
const PANT_TINT_MAX: float = 0.55

# --- Fatiga (T-049) -----------------------------------------------------
## Cuántos aleteos caben en la ventana antes de que empiece a notarse. A los
## 3,4 aleteos por hueco que da la curva de dificultad en su tope (ADR-0018),
## jugar bien nunca llega aquí: solo llega quien machaca el botón.
const FATIGUE_FLAP_COUNT: int = 4

## Ventana que se mira hacia atrás, s.
const FATIGUE_WINDOW: float = 1.2

## Cuánto se reduce el impulso del aleteo estando fatigado, en tanto por uno.
## 0,3 se nota sin quitar el control: Flapo sube menos, no deja de subir.
const FATIGUE_PENALTY: float = 0.3

# --- Puntuación ---------------------------------------------------------
const MEDAL_BRONZE: int = 10
const MEDAL_SILVER: int = 20
const MEDAL_GOLD: int = 40


## Cuánto de dificultad se ha desbloqueado, de 0 a 1.
##
## Todas las magnitudes de la curva son funciones puras de la puntuación: no
## hay estado de dificultad que reiniciar, y con puntuación 0 salen exactamente
## los valores del GDD. Ver ADR-0018.
static func difficulty(score: int) -> float:
	return clampf(float(score) / float(DIFFICULTY_CAP), 0.0, 1.0)


## Cuánto escala el hueco en cada modo (T-078).
static func gap_mult(modo: Difficulty) -> float:
	return DIFFICULTY_GAP_MULT[clampi(int(modo), 0, DIFFICULTY_GAP_MULT.size() - 1)]


## Cuánto escala la velocidad del mundo en cada modo (T-078).
static func speed_mult(modo: Difficulty) -> float:
	return DIFFICULTY_SPEED_MULT[clampi(int(modo), 0, DIFFICULTY_SPEED_MULT.size() - 1)]


## Velocidad de scroll para una puntuación, px/s.
static func scroll_speed_for(score: int, modo: Difficulty = Difficulty.NORMAL) -> float:
	return lerpf(SCROLL_SPEED, SCROLL_SPEED_MAX, difficulty(score)) * speed_mult(modo)


## Alto del hueco para una puntuación, px.
static func pipe_gap_for(score: int, modo: Difficulty = Difficulty.NORMAL) -> float:
	return lerpf(PIPE_GAP, PIPE_GAP_MIN, difficulty(score)) * gap_mult(modo)


## Separación entre tuberías para una puntuación, px.
##
## Escala con la MISMA proporción que la velocidad, y eso no es casualidad:
## así el tiempo entre dos tuberías —y por tanto los aleteos que caben— es
## idéntico en los tres modos. La dificultad cambia el margen y el tiempo de
## reacción, nunca el invariante de ADR-0018 de no bajar de 3 aleteos.
static func pipe_spacing_for(score: int, modo: Difficulty = Difficulty.NORMAL) -> float:
	return lerpf(PIPE_SPACING, PIPE_SPACING_MAX, difficulty(score)) * speed_mult(modo)


## Segundos entre spawns para una puntuación.
static func pipe_spawn_interval_for(score: int, modo: Difficulty = Difficulty.NORMAL) -> float:
	return pipe_spacing_for(score, modo) / scroll_speed_for(score, modo)


## Cuántos aleteos caben entre dos tuberías a esa puntuación.
##
## Es el número que decide si la curva es difícil o injusta: por debajo de 3
## no da tiempo a corregir. Ver docs/GDD.md.
static func flaps_between_pipes(score: int, modo: Difficulty = Difficulty.NORMAL) -> float:
	return pipe_spawn_interval_for(score, modo) / FLAP_CYCLE


## Deja un nombre en condiciones (T-079).
##
## Se quita todo lo que rompa el texto de compartir o la línea del menú:
## saltos de línea, tabuladores y controles. Los espacios de los extremos se
## recortan y los de dentro se colapsan, porque "a         b" desborda igual
## que un nombre largo. Vacío devuelve vacío, y quien llame decide: no es
## trabajo de esta función inventar un nombre por defecto.
static func sanitize_player_name(texto: String) -> String:
	var limpio: String = ""
	for c in texto:
		# Todo lo que no se ve pero ocupa: \n, \t, \r y demás controles.
		if c.unicode_at(0) < 32 or c.unicode_at(0) == 127:
			limpio += " "
		else:
			limpio += c
	while limpio.contains("  "):
		limpio = limpio.replace("  ", " ")
	limpio = limpio.strip_edges()
	if limpio.length() > PLAYER_NAME_MAX_LEN:
		limpio = limpio.substr(0, PLAYER_NAME_MAX_LEN).strip_edges()
	return limpio


## El nombre a enseñar: el del jugador, o el de siempre si no puso ninguno.
static func display_player_name(texto: String) -> String:
	var limpio: String = sanitize_player_name(texto)
	return limpio if limpio != "" else PLAYER_NAME_DEFAULT


## Probabilidad de que un par de tuberías oscile, a esa puntuación (T-063).
##
## Función pura de la puntuación, como el resto de la curva (ADR-0018): al
## reiniciar vuelve sola a 0 sin código de reinicio. Por debajo del mínimo es
## exactamente 0, no "muy poco": la rampa de entrada tiene que ser limpia.
static func moving_pipe_chance(score: int) -> float:
	if score < MOVING_PIPE_MIN_SCORE:
		return 0.0
	var recorrido: int = maxi(DIFFICULTY_CAP - MOVING_PIPE_MIN_SCORE, 1)
	var t: float = clampf(float(score - MOVING_PIPE_MIN_SCORE) / float(recorrido), 0.0, 1.0)
	return lerpf(MOVING_PIPE_CHANCE_MIN, MOVING_PIPE_CHANCE_MAX, t)


## Media altura de la franja que recupera aliento, px (T-202).
##
## Existe para que **el dibujo y la regla salgan del mismo sitio**. Antes el
## número vivía dentro de `_on_score_zone_body_entered`; marcar la franja en
## pantalla con una segunda cuenta habría sido la forma más fácil de que el
## brillo dejara de coincidir con lo que de verdad recupera.
static func breath_band_half(gap: float) -> float:
	return gap * BREATH_BAND_RATIO * 0.5


## Cuánto puede oscilar un hueco de alto `gap` centrado en `centro` sin que se
## salga de la zona jugable (T-063).
##
## Es la garantía del ticket, y por eso se calcula aquí y no en la tubería:
## el hueco COMPLETO tiene que caber en pantalla en todo momento, no solo su
## centro. Si no cabe margen, devuelve 0 y el par sale quieto — nunca un
## hueco a medias fuera de pantalla.
static func moving_pipe_amplitude(gap: float, centro: float) -> float:
	var media_luz: float = gap * 0.5
	var margen_arriba: float = centro - media_luz
	var margen_abajo: float = playable_height() - centro - media_luz
	var margen: float = minf(margen_arriba, margen_abajo)
	return clampf(minf(MOVING_PIPE_AMPLITUDE, margen), 0.0, MOVING_PIPE_AMPLITUDE)


## Velocidad vertical de punta de un par móvil, px/s (T-063).
##
## Existe para poder compararla con el impulso de aleteo en un test: si algún
## día la oscilación se acelerara hasta acercarse a lo que Flapo puede subir,
## el movimiento pasaría de exigente a inevitable.
static func moving_pipe_peak_speed(amplitud: float) -> float:
	return amplitud * TAU / MOVING_PIPE_PERIOD


## Si a la tubería número `indice` (0 la primera de la partida) le toca ser
## blandita (T-066).
##
## Función pura del índice, como el resto de la curva: reiniciar la partida
## reinicia la cuenta sin código de reinicio. La primera nunca lo es —salir a
## jugar y encontrarte la variante rara de entrada no explica nada—, así que
## se cuenta a partir de la séptima.
static func is_soft_pipe(indice: int) -> bool:
	if indice <= 0 or SOFT_PIPE_INTERVAL <= 0:
		return false
	return indice % SOFT_PIPE_INTERVAL == 0


## La mayor escala ENTERA a la que el playfield de 288×512 cabe en una
## ventana de `ventana` píxeles (T-085).
##
## Entera y nunca fraccionaria: ADR-0002 sigue mandando dentro del playfield,
## y un 2,37x haría que unos píxeles midieran 2 y otros 3.
##
## Es pura y estática a propósito: en headless no hay ventana que consultar,
## así que el cálculo tiene que poder probarse con tamaños inventados.
static func window_scale_for(ventana: Vector2i) -> int:
	if ventana.x <= 0 or ventana.y <= 0:
		return MIN_WINDOW_SCALE
	var cabe_ancho: int = ventana.x / VIEWPORT_SIZE.x
	var cabe_alto: int = ventana.y / VIEWPORT_SIZE.y
	return clampi(mini(cabe_ancho, cabe_alto), MIN_WINDOW_SCALE, MAX_WINDOW_SCALE)


## Dónde queda el playfield dentro de esa ventana, en píxeles reales (T-085).
##
## Siempre centrado, en cualquier proporción. Se centra con división entera:
## medio píxel de desplazamiento volvería a meter el escalado fraccionario
## por la puerta de atrás.
static func playfield_rect_for(ventana: Vector2i) -> Rect2i:
	var escala: int = window_scale_for(ventana)
	var tamano := Vector2i(VIEWPORT_SIZE.x * escala, VIEWPORT_SIZE.y * escala)
	var origen := Vector2i((ventana.x - tamano.x) / 2, (ventana.y - tamano.y) / 2)
	return Rect2i(origen, tamano)


## Cuánto sobra alrededor del playfield, en píxeles reales (T-085).
##
## `x` es lo que sobra a CADA lado en horizontal e `y` en vertical, no el
## total: lo que decide si cabe un panel al lado es el hueco de un lado, no
## la suma de los dos. Nunca negativo: si el playfield no cabe, sobra 0.
static func layout_margin_for(ventana: Vector2i) -> Vector2i:
	var caja: Rect2i = playfield_rect_for(ventana)
	return Vector2i(maxi(caja.position.x, 0), maxi(caja.position.y, 0))


## El factor de viento que de verdad se puede aplicar a esa puntuación
## (T-064), respetando el sobre de la curva de dificultad.
##
## El criterio del ticket es que el viento **nunca** saque el scroll de
## `[SCROLL_SPEED, SCROLL_SPEED_MAX]` (escalados al modo). Acotar a secas
## tenía un efecto feo: a 0 puntos ya estás en el mínimo, así que un viento
## en contra no haría nada, y en el tope pasaría lo mismo con uno a favor.
## Una ráfaga anunciada que luego no se nota es peor que no tenerla.
##
## Así que se sopla **hacia donde hay margen**: se pide una dirección y, si
## esa no cabe, se devuelve la contraria. El rango se respeta exacto y la
## ráfaga siempre se siente. Devuelve 1.0 solo si no cabe ninguna de las dos.
static func wind_factor_for(score: int, modo: Difficulty, a_favor: bool) -> float:
	var base: float = scroll_speed_for(score, modo)
	if base <= 0.0:
		return 1.0
	var suelo: float = scroll_speed_for(0, modo)
	var techo: float = scroll_speed_for(DIFFICULTY_CAP, modo)
	var cola: float = clampf(base * WIND_FACTOR_TAIL, suelo, techo) / base
	var contra: float = clampf(base * WIND_FACTOR_HEAD, suelo, techo) / base
	var preferido: float = cola if a_favor else contra
	var alternativo: float = contra if a_favor else cola
	if not is_equal_approx(preferido, 1.0):
		return preferido
	return alternativo


## La velocidad del mundo con el viento ya aplicado y acotada (T-064).
static func wind_speed_for(score: int, modo: Difficulty, factor: float) -> float:
	var base: float = scroll_speed_for(score, modo)
	return clampf(base * factor, scroll_speed_for(0, modo), scroll_speed_for(DIFFICULTY_CAP, modo))


## Probabilidad de que un par de tuberías gire, a esa puntuación (T-065).
##
## Misma forma que `moving_pipe_chance`: pura, 0 exacto por debajo del
## mínimo, y con tope para que no sea la norma.
static func spin_pipe_chance(score: int) -> float:
	if score < SPIN_PIPE_MIN_SCORE:
		return 0.0
	var recorrido: int = maxi(DIFFICULTY_CAP - SPIN_PIPE_MIN_SCORE, 1)
	var t: float = clampf(float(score - SPIN_PIPE_MIN_SCORE) / float(recorrido), 0.0, 1.0)
	return lerpf(SPIN_PIPE_CHANCE_MIN, SPIN_PIPE_CHANCE_MAX, t)


## En qué estado de jadeo está Flapo con ese aliento (T-201).
##
## **Función pura, y eso es la decisión del ticket**: el jadeo no se guarda en
## ningún sitio, se deriva del aliento en cada frame. Así no hay un estado
## que reiniciar al empezar partida —y por tanto no hay un reinicio que
## olvidar, que es como se cuelan los bugs de ADR-0011—: al volver el aliento
## al máximo, el jadeo desaparece solo.
static func pant_level(aliento: float, maximo: float) -> Pant:
	if maximo <= 0.0:
		return Pant.NINGUNO
	if aliento <= 0.0:
		return Pant.AGOTADO
	if aliento / maximo < BREATH_LOW_RATIO:
		return Pant.JADEO
	return Pant.NINGUNO


## Cuánto se tiñe Flapo con ese aliento, de 0 a `PANT_TINT_MAX` (T-201).
##
## Continuo y no por escalones: el rubor sube según se acaba el aire, así que
## el jugador ve venir el agotamiento en vez de encontrárselo de golpe.
static func pant_tint_weight(aliento: float, maximo: float) -> float:
	if maximo <= 0.0 or BREATH_LOW_RATIO <= 0.0:
		return 0.0
	var ratio: float = clampf(aliento / maximo, 0.0, 1.0)
	if ratio >= BREATH_LOW_RATIO:
		return 0.0
	var hundido: float = 1.0 - ratio / BREATH_LOW_RATIO
	return hundido * PANT_TINT_MAX


## Nombre del modo para la interfaz. Vive aquí y no en el menú porque es
## contenido de las reglas, no de la pantalla que lo enseña.
static func difficulty_name(modo: Difficulty) -> String:
	match modo:
		Difficulty.FACIL:
			return "Fácil"
		Difficulty.DIFICIL:
			return "Difícil"
	return "Normal"


## Segundos entre spawns de tuberías (T-025).
##
## Derivado, no constante suelta: la separación en píxeles es lo que se
## percibe al jugar, y el intervalo es su consecuencia. Si se tunea la
## velocidad de scroll sin tocar esto, la separación real cambiaría.
static func pipe_spawn_interval() -> float:
	return PIPE_SPACING / SCROLL_SPEED


## Alto de la zona por la que Flapo puede volar, px: la pantalla menos el
## suelo. Derivado por el mismo motivo que el intervalo de spawn.
static func playable_height() -> float:
	return float(VIEWPORT_SIZE.y) - GROUND_HEIGHT


## En qué escalón de confianza está alguien que ha jugado `partidas` partidas.
##
## Función pura, como el resto de la progresión: no hay estado de confianza
## que sincronizar, solo un número guardado del que se deriva todo.
static func confidence_level(partidas: int) -> int:
	return clampi(partidas / CONFIDENCE_STEP, 0, CONFIDENCE_MAX_LEVEL)


## Aliento máximo en ese escalón. En el tope, 140 sobre los 100 de salida.
static func max_breath_for(nivel: int) -> float:
	var n: int = clampi(nivel, 0, CONFIDENCE_MAX_LEVEL)
	return MAX_BREATH + float(n) * CONFIDENCE_BREATH_BONUS


## Multiplicador del impulso de aleteo según cuántos aleteos ha habido en la
## ventana reciente (T-049).
##
## Es una **función pura del historial**: no hay estado de fatiga escondido en
## `bird.gd` que haya que reiniciar, sincronizar o depurar. Flapo guarda las
## marcas de tiempo de sus aleteos y pregunta.
static func fatigue_impulse_mult(aleteos_en_ventana: int) -> float:
	return 1.0 - FATIGUE_PENALTY if aleteos_en_ventana > FATIGUE_FLAP_COUNT else 1.0


## Si ese número de aleteos cuenta como fatiga. Lo usa el HUD y los tests.
static func is_fatigued(aleteos_en_ventana: int) -> bool:
	return aleteos_en_ventana > FATIGUE_FLAP_COUNT


## Qué medalla corresponde a una puntuación. Los umbrales viven aquí y no en
## el panel: son regla de juego, no decoración (criterio de T-071).
static func medal_for(score: int) -> Medal:
	if score >= MEDAL_GOLD:
		return Medal.JAMON
	if score >= MEDAL_SILVER:
		return Medal.TORTILLA
	if score >= MEDAL_BRONZE:
		return Medal.CROQUETA
	return Medal.NINGUNA


## Nombre visible de una medalla.
static func medal_name(medal: Medal) -> String:
	match medal:
		Medal.JAMON:
			return "Jamón"
		Medal.TORTILLA:
			return "Tortilla"
		Medal.CROQUETA:
			return "Croqueta"
		_:
			return ""
