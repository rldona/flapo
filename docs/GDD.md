# GDD — Flapo

> Una página. Si no cabe, el alcance es demasiado grande.

## Pitch
Toca para que Flapo aletee y cruza tantas tuberías como puedas sin tocar nada.

## Concepto y tono
Flapo es el hermano gordito del pájaro famoso. Quiere volar como él, pero pesa el doble y le cuesta el triple. El juego es el mismo reto de siempre contado con humor: cada muerte es un batacazo cómico, no un drama.

Cómo se traduce al juego:
- **Silueta**: redondo, tripa por delante, alas pequeñas. Lee mejor a 16×12 px que un pájaro estilizado.
- **Física**: caída algo más pesada y aleteo con esfuerzo visible (frames exagerados, un pequeño "uf" de retardo antes del impulso, siempre por debajo de 50 ms para no estropear el control).
- **Muerte**: rebote en el suelo, ojos en espiral, sacudida de cámara más fuerte que en un Flappy normal.
- **UI**: logo con la tripa como letra O, medallas con nombre de comida (croqueta de bronce, tortilla de plata, jamón de oro).
- **Textos**: cortos y con guasa. "Otra vez", no "Game Over".

Lo que NO es: no se ríe del jugador, se ríe con él. Nada de mensajes de burla al morir.

Las frases que salen al morir viven en `assets/data/death_lines.tres` (T-056),
editables sin tocar código. La regla al escribir una: **ánimo torpe, nunca
burla**. Si una frase se puede leer como "qué malo eres", sobra.

Desde T-075 la frase **se ajusta a cómo murió**: hay una lista por causa
(tubería, suelo, caída al vacío) y otra para cuando llega con el aliento a
cero, que tiene prioridad sobre la causa. Ojo al tono aquí: comentar la causa
se acerca peligrosamente a señalar el error del jugador. "Un poco más arriba
y pasa" vale; "otra vez contra la misma tubería" no.

**Quedarse sin aliento no es una causa de muerte**, es un agravante: a 0 se
pierde el planeo, nunca el aleteo (ADR-0020).

Nota de tienda: en itch.io y Google Play nunca usar el nombre del juego original ni describir Flapo como spin-off. "Inspirado en el clásico de un solo botón" es suficiente.

## Bucle central
Ready → (toque) → Playing: aletear, esquivar, puntuar → (colisión) → Game Over → reintentar.

## Reglas y constantes
| Constante | Valor inicial | Valor final | Notas |
|---|---|---|---|
| Gravedad (px/s²) | 1200 | | |
| Impulso de aleteo (px/s) | -380 | | |
| Velocidad de scroll (px/s) | 100 | | |
| Separación entre tuberías (px) | 160 | | |
| Hueco inicial (px) | 118 | | se estrecha con la puntuación |
| Rango vertical del hueco | 20 %–80 % | | deja ≥30 px con techo y suelo |
| Tope superior | y = 0 | | |
| Tope de caída (px/s) | 500 | | mentira física al servicio del control (ADR-0006) |
| Alto del suelo (px) | 64 | | altura jugable = 448 |

### Qué significan esos números al jugar

Medido con `tools/medir_feel.gd`, que es lo que hay que volver a ejecutar tras
cada cambio de la tabla:

| Magnitud percibida | Con los valores actuales |
|---|---|
| Cuánto sube un aleteo | 57 px, o **2,4 alturas de Flapo** |
| Cuánto tarda en subir | 0,32 s (ida y vuelta: 0,63 s) |
| Desde que la tubería entra hasta que llega a Flapo | 2,16 s |
| Tiempo entre dos tuberías | 1,60 s — caben **4,6 aleteos** |
| Margen libre al cruzar el hueco | 84 px, 42 arriba y 42 abajo |
| Caída libre desde el inicio hasta el suelo | 0,57 s |

Lo que hay que mirar al tunear (T-040):

- **Si el aleteo sube más de ~3 alturas de Flapo**, el salto deja de leerse:
  el jugador no puede estimar dónde va a acabar.
- **Si caben menos de 3 aleteos entre tuberías**, no da tiempo a corregir y el
  juego pasa de difícil a injusto.
- **El margen del hueco son 42 px por lado** porque la hitbox (radio 8) es más
  pequeña que el dibujo (24 px): Flapo sobresale 4 px por lado sin morir. Eso
  es deliberado y hace el juego generoso.

### Curva de dificultad (T-045)

La dificultad sube con la puntuación y **tiene tope a los 30 puntos**. Todo
son funciones puras de la puntuación, así que reiniciar la devuelve al inicio.

