# ADR-0032 — El fantasma graba posiciones, no pulsaciones

Fecha: 2026-09-08 · Estado: aceptada · Depende de [ADR-0030](ADR-0030-semilla-determinista.md)

## Contexto
T-243 pide un fantasma del récord: al volver a jugar la misma semilla, un
Flapo translúcido repite el vuelo con el que se batió la marca. Es la única
forma honesta de competir contigo mismo sin servidor.

El ticket propone guardar **la semilla y la lista de inputs** (frame +
aleteo/planeo) y reconstruir el vuelo reproduciéndolos. Es lo que hace
cualquier replay de un juego determinista, y este juego lo es: física a 60 Hz
fijos (ADR-0002) y un solo generador con semilla (ADR-0030).

## Decisión
Se graban **posiciones**: la `y` de Flapo en cada frame de física desde el
primero de `PLAYING`, en `user://ghost.dat`.

Solo la `y`. La `x` de Flapo no se mueve nunca —`_mantener_carril` en `Bird`
lo garantiza desde T-066—, así que grabarla sería guardar 3600 veces el mismo
número.

## Por qué no inputs
Un replay por inputs solo es fiel mientras la simulación no cambie. Y aquí la
simulación **es un montón de constantes que estamos tuneando ticket a
ticket**: `GRAVITY`, `flap_impulse`, `glide_gravity_mult`, `max_fall_speed`,
el coste de aliento por aleteo, la fatiga.

El día que se toque cualquiera de ellas —y se van a tocar, T-040 está
pendiente justo para eso— todos los fantasmas ya guardados se desincronizan.
Y no fallan con un error: fallan volando por sitios por donde nadie voló,
atravesando tuberías, aterrizando en el suelo a destiempo. Un bug silencioso
en el disco de cada jugador, que además solo se ve al reproducir.

Con posiciones, el fantasma **es** el vuelo que se hizo, pase lo que pase con
las constantes. El fichero es más grande —cuatro bytes por frame, unos 14 KB
por una partida de un minuto— y ese es todo el precio.

Hay una tercera ventaja, y es la que cierra un cabo suelto de ADR-0030: allí
quedó anotado que "un replay tiene que grabar el frame de inicio, no solo la
semilla", porque la `x` de las tuberías depende de en qué frame arrancó
`PLAYING`. Grabando posiciones ese problema no existe: el ancla es el frame 0
de `PLAYING`, el mismo en la partida grabada y en la reproducida.

## Por qué no colisiona
El fantasma es un `Node2D` con un `AnimatedSprite2D` dentro y **ni una sola
`CollisionShape2D` en toda la escena**. No es un `Bird` con la máscara a 0.

La diferencia importa: una máscara a 0 es un interruptor, y un interruptor lo
puede volver a encender cualquier ticket futuro sin darse cuenta. Aquí no hay
nada que encender. El test lo comprueba recorriendo la escena entera.

Tampoco pide un solo número al generador de la partida, así que jugar con
fantasma y sin él da exactamente las mismas tuberías. El test lo verifica
comparando las dos partidas, no leyendo el código.

## Cuándo sale
Solo si la semilla de la partida en curso es la del vuelo guardado. Con otras
tuberías, el vuelo grabado no significa nada: el fantasma pasaría por un hueco
que hoy no existe. En la práctica eso lo deja para el reto del día (T-241) y
para los códigos compartidos (T-242), que es donde comparar tiene sentido.

Se guarda al **batir el récord**, no al morir: si no, el "fantasma del récord"
sería en realidad "el fantasma de la última partida", que es otra cosa y
bastante menos útil.

## Cuándo se va
En cuanto el jugador pasa del último frame grabado. No se queda en la última
posición.

Esto se decidió mal la primera vez. Sobre el papel, "se queda donde se
estrelló" sonaba razonable. En pantalla se veía otra cosa: un pájaro planeando
en línea recta para siempre, porque la última `y` grabada se repetía frame
tras frame mientras el mundo seguía moviéndose. Un fantasma que sigue ahí
después de superarlo miente sobre lo único que tiene que contar, que es dónde
llegaste; y el instante en que desaparece es justo el premio de haberlo
superado.

Es distinto de morirse: si el que muere es el jugador, el fantasma se queda
quieto donde iba, y ahí sí enseña algo — la distancia que faltaba.

## Consecuencias
- Un fantasma sobrevive a cambiar `GameConfig`; un replay por inputs no.
- El fichero crece con la duración de la partida. Tope: `GHOST_MAX_FRAMES`,
  unos 10 minutos. No es un límite de diseño, es un seguro contra un fichero
  manipulado a mano.
- **Esto no sirve para T-261 (replay determinista)**. Un replay de verdad
  necesita reproducir la partida entera —muertes, frutas, viento—, y eso sí
  pide inputs. Son dos cosas distintas y van a convivir: el fantasma es una
  silueta que vuela, el replay es la partida otra vez.
- Fichero ausente, truncado, de otra versión o con basura: no hay fantasma y
  el juego sigue igual. Misma regla de oro que `SaveManager` (ADR-0013), y con
  una comprobación de tamaño al byte, porque un fichero cortado por la mitad
  se leería como un vuelo lleno de ceros.
