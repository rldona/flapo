# ADR-0021 — Progresión de confianza: mejorar sin menú de mejoras

Fecha: 2026-09-08 · Estado: aceptada · Depende de [ADR-0013](ADR-0013-guardado.md) y [ADR-0020](ADR-0020-aliento.md)

## Contexto
El GDD lleva desde el principio una lista de **fuera de alcance en v1**:
"skins, ranking online, anuncios, compras, modos de juego". T-074 pide que
Flapo "vaya cogiendo el truco" según se juega, y a primera vista eso suena
justo a lo que esa lista excluye: meta-progresión, mejoras, desbloqueables.

Merece una ADR precisamente porque es el tipo de decisión que, tomada sin
pensar, mete un sistema entero de economía y menús en un juego de un botón.

## El problema con la meta-progresión
Una progresión comprada —monedas, tienda, elegir mejora— cambia el juego de
sitio: parte del tiempo del jugador deja de estar en el vuelo y pasa a estar
en una pantalla decidiendo. En un juego cuya partida dura veinte segundos,
esa pantalla pesa más que el juego. Y trae detrás una cola larga: balance de
economía, botón de reinicio de datos, tentación de vender monedas.

También cambia el tono. Flapo no es un pájaro que compra mejoras; es un
pájaro gordito que insiste hasta que le sale.

## Decisión
Progresión **derivada, pequeña, con tope y automática**:

- Se cuentan **partidas jugadas, no puntos**. Mejora quien insiste, no quien
  ya juega bien: al que se le da mal es justo el que necesita la ayuda.
- Cada `CONFIDENCE_STEP` (10) partidas sube un escalón, con tope en
  `CONFIDENCE_MAX_LEVEL` (5). A las 50 partidas se acabó.
- El único efecto es **+`CONFIDENCE_BREATH_BONUS` (8) de `MAX_BREATH`** por
  escalón: de 100 a 140 en el tope. Ver la tabla de abajo.
- **No hay menú, ni moneda, ni elección, ni mensaje de "¡has subido de
  nivel!"**. Lo que el jugador ve es que la barra de aliento es un poco más
  larga que hace unos días.

Todo se deriva de un entero guardado: `confidence` en la misma sección del
`user://save.cfg` que el récord (ADR-0013). `GameConfig.confidence_level()` y
`max_breath_for()` son funciones puras, como el resto de la progresión del
juego (ADR-0018), así que no hay estado que sincronizar.

| Partidas | Escalón | `MAX_BREATH` |
|---|---|---|
| 0–9 | 0 | 100 |
| 10–19 | 1 | 108 |
| 30–39 | 3 | 124 |
| 50 y más | 5 (tope) | **140** |

## Por qué el aliento y no la fatiga
T-074 daba a elegir entre subir `MAX_BREATH` o rebajar la penalización de
fatiga. Se elige el aliento por dos razones:

1. **Se ve.** El aliento tiene una barra en el HUD (T-048); la fatiga es un
   tinte de esa misma barra. Una progresión que no se percibe no es una
   progresión, es un número en un fichero.
2. **Es medible.** Tocar las dos palancas a la vez haría imposible saber
   cuál de las dos cambió el juego cuando toque tunear (T-040).

Y sobre todo: el aliento **solo compra planeo**, que es la herramienta
opcional. Aletear no mejora nunca. La progresión no toca el control.

## Por qué se guarda el escalón además de las partidas
Es redundante: el escalón se puede calcular de `games_played`. Se guarda
igualmente porque un día se podría subir `CONFIDENCE_STEP`, y entonces quien
ya había llegado al escalón 3 se despertaría en el 2. `record_game()` se
queda con el **máximo** entre lo guardado y lo que tocaría. La progresión
nunca va hacia atrás, que es lo único que un jugador no perdona.

## Consecuencias
- **No contradice "fuera de alcance en v1"**: no es una compra, ni un
  desbloqueable, ni una pantalla. La lista se mantiene tal cual.
- Un jugador nuevo y uno de 50 partidas juegan al **mismo juego**: misma
  curva de dificultad, mismo impulso, mismas tuberías. Solo cambia cuánto
  puede planear.
- El récord deja de ser perfectamente comparable entre sesiones muy
  separadas en el tiempo. Se acepta: el récord es contra uno mismo, y el que
  llega a 50 partidas ha ganado esos 40 puntos de aliento jugando.
- El tope es una decisión de diseño, no una limitación técnica: un juego que
  mejora sin límite acaba jugándose solo.
- Si `CONFIDENCE_BREATH_BONUS` se subiera "solo un poco", la progresión
  dejaría de ser pequeña. `tests/test_t074_confianza.gd` asegura que el tope
  no llega a multiplicar por 1,5 el aliento inicial.