| Puntos | Velocidad | Hueco | Separación | Aleteos entre tuberías |
|---|---|---|---|---|
| 0 | 100 px/s | 118 px | 160 px | 4,57 |
| 15 | 122 px/s | **100 px** | 166 px | 3,87 |
| 30 y más | 145 px/s | 82 px | 172 px | **3,39** |

El hueco arranca **por encima** de los 100 px habituales del género y llega a
ellos justo a los 15 puntos: los primeros quince son la rampa de entrada, y a
partir de ahí el juego es el de siempre y sigue apretando.

La separación sube a propósito: es lo que mantiene los aleteos por encima de
3. Ver ADR-0018.

### Tuberías móviles (T-063)

A partir de **15 puntos** —cuando acaba la rampa de entrada— algunos pares
oscilan arriba y abajo. La probabilidad va de 0,15 a los 15 puntos a 0,45 en
el tope; nunca es certeza.

| Magnitud | Valor | Por qué |
|---|---|---|
| Amplitud | hasta ±22 px | recortada por tubería para que el hueco entero quepa en pantalla |
| Periodo | 2,4 s | 58 px/s de punta |
| Velocidad frente al aleteo | 15 % | Flapo siempre puede más que la tubería |

Ese 15 % es lo que separa "exigente" de "inevitable": si la tubería subiera
más rápido de lo que Flapo sube, no habría forma de responder. Ver ADR-0023.

### Tubería blandita (T-066)

Una de cada **7** tuberías es blandita y se ve distinta (verde apagado) desde
que entra en pantalla. Tocarla **no acaba la partida**: rebota a Flapo hacia
el hueco y cuesta 35 de aliento y 1 punto, con 0,8 s entre cobros.

Es predecible a propósito: al poder contarla se convierte en una decisión
("me la juego en la séptima") en vez de en un golpe de suerte. Tocar a la vez
una blandita y una normal sí mata: la blandita no es un escudo. Ver ADR-0023.

### Tubería giratoria (T-065)

A partir de **12 puntos**, algunos pares giran las bocas a 0,35 vueltas por
segundo. **Es solo el dibujo**: el hueco real y la puntuación son idénticos a
los de una tubería normal. Ver ADR-0023.

### Ráfagas de viento (T-064)

A partir de **10 puntos**, cada 12-22 s hay una ráfaga de 5 s que sube o baja
la velocidad del mundo un 25 % / 20 %. **Siempre se anuncia 2 s antes** (5,7
aleteos) con un cartel ámbar; mientras sopla el cartel es blanco.

El viento nunca saca la velocidad del sobre de la curva, y por eso **sopla
hacia donde hay margen**: a 0 puntos solo puede empujar a favor, en el tope
solo en contra. Así el rango se respeta y la ráfaga siempre se nota. Ver
ADR-0026.

- Muerte: contacto con tubería o suelo.
- Puntuación: +1 al atravesar el hueco. Una vez por tubería.
- Récord persistente. Medallas: bronce 10, plata 20, oro 40.

## Estados
`MENU` (título, récord, jugar y modo) · `READY` (Flapo flota, sin gravedad) · `PLAYING` · `GAME_OVER` (0,5 s de retardo antes del panel).

Se vuelve a `MENU` desde el Game Over. `MENU` es `READY` con un panel encima:
el mundo se ve quieto detrás, y aletear ahí no empieza la partida.

### Modos de dificultad (T-078)

Los tres modos son **el mismo juego escalado**, no tablas aparte:

| Modo | Hueco | Velocidad | Hueco a 0 pts | Hueco a 30 pts |
|---|---|---|---|---|
| Fácil | ×1,18 | ×0,85 | 139 px | 97 px |
| Normal | ×1,0 | ×1,0 | 118 px | 82 px |
| Difícil | ×0,88 | ×1,15 | 104 px | 72 px |

La separación entre tuberías escala con la velocidad, así que **los aleteos
que caben entre dos tuberías son los mismos en los tres modos** (4,57 al
empezar, 3,39 en el tope). La dificultad cambia el margen y el tiempo de
reacción, nunca el ritmo. Ver ADR-0022.

El modo elegido se recuerda entre sesiones y no se puede cambiar jugando.

