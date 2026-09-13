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
