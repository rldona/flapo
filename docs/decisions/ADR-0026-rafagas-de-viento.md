# ADR-0026 — Ráfagas de viento: acotadas al sobre de la curva y siempre anunciadas

Fecha: 2026-09-08 · Estado: aceptada · Extiende [ADR-0018](ADR-0018-curva-de-dificultad.md) y [ADR-0022](ADR-0022-modos-de-dificultad.md)

## Contexto
T-064 pide tramos puntuales donde la velocidad del mundo sube o baja durante
unos segundos, siempre anunciados antes. Dos cosas que decidir: **cómo
convive con la curva de dificultad**, que ya manda sobre esa misma velocidad,
y **qué garantiza que una ráfaga no sea una encerrona**.

## Decisión 1 · Un nodo global, con reloj propio
`Wind` cuelga de `Main`, no del spawner: el viento le pasa al mundo, no a un
obstáculo. Ciclo calma → aviso → soplando → calma, con la calma sorteada
entre 12 y 22 s para que no se pueda contar el compás.

El ticket pedía un `Timer` global. Es un reloj acumulado en
`_physics_process`, no un `Timer`, por la misma razón que en T-049 y T-063:
así se para con la pausa y con el hit-stop. Lo que importaba de aquella frase
—**global, no por tubería**— se cumple.

`Wind` no sabe la puntuación ni calcula velocidades. Solo dice si sopla y en
qué sentido; quien lo convierte en px/s es `Main`, que es quien conoce la
curva ("call down", ADR-0005).

## Decisión 2 · El viento se acota al sobre de la curva, y por eso sopla hacia donde hay margen
El criterio del ticket es que el viento nunca saque el scroll de
`[SCROLL_SPEED, SCROLL_SPEED_MAX]`, escalados al modo de dificultad
(ADR-0022). Acotar a secas tenía un efecto feo que solo se ve haciendo la
cuenta:

- A 0 puntos la velocidad **ya está en el mínimo**, así que un viento en
  contra se acotaría a sí mismo y no haría nada.
- En el tope de la curva pasa lo mismo con uno a favor.

Una ráfaga anunciada con dos segundos de antelación que luego no se nota es
peor que no tener viento: enseña al jugador a ignorar el aviso.

La decisión es **soplar hacia donde hay margen**. `wind_factor_for()` recibe
la dirección sorteada y, si esa no cabe, devuelve la contraria. El rango se
respeta exacto —el test lo comprueba en 48 combinaciones de modo, puntuación
y dirección— y ninguna ráfaga se queda en nada.

### El orden de los multiplicadores
```
velocidad = acotar_al_sobre(curva(puntos, modo) × viento) × fruta_violeta
```
La fruta violeta va **al final y fuera del acotado**, a propósito: su efecto
es justamente bajar del mínimo (60 px/s frente a 100), y el criterio del
viento no debía llevárselo por delante. Un test lo fija.

## Decisión 3 · El aviso es parte de la mecánica, no decoración
`WIND_WARNING_TIME` son 2 s, y eso son **5,7 aleteos** (`FLAP_CYCLE` = 0,35
s): tiempo de sobra para recolocarse. El test comprueba esa relación, no el
número suelto, para que tunear el aleteo en T-040 lo detecte.

El cartel distingue aviso de ráfaga **en el texto y en el color**: ámbar y la
palabra "viento" mientras avisa, blanco y solo flechas mientras sopla. Si
fueran el mismo cartel, el jugador no sabría si tiene dos segundos o si ya
está pasando.

## Consecuencias
- El viento no sopla por debajo de `WIND_MIN_SCORE` (10). La rampa de entrada
  se deja limpia, igual que con las tuberías móviles.
- Fuera de `PLAYING` no hay viento **y se reinicia**: en el menú una ráfaga no
  significa nada, y dejar el reloj corriendo descuadraría el aviso de la
  partida siguiente.
- **Se deshace solo**: no hay estado que limpiar al terminar. La velocidad es
  función pura de la puntuación (ADR-0018), así que basta con recalcular.
- `skip_to_next_phase()` existe solo para los tests: esperar 12 s de calma
  real por cada caso haría la suite lenta y dependiente del reloj.
- **No cubierto aquí**: si 2 s de aviso *bastan de verdad* jugando. La cuenta
  dice que sí; lo dice jugar.

---

## Ampliación (T-203): las térmicas, y el sistema de aire

T-203 pide que esta ADR documente "el sistema de aire" —térmicas y rebufo— en
vez de abrir número nuevo. Tiene sentido: las ráfagas ya eran aire, y son la
misma idea con tres formas.

**Aire es lo que cambia lo que hace el planeo, no lo que hay que esquivar.**
Esa es la regla que las une y la que decide si algo nuevo entra aquí.

| Pieza | Qué hace | Alcance |
|---|---|---|
| Ráfaga (T-064) | Cambia la velocidad del mundo | Toda la pantalla |
| Térmica (T-203) | Planear **sube** en vez de caer | Una columna |
| Rebufo (T-204) | Planear **no gasta aliento** | Una estela |

