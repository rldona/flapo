# ADR-0033 — Un submenú de opciones, y qué entra en él

Fecha: 2026-09-08 · Estado: aceptada · Amplía [ADR-0005](ADR-0005-main-cablea.md)

## Contexto
El menú de inicio llegó a **nueve elementos apilados en una columna de 288 px**,
siete de ellos tocables con sus 48 dp de alto mínimo (T-030). Nació en T-078
con título, récord, jugar y dificultad; T-079 le puso el nombre, T-084 las
estadísticas, T-241 el reto del día, T-242 el campo de código con su botón y
su aviso. Cada ticket, una fila más.

Y quedaba sitio por gastar: T-243 pide poder esconder el fantasma, T-090 trae
tres ajustes de accesibilidad y T-245 la calibración del micrófono.

## Decisión
Un `OptionsPanel`, y una regla para lo que entra:

> **Ajustes sí, acciones no.** Se va a opciones lo que se elige una vez y
> persiste. Se queda fuera lo que se hace.

Por eso van dentro el nombre, el modo, el sonido y el fantasma; y se quedan
fuera jugar, el reto de hoy, jugar un código y ver las estadísticas. Jugar un
código parece un ajuste porque es un campo de texto, pero es una acción: se
escribe y se juega, no se guarda.

Sin una regla, un submenú de opciones es solo un sitio nuevo donde amontonar,
y dentro de seis tickets estaríamos hablando de partirlo en pestañas.

## No es un estado de la máquina
Es un panel que se abre encima del menú, igual que las estadísticas (T-084) y
que la pausa se abre encima de la partida. Detrás sigue estando el menú: no
hay nada del mundo que cambiar, y un quinto estado obligaría a cada pieza del
juego a saber que existe una pantalla que no le afecta.

Salir del menú lo cierra, como cierra las estadísticas. Un panel que se
quedara delante de la partida sería un bug de los que solo se ven jugando.

## Los botones dicen el estado, no la acción
"Sonido: activado", no "Silenciar". Un botón que enuncia lo que va a pasar
deja al jugador adivinando en qué estado está ahora mismo — que es justo lo
que viene a mirar cuando abre opciones.

## Dónde se guarda
En `user://settings.cfg` (`Settings`), no en `user://save.cfg` (`SaveManager`).
La separación es la de ADR-0013: **progreso** contra **preferencias**. Borrar
la partida no debería desactivar el mute, ni al revés.

Dentro del fichero, sección propia `[juego]` en vez de amontonarlo en
`[audio]`. Cuando T-090 traiga tres ajustes más, el fichero seguirá siendo
legible por un humano, que es medio motivo de que sea texto plano.

## El fantasma, en concreto
Por defecto **se ve**. Es una función del juego, no una molestia que haya que
desactivar: nadie debería tener que descubrir un ajuste para disfrutar de algo.
Quien no lo quiera, lo apaga.

El ajuste se consulta al entrar en `PLAYING`, así que tiene efecto en la
siguiente partida. Desde el menú no hay ninguna en curso, de modo que en la
práctica es inmediato, y a cambio el fantasma no tiene que vigilar un ajuste
frame a frame.

## Consecuencias
- El menú principal baja de siete elementos tocables a seis, y ninguno de
  ellos es un ajuste.
- `MenuPanel` pierde el nombre y la dificultad: **se mudan, no se copian**. Si
  siguieran en los dos sitios habría dos estados que mantener sincronizados, y
  el ticket no habría servido de nada. El test lo comprueba mirando los hijos
  reales del menú.
- T-090 y T-245 ya tienen dónde ponerse, y una regla para decidirlo.
