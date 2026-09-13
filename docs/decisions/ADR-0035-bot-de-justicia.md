# ADR-0035 — Qué garantiza el bot de justicia y qué no

Fecha: 2026-09-08 · Estado: aceptada · Depende de [ADR-0030](ADR-0030-semilla-determinista.md)

> **Nota de numeración.** T-260 pedía ADR-0033, pero ese número se lo llevó el
> menú de opciones (T-087). Todos los números hasta 0034 están reclamados por
> algún ticket, así que esta ADR toma el siguiente libre. Ver la lista de cabos
> sueltos al final.

## Contexto
La curva de dificultad (T-045, ADR-0018) se tuneó a ojo. "A ojo" quiere decir
que Raúl juega un rato y decide si le parece justa — lo cual mide a Raúl tanto
como al juego: un día está fino y otro no, y a la décima partida ya se sabe
las tuberías.

Con la semilla determinista (T-240) se puede hacer otra cosa: poner a jugar a
algo que no se cansa, no se distrae y siempre juega igual, 200 veces, y mirar
**dónde muere**.

## Qué garantiza
Que dos medidas son comparables. Nada más, y no es poco: es lo único que
permite decir "esta constante ha empeorado la curva" en vez de "me ha parecido
más difícil".

- Las semillas son fijas y consecutivas, así que la tanda entera se repite tal
  cual después de tocar `GameConfig`.
- El guardado se limpia **antes de cada partida**. Sin eso, la confianza
  (T-074) alarga la barra de aliento con las partidas jugadas, y la partida 180
  se jugaría con más aire que la 2: el histograma mediría el progreso del
  guardado, no la curva.
- El bot pulsa el botón de verdad (`Input.parse_input_event`). Un bot que
  empujara a Flapo por dentro mediría una física que ningún jugador toca.

## Qué NO garantiza
**Que el juego sea divertido.** Eso no se mide y este documento no lo intenta.
Un bot puede sacar una curva perfectamente plana y perfectamente aburrida.

**Que sea justo para un humano.** El bot no tiene tiempo de reacción, no se
pone nervioso y no se cansa. Mide la *forma* de la curva, no su dureza.

**Que la política sea buena.** Es una política simple y fija, elegida para ser
explicable, no para maximizar la puntuación. Si el bot muere en la tubería 5,
puede ser la tubería o puede ser el bot; lo que significa algo es que un pico
**aparezca o desaparezca** al tocar una constante.

## Tres cosas que se aprendieron calibrándolo
Las tres son hallazgos sobre el juego, no sobre el bot, y por eso están aquí.

**1. No se puede planear sin aletear.** El ticket proponía "planea cuando estás
por encima del hueco". Es imposible: el planeo no es un control aparte, es lo
que ocurre si mantienes pulsado *después* de aletear (T-200). Un bot que
intenta planear cuando quiere bajar aletea hacia arriba — se midió, trepaba
hasta el techo en todas las partidas. La política acabó siendo **solo aletear**.

**2. Lo que decide la partida es dónde se apunta.** Apuntar al centro exacto
del hueco da 1 punto de media; apuntar media subida de aleteo por debajo da
15. La razón es geométrica: un aleteo sube 60 px de golpe y la mitad del hueco
son 59, así que quien apunta al centro sale del hueco por arriba en cuanto
corrige. Apuntando bajo, el arco del aleteo *pasa* por el centro en vez de
empezar en él.

La anticipación quedó en 0,03 s —dos frames, casi "dónde está ahora"— y con
horizontes largos empeora mucho: a 0,10 s la media se hunde de 17 a 3.

**3. Predecir la caída libre es contraproducente.** La primera versión incluía
el término `0,5·g·t²` completo. A 0,30 s son 54 px que se suman siempre, así
que la predicción caía por debajo del hueco incluso flotando quieto en el
centro. La gravedad es justo lo que el aleteo viene a compensar.

## Una hipótesis que se probó y salió que no
Parecía evidente que frenar los aleteos del bot tenía que ayudar: más de
cuatro aleteos en 1,2 s es fatiga (T-049) y recorta el impulso, y cada aleteo
gasta 10 de 100 de aliento (T-048). Se añadió una cadencia mínima entre
aleteos y **el barrido dice que no sirve de nada**: sin freno, 15,07 de media;
con 20 frames de freno, bastante menos.

La explicación es que el bot ya se frena solo. Solo aletea cuando se ve por
debajo del objetivo, y un aleteo lo sube 60 px de golpe, así que pasa un buen
rato sin necesitar otro. La fatiga nunca llega a morder.

La perilla se queda en 1 (sin freno) y documentada, porque una hipótesis
descartada con datos vale más que un hueco donde alguien la vuelva a tener.

## Un bug que encontró el calibrado, y una calibración que hubo que tirar
Partidas que terminaban en **1 frame con 0 puntos**. `READY` libera las
tuberías de la partida anterior con `queue_free()`, que no borra hasta el final
del frame; encadenar `READY` y `PLAYING` sin un frame por medio dejaba las
tuberías viejas en el árbol durante el primer frame de la partida nueva,
matando a Flapo antes de empezar.

Solo afecta a quien encadena estados por código —el bot y algún test—, no al
juego, donde entre `READY` y `PLAYING` siempre pasa al menos un frame porque
hay un humano pulsando.

Pero contaminó **los tres primeros barridos enteros**, y con ellos la primera
calibración: con partidas que morían al nacer metidas en cada media, el
barrido señaló como ganadora una cadencia de 28 frames y una media de 5,43.
Con los datos limpios, esa configuración es de las peores.

Lo que destapó el error no fue leer el código: fue **romperlo a propósito**.
Al comprobar que el test detectaba un bot sin cadencia, el bot roto puntuó
casi el doble que el calibrado. Un test que no se valida rompiendo no habría
dicho nada, y la ADR estaría ahora afirmando lo contrario de lo que pasa.

## Calibrado
Barrido sobre anticipación × dónde apunta × cadencia, y **validación en
semillas distintas de las del barrido** (2000-2029, treinta partidas): 17,30
de media dentro de la muestra contra 15,07 fuera.

Ganador: anticipación 0,03 s, apuntar a media subida de aleteo por debajo del
centro, sin cadencia.

## Consecuencias
- La línea base vive en `docs/perf.md`. Lo que importa no es el número, es
  cómo se mueve al tocar `GameConfig`.
- `tests/run.sh` no lo ejecuta: 200 partidas tardan minutos y lo que devuelve
  es una medida, no un veredicto. Sí **compila** `tools/`, para que la
  herramienta no se pudra sin que nadie se entere.
- El test de `tests/` comprueba que la herramienta sirve —que el bot juega,
  que la medida es repetible y que el informe sale—, no la calidad de la curva.
