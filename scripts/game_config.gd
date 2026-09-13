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

## Las cuatro caras del mismo sitio. Es puro adorno: ni una sola de ellas
## toca el hueco, la velocidad ni la física.
enum Scenery { DIA, ATARDECER, NOCHE, LLUVIA }

## Los cuatro paisajes del viaje, en orden. El nido (T-209) está al final del
## último: el paisaje va contando lo cerca que estás sin decir un número.
enum Stage { PARQUE, TEJADOS, NUBES, CIELO }

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

# --- Semilla determinista (T-240) ---------------------------------------
## Semilla que se usa cuando nadie pide una concreta. 0 significa "sortea
## una": la partida libre sigue siendo distinta cada vez, pero la semilla que
## le tocó se puede leer y volver a jugar (T-242).
const SEED_ALEATORIA: int = 0

# --- Semilla compartible (T-242) ----------------------------------------
## Alfabeto del código. Base 36 sin distinguir mayúsculas: se dicta por
## teléfono y se teclea en un móvil, así que cuanto menos haya que precisar,
## mejor.
const CODIGO_ALFABETO: String = "0123456789abcdefghijklmnopqrstuvwxyz"

## Cuántos caracteres tiene un código. 5 en base 36 son 60 millones de
## partidas distintas: de sobra para que dos amigos no repitan, y corto para
## caber en el Game Over a 288 px.
const CODIGO_LARGO: int = 5

# --- Reto del día (T-241) -----------------------------------------------
## Nombres de los meses para el texto de compartir. Aquí y no en el panel:
## es contenido de las reglas del reto, no de la pantalla que lo enseña.
const MESES: Array[String] = [
	"enero",
	"febrero",
	"marzo",
	"abril",
	"mayo",
	"junio",
	"julio",
	"agosto",
	"septiembre",
	"octubre",
	"noviembre",
	"diciembre",
]

# --- Descubrir el planeo (T-200) ----------------------------------------
## En cuántas primeras partidas puede salir el aviso de planeo. Pocas: el
## planeo es la mecánica que ningún clon tiene y hay que enseñarla, pero un
## cartel que sigue saliendo a la décima partida es un cartel que molesta.
const GLIDE_HINT_MAX_GAMES: int = 5

## Cuántos huecos se cruzan sin planear antes de sugerirlo dentro de la
## partida. Tres: uno es casualidad, tres es que no se ha descubierto.
const GLIDE_HINT_AFTER_GAPS: int = 3

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

## --- Variantes de escenario (T-057) ---

## El color exacto del cielo en cada variante.
##
## El cielo es un `ColorRect`, así que aquí sí se puede poner el color que se
## quiera. Las capas de nubes y edificios ya vienen pintadas del PNG y solo
## se pueden **teñir**, o sea multiplicar, o sea oscurecer — que es justo lo
## que hace la luz al caer la tarde, así que no es una limitación sino la
## física del asunto.
const SCENERY_SKY: Array[Color] = [
	Color("#7CB3D7"),
	Color("#E8A06B"),
	Color("#2E3F5C"),
	Color("#8FA3B0"),
]

## El tinte de las capas. Blanco = dejarlas como están (el día de siempre).
const SCENERY_TINT: Array[Color] = [
	Color.WHITE,
	Color("#FFC49A"),
	Color("#6E7FA6"),
	Color("#B9C6CE"),
]

## Cuál de ellas llueve. Se guarda como dato y no como un `if` suelto: el día
## que haya una variante más, esto sigue diciendo la verdad.
const SCENERY_LLUEVE: Array[bool] = [false, false, false, true]

## --- Tramos del viaje (T-222) ---

## Cada cuántos puntos se cambia de tramo.
##
## 13 no es un número redondo y es a propósito: cuatro tramos de 13 ponen el
## cielo abierto en el punto 39, y el nido (T-209) cae en el 50, ya dentro del
## último tramo. Así el paisaje anuncia el final antes de que llegue en vez de
## cambiar justo encima.
const JOURNEY_STAGE_SCORE: int = 13

## Cuánto tarda el fundido entre tramos, s. Dos segundos: el cambio tiene que
## notarse al mirarlo y no al mirarlo fijamente, y sobre todo no puede robar
## la atención del hueco que se está cruzando.
const JOURNEY_FADE_TIME: float = 2.0

## --- Fin del viaje: el nido (T-209) ---

