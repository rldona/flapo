# ADR-0031 — `GameSession`: sacar de `Main` lo que no es el bucle de juego

Fecha: 2026-09-08 · Estado: aceptada · Reorganiza [ADR-0005](ADR-0005-main-cablea.md)

## Contexto
`Main` nació con un trabajo claro (ADR-0005): es quien cablea las piezas y
quien lleva la máquina de estados. "Call down, signal up" — los hijos no se
buscan entre sí, el padre reparte.

La Ola 2 le fue añadiendo otra cosa distinta. T-074 le puso la confianza,
T-078 el modo de dificultad, T-079 el nombre del jugador, T-200 la bandera
del planeo, T-240 la semilla y el generador, T-241 el reto del día, T-242 el
código. Cada ticket, un par de métodos. Al llegar a T-242 **gdlint avisó dos
veces en dos tickets** de que `Main` pasaba de veinte métodos públicos.

La primera vez lo resolví haciendo privados dos métodos. Eso no arreglaba
nada: solo bajaba el número. El problema real es que `Main` había pasado de
"cablea y lleva estados" a "cablea, lleva estados, marca puntos **y** es el
perfil del jugador".

## Decisión
Todo lo que una partida sabe **antes de empezar a jugarse** se va a
`GameSession`: semilla, generador, código, reto del día, nombre, modo de
dificultad y confianza.

El criterio para decidir qué se va es doble, y las siete cosas lo cumplen:

1. **Sale del guardado**, no del juego.
2. **No tiene nada que ver con el bucle**: nada de esto cambia mientras
   Flapo vuela.

Lo que se queda en `Main` es lo que sí es suyo: la máquina de estados, el
cableado de las piezas, la puntuación y la dificultad *aplicada* al mundo.

`GameSession` es un `RefCounted` y no un nodo: no dibuja, no procesa y no
escucha señales. Y **no cambia de estado**: `preparar_reto()` deja la partida
lista, pero quien decide cuándo se pasa a `READY` sigue siendo `Main`. Si la
sesión pudiera cambiar el estado, habría dos sitios desde donde se gobierna
la máquina y volveríamos a empezar.

## Resultado
| | Antes | Después |
|---|---|---|
| Métodos públicos de `Main` | 22 | 13 |
| Líneas de `Main` | ~700 | 652 |

Trece deja sitio para los treinta tickets que quedan de la ola. Veinte no
dejaba ninguno.

## Cómo se comprobó que no cambia nada
Un refactor que cambia el comportamiento sin querer es peor que no haberlo
hecho, y aquí el riesgo era real: se movió el generador de aleatoriedad.

Además de la suite entera en verde, se grabó la **huella determinista** de
una partida con un código fijo —secuencia de tuberías con sus variantes y
frutas con su fase de balanceo— antes y después del refactor, y se comparó.
Idéntica byte a byte. Es la comprobación que corresponde a este cambio
concreto: si el reparto del generador se hubiera roto, la huella se habría
movido aunque todos los tests siguieran pasando.

## Consecuencias
- Los tests hablan con `main.session()`. Es más verboso, y a cambio dice de
  dónde sale cada cosa.
- `Main.set_difficulty()` desaparece de la API pública: el modo lo cambia el
  menú por señal, y ahora los tests usan esa misma ruta en vez de una puerta
  trasera. El test comprueba el camino que recorre el jugador.
- Los tickets que quedan (fantasma, bot, replays) tienen dónde poner lo suyo
  sin volver a empujar contra el linter.
- **El límite del linter no era el problema, era el síntoma.** Bajar el
  número haciendo métodos privados —lo que hice en T-242— fue tapar el aviso.
