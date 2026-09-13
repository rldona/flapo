# Decisiones técnicas (ADR)

Cada decisión relevante se documenta en un fichero `ADR-NNNN-titulo.md` con:
contexto, opciones consideradas, decisión y consecuencias. Una ADR no se edita
cuando cambia la decisión: se escribe una nueva que la sustituye.

La excepción son las **ampliaciones**: cuando un ticket nuevo cae dentro de un
sistema que ya tiene ADR, se le añade una sección en vez de abrir número. Lo
hace ADR-0026 con las térmicas y el rebufo, porque los tres son *aire*.

## Este registro manda sobre los números que dicen los tickets

`TICKETS.md` menciona números de ADR (“ADR-0024 documenta…”). **Esos números
son estimaciones**, escritas cuando se planificó la ola y mucho antes de que
las ADRs existieran. Al escribirlas en otro orden, cinco chocaron: el número
que pedía un ticket ya se lo había llevado otro.

La regla, a partir de ahora:

> **El número se asigna al escribir la ADR, no al escribir el ticket.** Se coge
> el siguiente libre de este registro. Si un ticket pedía otro, se anota aquí y
> la ADR lo dice en su cabecera.

No se renumera nada. Renumerar significaría reescribir enlaces en ADRs,
comentarios de código y mensajes de commit ya publicados, para que un número
coincida con una previsión que se hizo antes de saber qué se iba a escribir.
El coste es real y el beneficio es cosmético.

### Los cinco desvíos

| Ticket | Pedía | Es | Por qué |
|---|---|---|---|
| T-067 · Tramo especial | ADR-0024 | **[ADR-0037](ADR-0037-tramo-especial.md)** | 0024 se la llevó T-057, escrita antes |
| T-076 · Modo espejo | ADR-0023 | **[ADR-0038](ADR-0038-modo-espejo.md)** | 0023 son las tuberías especiales (T-063/T-065/T-066) |
| T-260 · Bot de justicia | ADR-0033 | **[ADR-0035](ADR-0035-bot-de-justicia.md)** | 0033 se la llevó T-087, escrita antes |
| T-203 · Térmicas | ADR-0026 | [ADR-0026](ADR-0026-rafagas-de-viento.md) *(ampliada)* | Es el mismo sistema: el aire |
| T-204 · Rebufo | ADR-0026 | [ADR-0026](ADR-0026-rafagas-de-viento.md) *(ampliada)* | Ídem |

Los dos últimos no son desvíos sino aciertos del ticket: pedía documentar “el
sistema de aire”, y el sistema de aire ya tenía ADR.

### Números reservados y todavía sin escribir

`0028` (reapertura de alcance de los complementos), `0029` (revisión de
ADR-0017 sobre música) y `0034` (PWA, T-280). Están reservados por tickets
pendientes; si al escribirlos siguen libres, se usan, y si no, se aplica la
regla de arriba.

## Índice

| ADR | Decisión |
|---|---|
| [ADR-0001](ADR-0001-motor.md) | Motor y lenguaje: Godot 4 + GDScript |
| [ADR-0002](ADR-0002-escalado-y-render.md) | Escalado de pantalla y método de renderizado |
| [ADR-0003](ADR-0003-gameconfig.md) | Dónde viven las constantes de juego |
| [ADR-0004](ADR-0004-entrada.md) | Gestión de la entrada: acciones del InputMap |
| [ADR-0005](ADR-0005-maquina-de-estados.md) | Máquina de estados y comunicación entre nodos |
| [ADR-0006](ADR-0006-cuerpo-de-flapo.md) | Tipo de cuerpo físico de Flapo |
| [ADR-0007](ADR-0007-verificacion-headless.md) | Verificación headless desde el día uno |
| [ADR-0008](ADR-0008-tuberias.md) | Tuberías: cuerpo, ciclo de vida y aleatoriedad |
| [ADR-0009](ADR-0009-gameconfig-sin-autoload.md) | `GameConfig` deja de ser autoload |
| [ADR-0010](ADR-0010-suelo.md) | Suelo: scroll infinito y colisión quieta |
| [ADR-0011](ADR-0011-reinicio.md) | Reinicio en sitio, sin recargar la escena |
| [ADR-0012](ADR-0012-fase3-game-feel.md) | Game feel: dónde vive el jugo y cómo se mide |
| [ADR-0013](ADR-0013-persistencia.md) | Persistencia: `SaveManager` sin autoload |
| [ADR-0014](ADR-0014-pantallas-y-pausa.md) | Pausa y adaptación a pantallas reales |
| [ADR-0015](ADR-0015-tamano-de-flapo.md) | Flapo pasa de 16×12 a 24×24 |
| [ADR-0016](ADR-0016-arte-generado.md) | El arte que no es Flapo se genera por código |
| [ADR-0017](ADR-0017-audio.md) | Audio: efectos generados, buses y silencio |
| [ADR-0018](ADR-0018-curva-de-dificultad.md) | Curva de dificultad |
| [ADR-0019](ADR-0019-frutas.md) | Frutas con efectos |
| [ADR-0020](ADR-0020-aliento.md) | Aliento: un recurso de vuelo sin añadir botones |
| [ADR-0021](ADR-0021-progresion-de-confianza.md) | Progresión de confianza: mejorar sin menú de mejoras |
| [ADR-0022](ADR-0022-modos-de-dificultad.md) | Modos de dificultad: una curva, tres escalas |
| [ADR-0023](ADR-0023-tuberias-moviles.md) | Tuberías especiales: móviles, blanditas y giratorias |
| [ADR-0024](ADR-0024-variantes-de-escenario.md) | El cielo sale de la semilla, no del generador |
| [ADR-0025](ADR-0025-layout-adaptativo.md) | Layout adaptativo: un cálculo continuo, no dos layouts |
| [ADR-0026](ADR-0026-rafagas-de-viento.md) | Ráfagas de viento: acotadas al sobre de la curva y siempre anunciadas |
| [ADR-0027](ADR-0027-fin-del-viaje.md) | Un final en un juego infinito, y por qué no es un estado |
| [ADR-0030](ADR-0030-semilla-determinista.md) | Un solo generador: qué garantiza el determinismo y qué no |
| [ADR-0031](ADR-0031-game-session.md) | `GameSession`: sacar de `Main` lo que no es el bucle de juego |
| [ADR-0032](ADR-0032-fantasma-del-record.md) | El fantasma graba posiciones, no pulsaciones |
| [ADR-0033](ADR-0033-menu-de-opciones.md) | Un submenú de opciones, y qué entra en él |
| [ADR-0035](ADR-0035-bot-de-justicia.md) | Qué garantiza el bot de justicia y qué no |
| [ADR-0036](ADR-0036-replay-determinista.md) | Un replay es la semilla, las entradas **y el perfil del jugador** |
| [ADR-0037](ADR-0037-tramo-especial.md) | El tramo especial celebra, no examina |
| [ADR-0038](ADR-0038-modo-espejo.md) | El modo espejo: una excepción más a "modos de juego fuera de v1" |
| [ADR-0039](ADR-0039-captura-del-mejor-salto.md) | La captura se compone, no se fotografía |
| [ADR-0040](ADR-0040-tramos-del-viaje.md) | Cuatro capas que siempre existen |