## A qué puntuación llega Flapo al nido. 50: por encima de la medalla de oro
## (40), o sea alcanzable pero no de casualidad.
const JOURNEY_END_SCORE: int = 50

## Cuánto dura la escena, s. Tres: lo que se tarda en leer una línea y
## respirar. Más y el jugador quiere seguir jugando; menos y no se entera.
const JOURNEY_SCENE_TIME: float = 3.0

## Lo que dice. Es la única frase del juego que no se burla de Flapo.
const JOURNEY_LINE: String = "Ha llegado. Gordo, pero ha llegado."

## --- Escudo acumulable ---

## Cuántos escudos se pueden llevar a la vez.
##
## Tres, y el tope existe por dos motivos. Uno es de lectura: "Escudo x12" no
## se entiende de un vistazo en una pantalla de 288 px. El otro es de juego —
## con escudos infinitos, quien encadena azules deja de jugar al juego del
## aliento y pasa a jugar a otro donde chocar no importa.
const SHIELD_MAX: int = 3

## --- Captura del mejor salto (T-077) ---

## Cuántos segundos de vuelo entran en la captura.
const SNAPSHOT_SECONDS: float = 2.0

## Cuántas siluetas de Flapo se dibujan en esos segundos. Seis: suficientes
## para que se lea el arco del vuelo, pocas para que no sea una mancha.
const SNAPSHOT_SAMPLES: int = 6

## A cuánto se amplía la imagen final. x3 sobre 288×512 da 864×1536, que es
## lo que una red social necesita para no reescalarla y emborronarla.
const SNAPSHOT_SCALE: int = 3

## Transparencia de la silueta más antigua. La más reciente va opaca; las de
## en medio interpolan. Es lo que convierte seis copias en un movimiento.
const SNAPSHOT_FADE_MIN: float = 0.22

## Color de las tuberías en la captura. La silueta, no el dibujo: la captura
## cuenta un vuelo, no enseña arte.
const SNAPSHOT_PIPE_COLOR: Color = Color("#3A5468")

## --- Modo espejo (T-076) ---

## Récord a partir del cual se ofrece el modo espejo.
##
## 25 y no menos: es por encima de la medalla de plata (20), o sea que lo ve
## quien ya domina el juego normal. Ofrecérselo antes sería ofrecer una
## variante a quien todavía no tiene de qué variar.
const MIRROR_UNLOCK_SCORE: int = 25

## --- Compañero silencioso (T-058) ---

## A qué fracción del borde del hueco empieza a considerarse un roce.
##
## 0.80 del semihueco: los últimos 20 % antes del tubo. Más generoso y el
## compañero se asustaría en casi todas las tuberías, que es la forma más
## rápida de que el jugador deje de mirarlo.
const GRAZE_RATIO: float = 0.80

## Dónde vuela el compañero respecto a Flapo, px. Detrás y arriba, nunca
## delante: entre Flapo y el hueco no puede haber nada que mirar.
const BUDDY_OFFSET: Vector2 = Vector2(-26.0, -20.0)

## Cuánto tarda en alcanzar su sitio, en segundos. El retardo es lo que le da
## vida: un segundo pájaro pegado a Flapo con un offset fijo se lee como un
## adorno del sprite, no como otro bicho.
const BUDDY_LAG: float = 0.22

## Cuánto sube y baja al volar, px, y cada cuánto. Ligero: es un compañero,
## no un segundo objetivo en pantalla.
const BUDDY_BOB: float = 3.0
const BUDDY_BOB_PERIOD: float = 0.9

## Tinte y tamaño. Más pequeño y más apagado que Flapo: si compitiera en
## contraste, el ojo iría al sitio equivocado.
const BUDDY_TINT: Color = Color("#9BBBA8")
const BUDDY_SCALE: float = 0.7

## Cuánto dura cada reacción, en segundos.
const BUDDY_SCARE_TIME: float = 0.6
const BUDDY_CLAP_TIME: float = 1.0

## Cuánto se aparta del susto, px, y cuánto aplaude, px de rebote.
const BUDDY_SCARE_JUMP: float = 14.0
const BUDDY_CLAP_BOUNCE: float = 7.0

## --- Tramo especial al superar el récord (T-067) ---

## Cuántas tuberías dura el tramo. Cuatro: suficiente para que se note que
## está pasando algo y corto para que no se convierta en un examen. A la
## velocidad de crucero son unos seis segundos.
const SPECIAL_STRETCH_PIPES: int = 4