### Nombre de jugador (T-079)
Campo opcional en el menú, máximo 12 caracteres. **Jugar sin nombre nunca se
bloquea**: quien no pone ninguno comparte en primera persona ("He cruzado 3
tuberías con Flapo") en vez de firmar.

### Estadísticas (T-084)
Desde el menú: partidas jugadas, mejor marca, mejor medalla, tuberías
cruzadas en total y media por partida. Solo el total de tuberías es un
contador nuevo; lo demás se deriva de lo que ya se guardaba.

## Controles
Acción `flap`: toque, click izquierdo, espacio. `restart`, `pause`.

## Feedback
Sonidos: aleteo, punto, golpe, caída, botón. Al morir: flash blanco, sacudida de cámara, hit-stop 60–100 ms. Parallax de fondo en 2 capas.

## Estilo
El playfield mide siempre 288×512 lógicos y se escala a la mayor **escala
entera** que cabe en la ventana (tope 6x), centrado en cualquier proporción y
recalculado en vivo al redimensionar. Ver ADR-0025.

288×512 vertical, pixel art, paleta propia de 16 colores (ver `docs/art-guide.md`). Flapo 24×24 px (hitbox: círculo de radio 8, más generosa que el dibujo).

## Aliento (T-048)
El mismo botón hace dos cosas según cuánto lo mantengas:

- **Toque corto** → aleteo de siempre, impulso fijo.
- **Mantener** (más de 0,18 s) → **planeo**: cae al 25 % de la gravedad, con
  tope de 90 px/s en vez de 500.

Las dos gastan **aliento**, y se recupera cruzando el hueco **por su mitad
central**.

| Constante | Valor | Por qué |
|---|---|---|
| `MAX_BREATH` | 100 | escala arbitraria; 100 se lee como porcentaje |
| `BREATH_DRAIN_FLAP` | 10 por aleteo | ~25/s a ritmo normal |
| `BREATH_DRAIN_GLIDE` | 15 por segundo | menos que aletear: planear es lo barato |
| `BREATH_RECOVER_ON_GAP` | +25 por hueco centrado | ~15,6/s: sostiene el planeo, no el aleteo |
| `BREATH_BAND_RATIO` | 0,5 | solo la mitad central del hueco cuenta |

T-202 llegó a **dibujar** esa franja: un brillo crema muy tenue en el hueco. Se quitó después de verlo jugando, y el motivo es que **no se leía como una pista**: sin nada que lo relacionara con el aliento, se leía como un rectángulo semitransparente en medio del hueco, que es justo donde el jugador tiene que estar mirando. La regla no cambia — cruzar por el centro sigue dando aire—; lo que desaparece es el dibujo. Que la pista se enseñe de otra forma queda pendiente.

**A 0 de aliento el planeo deja de frenar, pero el aleteo corto sigue dando el
impulso completo.** Flapo nunca se queda sin poder aletear: el castigo es
perder una herramienta, no el control. Ver ADR-0020.

### Confianza (T-074)
Cada **10 partidas jugadas** (no puntos), Flapo gana **+8 de `MAX_BREATH`**,
con tope en el escalón 5: de 100 a 140 a las 50 partidas. Sube solo, se
guarda con el récord y nunca baja.

**No es un power-up comprado ni un desbloqueable.** No hay moneda, ni tienda,
ni menú de mejoras, ni aviso de "has subido de nivel": lo único que el
jugador ve es que la barra de aliento es un poco más larga que hace unos
días. Por eso la lista de "fuera de alcance en v1" sigue intacta. Mejora
quien insiste, no quien ya juega bien, y solo mejora el **planeo**: el
aleteo, que es el control, no cambia nunca. Ver ADR-0021.

### Enseñar el planeo (T-200)
El planeo es la mecánica que ningún clon tiene, y nadie la descubre solo. En
`READY`, durante las **5 primeras partidas**, un cartel dice "mantén pulsado
para planear"; dentro de la partida vuelve a salir si a los **3 huecos** no se
ha planeado nunca. **En cuanto se plana una vez, desaparece para siempre** y
queda guardado.

Nunca bloquea ni pausa: aletear con el cartel puesto funciona igual. Un
tutorial que hay que cerrar es un tutorial que estorba.

### Jadeo visible (T-201)
La barra de aliento es UI; el aliento **también se ve en Flapo**. Por debajo
del **30 %** (`BREATH_LOW_RATIO`): alas temblando (aleteo ×1,6), mejillas
encendidas y gotas de sudor. A 0, además, vaho.

El rubor es una **rampa continua**, no un interruptor: sube según se acaba el
aire, así que el agotamiento se ve venir. Y todo es función pura del aliento
—no hay estado de jadeo guardado—, así que al empezar partida se apaga solo.
La hitbox no cambia en ningún estado.

### Fatiga (T-049)
Más de **4 aleteos en 1,2 s** reduce el impulso del siguiente un **30 %**. Se
quita planeando una vez o dejando pasar la ventana.

El ritmo normal de juego son 3,4 aleteos por hueco en el punto más duro de la
curva, así que **jugar bien nunca fatiga**: solo machacar el botón. Y el
impulso reducido sigue subiendo, nunca deja a Flapo sin control.

## Frutas (T-047)
Aparecen flotando entre tuberías, en la franja central. 6 s de duración; el
escudo va aparte y no caduca.

Los efectos **se acumulan, uno por eje**: gravedad, tamaño y velocidad del
mundo. Ser grande y coger la violeta deja **grande y lento**, no lento y
pequeño. Lo que sí se sustituye son los opuestos: coger la roja llevando la
verde deja pesado, no "normal" — dejarlos convivir los cancelaría y el jugador
vería que no pasa nada con dos frutas encima.

El **escudo se acumula** hasta 3 (`SHIELD_MAX`). Coger una azul llevando otra
ya no desperdicia la segunda: se apilan, el HUD dice cuántos quedan
("Escudo x3") y cada golpe gasta uno. El tope existe por dos motivos: a 288 px
de ancho "Escudo x12" no se lee de un vistazo, y con escudos infinitos quien
encadena azules deja de jugar al juego del aliento y pasa a jugar a otro
donde chocar no importa.

| Fruta | Efecto | Puntos |
|---|---|---|
| Azul | Inmunidad a un toque | — |
| Verde | Flapo pesa la mitad | — |
| Violeta | El mundo va al 60 % | — |
| Roja | Flapo pesa el doble | **+3** |
| Naranja | Flapo es el doble de grande (hitbox ×1,6) | **+3** |

Las de castigo pagan en puntos: es lo que las convierte en una apuesta en vez
de en una trampa. Ver ADR-0019.

## Semilla compartible (T-242)
Cada partida libre enseña en el Game Over un **código de 5 caracteres** en
base 36, y el menú tiene "Jugar un código". Dos amigos escriben el mismo y
juegan exactamente las mismas tuberías, sin ranking online ni servidor.

La semilla de una partida libre se sortea **dentro del espacio del código**:
si fuera mayor, el código enseñado llevaría a otra partida y nadie se
enteraría. Da igual mayúsculas y espacios, porque se dicta por teléfono. Un
código inválido no rompe nada: aviso corto y se sigue en el menú.

En el reto del día no hay código: ya se identifica por su fecha.

## Reto del día (T-241)
Botón en el menú. La semilla es **la fecha local en AAAAMMDD**, así que todo
el mundo juega las mismas tuberías ese día **sin servidor**. Cambia a
medianoche del jugador, no en UTC.

Solo cambia la semilla: el modo de dificultad, las frutas y el resto de
reglas son los del juego normal — un reto con reglas distintas no sería
comparable. La marca va a **su propia clave** y no toca el récord general,
pero la partida sí cuenta como jugada (suma confianza y tuberías). Al
compartir dice de qué día era.

## Determinismo (T-240)
Toda la aleatoriedad de una partida —huecos, variantes de tubería, frutas,
viento— sale de **un solo generador** con semilla conocida. Con la misma
semilla, la secuencia de tuberías es idéntica; desde un arranque limpio, la
partida entera lo es frame a frame.

Lo cosmético (sacudida de cámara, frases al morir) queda **fuera** a
propósito: si entrara, el aspecto del juego afectaría a su simulación. Y el
determinismo **no sobrevive a cambiar una constante del GDD**. Ver ADR-0030.

## Fuera de alcance en v1
Skins, ranking online, anuncios, compras, modos de juego.

La **progresión de confianza (T-074) no está en esta lista** y no la
contradice: no se compra, no se elige y no tiene pantalla. Ver ADR-0021.

Los **power-ups estaban aquí** hasta T-047: se sacaron de la lista a
propósito, con ADR-0019, cuando el juego ya estaba completo y se vio que
aguantaba más sustancia.

El **modo espejo (T-076)** es la segunda excepción, con ADR-0038. Se
desbloquea con récord 25 y da la vuelta a la gravedad y al aleteo: la física
de siempre con el signo cambiado. Entra porque **no añade sistemas** —ni
tienda, ni servidor, ni assets, ni una segunda economía— y se paga una vez.
Skins, ranking online, anuncios y compras siguen fuera, y por ese mismo
motivo: todas ellas traen algo que mantener para siempre.

Es **opt-in y nunca automático**: aparece un botón en Opciones al
desbloquearlo, y hasta entonces no existe. El modo normal no cambia en nada.