### Por qué un `Area2D` propio y no la gravedad de área de Godot
Godot trae `Area2D` con `gravity_space_override`, que parece hecho para esto.
No se usa, por tres motivos:

1. **Solo afectaría a la caída, no al planeo.** La térmica no cambia la
   gravedad: cambia lo que significa *planear*. Con la gravedad de área, un
   Flapo que aletea dentro de la columna subiría más, y eso no es lo que pide
   el ticket — el aleteo tiene que ser idéntico dentro y fuera.
2. **`Bird` es un `CharacterBody2D`**, que no obedece a la gravedad de área:
   habría que leerla a mano de todos modos. La comodidad no existe.
3. **No sería comprobable igual de bien.** Una señal de entrada y salida se
   prueba en headless con dos líneas; una gravedad de área hay que
   reconstruirla desde el motor para saber qué está pasando.

### Un contador, no un `sí/no`
`Bird` cuenta cuántas térmicas lo tocan. Con un `bool`, salir de una columna
solapada con otra apagaría el efecto estando aún dentro de la segunda. Hoy no
se solapan; el día que se solapen, esto ya funciona.

### La garantía de "nunca coincide", y lo que costó
El ticket exige que una térmica nunca coincida con una tubería móvil ni con el
tramo especial, **y que lo garantice el spawner, no el azar**. Son dos
comprobaciones, porque la térmica cae entre dos tuberías:

- La de detrás ya existe cuando se decide: se mira.
- La de delante todavía no, así que se le **reserva** al generador.

De ahí salió un invariante que faltaba y que va mucho más allá de este ticket:
**cada tubería consume siempre los mismos números del generador**, decida lo
que decida ser. Si la cantidad de tiradas dependiera del resultado, cualquier
cosa que empuje una decisión —una reserva, el tramo especial— desplazaría la
secuencia entera, y dos partidas con la misma semilla dejarían de ser la misma
(ADR-0030). Antes, el desfase de oscilación solo se sorteaba si la tubería
oscilaba; ahora se sortea siempre y se usa si toca.

Y un choque entre tickets: el tramo especial (T-067) puede **arrancar** entre
la reserva y la tubería reservada. Se resuelve **aplazando el tramo una
tubería** en vez de pisar la reserva: el tramo sigue durando sus cuatro y la
térmica no acaba pegada a una giratoria. Los dos tickets se cumplen enteros.

### Dos bugs que encontró el test, no la lectura del código
- Las térmicas **no caían a mitad de camino**: se sumaba media separación a la
  `x` de nacimiento del propio spawner (400) en vez de a la de las tuberías
  (320), así que aparecían casi encima de la tubería siguiente. Se vio al
  medir las vecinas de cada térmica.
- La primera versión del test medía "coincidir" como solape de rectángulos.
  Como la térmica cae a media separación, **nunca** se solapa con nada y el
  test estaba siempre en verde: quitando la garantía entera no se enteraba.
  Ahora mira la tubería de antes y la de después.

## Ampliación (T-204): el rebufo, y el hermano

El hermano es **puro escenario**: un `Node2D` con un sprite y ni una forma de
colisión en toda la escena. No es un `CharacterBody2D`, no colisiona, no
puntúa y no se le alcanza. Es un chiste que cruza la pantalla, y el humor es
con Flapo, nunca contra él (GDD).

Todo su efecto en el juego es la estela que deja. Planear dentro **no gasta
aliento**: ni empuja, ni sube, ni puntúa. El rebufo es **descanso, no
ventaja** — si empujara, el chiste dejaría de serlo y pasaría a ser una pieza
que hay que cazar.

### El carril del hermano sale de la geometría, no del gusto
Cruza **pegado a un borde**, arriba o abajo, eligiendo el contrario al hueco
que toca. No "a media pantalla, lejos del hueco", que es lo que hacía la
primera versión.

El motivo es que **el hermano atraviesa media pantalla** y se encuentra huecos
que todavía no existían cuando se decidió su altura. Apartarse del hueco de la
última tubería no vale para el que viene tres tuberías después. Se midió: 62
invasiones.

Los huecos se sortean entre el 20 % y el 80 % de la altura jugable, así que un
carril a 26 px del borde **nunca** cae dentro de ninguno, ni del siguiente ni
del que venga después. El test lo comprueba con aritmética sobre el hueco más
extremo que el juego puede generar, no muestreando mientras el hermano pasa —
pasa en un segundo, y muestrear no encontraba el caso malo.

### Un número que estaba mal por geometría
`SLIPSTREAM_TIME` era 3,5 s. La estela mide una pantalla de ancho y se mueve
con el mundo, así que tarda unos 2,4 s en salirse por la izquierda: **el
temporizador no llegaba a notarse nunca** y su desvanecido no lo veía nadie.
Ahora son 2,0 s.

Lo destapó el test al preguntar algo que parecía una tontería: no *cuándo*
muere la estela, sino **dónde**. Preguntando por el tiempo, las dos causas de
muerte —caducar y salirse— daban casi el mismo número y eran
indistinguibles.