## Récord mínimo para que el tramo exista.
##
## Con récord 0, la primera tubería de la primera partida ya sería récord y el
## tramo saldría antes de que el jugador sepa lo que es un hueco. Celebrar algo
## que no ha costado nada no celebra nada.
const SPECIAL_MIN_RECORD: int = 1

## El color del tramo. Dorado apagado: se lee como "esto es tuyo" y no como
## "cuidado", que es lo contrario de lo que este tramo quiere decir. La
## blandita (T-066) es verde y la normal no se tiñe, así que no se confunden.
const SPECIAL_PIPE_TINT: Color = Color("#E6C46A")

## --- Fantasma del récord (T-243) ---

## Transparencia del fantasma. 0.45 y no menos: por debajo desaparece sobre
## el cielo claro y el fantasma deja de servir para nada; por encima se
## confunde con Flapo en un hueco estrecho, que es justo lo que no debe pasar.
const GHOST_ALPHA: float = 0.45

## Tinte del fantasma. Azulado a propósito: la silueta es la misma que la de
## Flapo, así que el color es lo ÚNICO que los distingue de un vistazo.
const GHOST_TINT: Color = Color("#8FB8D8")

## Tope de frames que se graban, unos 10 minutos a 60 Hz. No es un límite de
## diseño sino un seguro: un fichero de fantasma no puede crecer sin fin ni
## por una partida eterna ni por un fichero manipulado a mano.
const GHOST_MAX_FRAMES: int = 36000


## Si el récord guardado da acceso al modo espejo (T-076).
##
## Depende del récord y no de las partidas jugadas: es un premio por jugar
## bien, no por jugar mucho. La confianza (T-074) ya premia lo segundo.
static func mirror_unlocked(record: int) -> bool:
	return record >= MIRROR_UNLOCK_SCORE


## A qué desvío del centro del hueco empieza a contar como roce (T-058).
##
## Se mide desde el centro, igual que `breath_band_half`, para que las dos
## bandas —la del aliento y la del susto— hablen el mismo idioma y no puedan
## solaparse por accidente.
static func graze_threshold(gap: float) -> float:
	return gap * 0.5 * GRAZE_RATIO


## En qué tramo del viaje va una puntuación (T-222).
##
## Función pura, como toda la curva (ADR-0018): no hay estado de tramo que
## sincronizar, y reiniciar vuelve al parque sin código de reinicio porque el
## marcador vuelve a 0.
static func journey_stage(score: int) -> Stage:
	var indice: int = int(maxi(score, 0) / JOURNEY_STAGE_SCORE)
	return clampi(indice, 0, Stage.size() - 1) as Stage


## Nombre visible del tramo. Lo usan los tests.
static func stage_name(tramo: Stage) -> String:
	return ["Parque", "Tejados", "Nubes", "Cielo"][int(tramo)]


## Si a esta tubería del tramo le toca ser blandita (T-067).
##
## La del medio. Un tramo de celebración con una red debajo: si el jugador se
## estrella justo en el momento de su récord, el juego le ha tendido una
## trampa disfrazada de premio.
static func is_special_soft(restantes: int) -> bool:
	return restantes == SPECIAL_STRETCH_PIPES / 2


## Relleno liso que hace falta DEBAJO del suelo para llegar al borde.
##
## Desde ADR-0042 el viewport es más alto que los 512 del diseño y el suelo
## dejaba cielo por debajo. Color plano y no el tile repetido: el tile lleva
## una línea oscura arriba y al repetirlo salía otra vez a media pantalla,
## como una costura. **Solo cambia el dibujo**; la colisión sigue igual, o
## morir contra el suelo dependería del móvil.
static func ground_fill_height(alto_viewport: float, superficie: float) -> float:
	return maxf(0.0, alto_viewport - superficie - GROUND_HEIGHT)


## Qué escenario le toca a una semilla (T-057).
##
## Sale de la semilla con una cuenta, **no de pedirle un número al
## generador**, y esa es la decisión del ticket (ADR-0024). Pedírselo movería
## la secuencia de tuberías un paso: los códigos compartidos de T-242 dejarían
## de dar la misma partida y el replay de referencia de T-261 dejaría de
## cuadrar. Un adorno no puede permitirse cambiar el juego.
##
## De regalo, el reto del día (T-241) sale con el mismo cielo para todo el
## mundo, que es lo que uno espera de un reto compartido.
static func scenery_for(semilla: int) -> Scenery:
	return posmod(semilla, SCENERY_SKY.size()) as Scenery


