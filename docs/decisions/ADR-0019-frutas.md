# ADR-0019 — Frutas con efectos

Fecha: 2026-09-08 · Estado: aceptada · Modifica el alcance fijado en `docs/GDD.md`

## Contexto
Raúl pidió frutas flotantes que dan privilegios y penalizaciones: azul
inmunidad, roja el doble de peso, verde el doble de ligero, naranja el doble
de tamaño, violeta más lento.

**El GDD dejaba los power-ups explícitamente fuera de v1.** Esta ADR cambia
esa decisión, tomada en la Fase 1 antes de que existiera ningún juego, y lo
hace a sabiendas: retrasa la publicación a cambio de que v1 salga con más
sustancia.

## El problema de diseño, y cómo se resuelve
De las cinco frutas, tres son premios y dos son castigos. Un castigo evitable
no lo coge nadie, y uno inevitable no es una fruta: es un obstáculo disfrazado
de recompensa. Eso el jugador lo lee como injusto, que es justo lo contrario
de lo que pide el GDD ("se ríe contigo, nunca de ti").

Se barajaron cuatro salidas: frutas todas iguales hasta cogerlas, castigos que
dan puntos, quitar los castigos, o ponerlos en el camino óptimo.

**Decisión: los castigos pagan en puntos** (+3 por defecto). Coger una roja te
da tres puntos y seis segundos de Flapo pesado. Deja de ser una trampa y pasa
a ser una apuesta: la coges cuando vas sobrado y la esquivas cuando vas justo.

## Reglas de composición
Elegidas para que el jugador sepa siempre en qué estado está sin leer nada:

- **Un solo efecto temporal a la vez.** Coger una fruta sustituye el anterior
  y reinicia el reloj. Verde y luego roja deja "pesado", no "normal": nada de
  cancelaciones que haya que deducir.
- **El escudo va aparte y no caduca.** Es una carga que se gasta al chocar, y
  convive con cualquier efecto.
- **Seis segundos** de duración, y el HUD enseña cuál está activo y cuánto
  queda. Un efecto invisible es un efecto que el jugador cree que es un bug.

## Detalles que costaron pensar

### La velocidad se multiplica, no se sustituye
La fruta violeta no fija una velocidad: multiplica. La velocidad real es
`curva_de_dificultad(puntuación) × modificador`. Si la fijara, coger una
violeta a los 30 puntos rebajaría el juego al nivel de salida y, al caducar,
volvería de golpe a la máxima: un salto que se siente como un fallo.

### La fruta naranja agranda el dibujo más que la hitbox
El dibujo va al doble (×2), la hitbox solo a ×1,6. Es deliberado y coherente
con el resto del juego, donde la hitbox ya es más pequeña que Flapo: parecer
enorme da la tensión, y el margen extra evita que la fruta sea una condena.

### La naranja deja de salir cuando el hueco se estrecha
Con el hueco en su mínimo (82 px) y Flapo al doble, no habría forma humana de
pasar. El spawner deja de ofrecerla por debajo de 90 px de hueco, lo que en la
práctica significa a partir de unos 22 puntos. Hay test.

### El escudo apaga las colisiones un segundo
Sobrevivir a un golpe no basta: Flapo sigue **dentro** de la tubería con la
que acaba de chocar y moriría en el frame siguiente. Al gastar el escudo deja
de colisionar durante un segundo, tiempo de sobra para que la tubería lo
rebase.

### Las frutas nacen entre tuberías
A mitad de camino entre dos, y en la franja central de la altura jugable. Así
son **siempre alcanzables y siempre esquivables**, que es lo que las convierte
en una decisión. Una fruta pegada a un tubo no se decide, se sufre.

## Consecuencias
- La paleta pasa de 16 a **20 colores**. Los cuatro nuevos son tonos que el
  escenario no usa, y eso es justo lo que hace que las frutas se lean como
  objetos ajenos al mundo y no como decorado.
- Dos sonidos nuevos. El de fruta mala tiene que reconocerse como "algo ha
  ido mal" sin sonar a muerte, o el jugador cree que ha perdido.
- La hitbox de Flapo deja de venir del `.tscn` y se **duplica** en `_ready()`:
  un sub-recurso de escena es el mismo objeto en todas las instancias
  (ADR-0008), y ahora se redimensiona.
- Los efectos no cruzan partidas: `Effects.clear()` al volver a `READY`.
- Queda por decidir jugando: la probabilidad de fruta (45 % por hueco), la
  duración (6 s) y los puntos del castigo (3). Los tres son `@export`.