## El color del cielo de esa variante.
static func scenery_sky(variante: Scenery) -> Color:
	return SCENERY_SKY[int(variante)]


## El tinte de las capas de esa variante.
static func scenery_tint(variante: Scenery) -> Color:
	return SCENERY_TINT[int(variante)]


## Si en esa variante llueve.
static func scenery_rains(variante: Scenery) -> bool:
	return SCENERY_LLUEVE[int(variante)]


## Nombre visible de la variante. Lo usan los tests y el modo depuración.
static func scenery_name(variante: Scenery) -> String:
	return ["Día", "Atardecer", "Noche", "Lluvia"][int(variante)]


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


## El espacio de semillas que caben en un código (T-242).
static func codigo_modulo() -> int:
	var n: int = 1
	for i in CODIGO_LARGO:
		n *= CODIGO_ALFABETO.length()
	return n


## La semilla como código corto en base 36 (T-242).
##
## Se reduce al espacio del código antes de escribirlo. Es lo que hace que el
## código sea **de ida y vuelta**: escribir 5 caracteres y leerlos tiene que
## devolver la misma semilla, y para eso la semilla que se enseña no puede
## ser mayor que lo que cabe.
static func seed_a_codigo(semilla: int) -> String:
	var n: int = posmod(semilla, codigo_modulo())
	var base: int = CODIGO_ALFABETO.length()
	var texto: String = ""
	for i in CODIGO_LARGO:
		texto = CODIGO_ALFABETO[n % base] + texto
		n /= base
	return texto


## De código a semilla, o -1 si el código no vale (T-242).
##
## Devuelve -1 y no lanza nada: un código mal tecleado es lo más normal del
## mundo, y el juego tiene que responder con un aviso, no con un error.
static func codigo_a_seed(codigo: String) -> int:
	var limpio: String = codigo.strip_edges().to_lower()
	if limpio.length() != CODIGO_LARGO:
		return -1
	var base: int = CODIGO_ALFABETO.length()
	var n: int = 0
	for c in limpio:
		var d: int = CODIGO_ALFABETO.find(c)
		if d < 0:
			return -1
		n = n * base + d
	return n


## La semilla del reto de un día concreto (T-241).
##
## Es la fecha como número, AAAAMMDD. Derivada **solo de la fecha**: así todo
## el mundo juega las mismas tuberías ese día sin que haya un servidor que
## las reparta. Que sea legible a simple vista es a propósito: un 20260908 se
## puede comprobar de un vistazo, un hash no.
static func daily_seed(anio: int, mes: int, dia: int) -> int:
	return anio * 10000 + mes * 100 + dia


## La clave con la que se guarda la marca de ese día (T-241).
static func daily_key(anio: int, mes: int, dia: int) -> String:
	return "daily_%d" % daily_seed(anio, mes, dia)


## "8 de septiembre", para el texto de compartir (T-241).
static func daily_name(mes: int, dia: int) -> String:
	if mes < 1 or mes > MESES.size():
		return "%d/%d" % [dia, mes]
	return "%d de %s" % [dia, MESES[mes - 1]]


## Si toca enseñar el pictograma de planeo en READY (T-200).
##
## Función pura de lo guardado: en cuanto Flapo ha planeado una vez, no
## vuelve a salir nunca. Un guardado ausente o corrupto devuelve 0 partidas y
## `false` en `ha_planeado`, así que cuenta como primera vez — que es lo que
## queremos: ante la duda, se enseña.
static func show_glide_pictogram(ha_planeado: bool, partidas: int) -> bool:
	if ha_planeado:
		return false
	return partidas < GLIDE_HINT_MAX_GAMES


## Si toca sugerir el planeo en mitad de la partida (T-200).
##
## Además de las condiciones del pictograma, hace falta llevar unos cuantos
## huecos sin haber planeado: el aviso es para quien ya está jugando y no ha
## dado con ello, no para quien acaba de empezar.
static func show_glide_hint(ha_planeado: bool, partidas: int, huecos: int) -> bool:
	if not show_glide_pictogram(ha_planeado, partidas):
		return false
	return huecos >= GLIDE_HINT_AFTER_GAPS


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
