# Tickets — Flapo

Cada ticket es una issue de GitHub. Formato: `### T-NNN · Título` seguido de metadatos y cuerpo. El script `scripts/create_issues.py` los crea automáticamente.

Estimación en puntos (1 = ~1 h, 2 = media tarde, 3 = una tarde, 5 = dos tardes).
Labels: `fase:N`, `area:code|art|audio|docs|ci|qa|release`.
Milestone = fase.

Los tickets **T-2xx** son la *ola 2*: cuarenta ideas para que Flapo no sea un Flappy más. Van dentro de la fase que les corresponde (el label `fase:N` manda, no el número) y siguen las mismas reglas: un ticket por vez, test en `tests/` para lo que headless puede ver, ADR para cada decisión que lo merezca.

---

## Fase 0 — Preparación

### T-001 · Instalar y verificar el entorno
labels: fase:0, area:docs · estimate: 1
Instalar Godot 4.x estable, Pixelorama y Audacity. Verificar que Godot abre un proyecto vacío y exporta a Web (descargar export templates).
**Criterios de aceptación**
- Godot arranca y exporta un proyecto vacío a HTML5 sin errores.
- Versiones anotadas en `docs/environment.md`.

### T-002 · Crear estructura del repositorio
labels: fase:0, area:docs · estimate: 1
Crear el repo público con la estructura definida en `ROADMAP.md`, `.gitignore` de Godot 4, `LICENSE` (MIT) y `README.md` inicial.
**Criterios de aceptación**
- Carpetas `assets/`, `scenes/`, `scripts/`, `docs/`, `.github/workflows/` existen (con `.gitkeep`).
- `.godot/` y `export/` ignorados; `*.import` versionado.
- El repo clona y abre en Godot sin advertencias.

### T-003 · README inicial
labels: fase:0, area:docs · estimate: 1
Redactar README con descripción, estado, cómo ejecutar, cómo contribuir, licencias y créditos de assets de terceros.
**Criterios de aceptación**
- Secciones: Qué es · Estado · Ejecutar · Contribuir · Licencia · Créditos.
- Enlaza a `ROADMAP.md` y `docs/GDD.md`.

### T-004 · ADR-0001: elección de motor y lenguaje
labels: fase:0, area:docs · estimate: 1
Documentar por qué Godot 4 + GDScript frente a Unity/Unreal/Phaser, usando plantilla ADR (contexto, decisión, consecuencias).
**Criterios de aceptación**
- `docs/decisions/ADR-0001-motor.md` con la plantilla completa.
- `docs/decisions/README.md` explica el proceso ADR.

### T-005 · Plantillas de issue y PR
labels: fase:0, area:docs · estimate: 1
Añadir `.github/ISSUE_TEMPLATE/task.md`, `bug.md` y `PULL_REQUEST_TEMPLATE.md` (descripción, cómo probar, GIF si cambia algo visible).
**Criterios de aceptación**
- Al crear una issue en GitHub aparecen las plantillas.

### T-006 · Verificación headless
labels: fase:0, area:qa · estimate: 2
Godot admite `--headless` y `-s script.gd`: el juego se puede comprobar desde la terminal sin ventana ni GPU. Montar un arnés mínimo en `tests/` y documentarlo, para que los criterios de aceptación se cierren con evidencia ejecutable en vez de con inspección manual.
**Criterios de aceptación**
- `./tests/run.sh` ejecuta todos los `tests/test_*.gd` y sale con 0 solo si pasan.
- `docs/testing.md` explica cómo ejecutar, cómo escribir un test y qué NO cubre.
- ADR-0007 y `CLAUDE.md` reflejan el nuevo reparto de responsabilidades.

---

## Fase 1 — Diseño

### T-010 · Redactar el GDD de una página
labels: fase:1, area:docs · estimate: 2
Escribir `docs/GDD.md`: pitch, bucle central, reglas con valores iniciales, estados, controles, feedback, fuera de alcance v1.
**Criterios de aceptación**
- Cabe en una página impresa.
- Incluye tabla de constantes: gravedad, impulso, velocidad de scroll, separación y hueco de tuberías.
- Lista explícita de "no en v1".

### T-011 · Definir estilo visual y paleta
labels: fase:1, area:art · estimate: 1
Elegir paleta de 16 colores (Lospec), resolución base 288×512, tamaños de sprites (pájaro 16×12, tubería 26 px ancho, tile suelo 32 px).
**Criterios de aceptación**
- `docs/art-guide.md` con la paleta (hex), tamaños y reglas (sin AA externo, outline 1 px oscuro).
- Archivo `.gpl`/`.hex` de la paleta en `assets/sprites/src/`.

---

## Fase 2 — Prototipo jugable

### T-020 · Configuración del proyecto
labels: fase:2, area:code · estimate: 1
Ajustar `project.godot`: resolución 288×512, stretch `viewport` + `integer`, orientación vertical, filtro de texturas `Nearest` por defecto, física a 60 Hz.
**Criterios de aceptación**
- La ventana escala sin píxeles deformados en 1x, 2x y 3x.

### T-021 · InputMap unificado
labels: fase:2, area:code · estimate: 1
Acción `flap` mapeada a click izquierdo, toque de pantalla y espacio. Acción `restart` y `pause`.
**Criterios de aceptación**
- El código nunca consulta teclas directamente, solo acciones.

### T-022 · Escena Main y máquina de estados
labels: fase:2, area:code · estimate: 2
`Main.tscn` con `GameState` enum `READY / PLAYING / GAME_OVER` y transiciones mediante señales.
**Criterios de aceptación**
- Cambiar de estado emite señal `state_changed`.
- En `READY` el pájaro flota sin gravedad; al pulsar `flap` pasa a `PLAYING`.

### T-023 · Bird: física y control
labels: fase:2, area:code · estimate: 2
`Bird.tscn` (`CharacterBody2D`): gravedad, impulso en `flap`, rotación proporcional a la velocidad vertical, tope superior de pantalla.
**Criterios de aceptación**
- Constantes exportadas (`@export`) para tunear desde el editor.
- No puede salir por arriba; al caer muere en el suelo.

### T-024 · Pipe: par de tuberías con hueco
labels: fase:2, area:code · estimate: 2
`Pipe.tscn` con tubería superior e inferior, hueco configurable y posición vertical aleatoria dentro de un rango. Se mueve a velocidad de scroll y se libera (`queue_free`) al salir por la izquierda.
**Criterios de aceptación**
- Hueco y rango como `@export`.
- No quedan nodos huérfanos tras 5 minutos (monitor de nodos estable).

### T-025 · PipeSpawner
labels: fase:2, area:code · estimate: 1
`Timer` que instancia `Pipe` cada N segundos solo en `PLAYING`; se detiene en `GAME_OVER`.
**Criterios de aceptación**
- Intervalo y velocidad centralizados en un `GameConfig` (autoload o resource).

### T-026 · Zona de puntuación
labels: fase:2, area:code · estimate: 1
`Area2D` entre tuberías; al atravesarla el pájaro emite `scored`. Contador en `Main`.
**Criterios de aceptación**
- Una sola puntuación por tubería, aunque el pájaro oscile.

### T-027 · Suelo con scroll infinito
labels: fase:2, area:code · estimate: 1
Dos sprites de suelo que se desplazan y se recolocan; `StaticBody2D` para colisión.
**Criterios de aceptación**
- Sin salto visible al reciclar.

### T-028 · Muerte, Game Over y reinicio
labels: fase:2, area:code · estimate: 2
Colisión con tubería/suelo → `GAME_OVER`. Overlay con puntuación y botón/acción `restart` que recarga la escena limpiamente.
**Criterios de aceptación**
- Reiniciar 50 veces seguidas no acumula nodos ni timers.

### T-029 · HUD de puntuación
labels: fase:2, area:code · estimate: 1
`CanvasLayer` con `Label` centrado; se actualiza con la señal `scored`.
**Criterios de aceptación**
- Visible en `PLAYING`, oculto en `READY`, sustituido por panel en `GAME_OVER`.

### T-030 · Sesión de prueba del prototipo
labels: fase:2, area:qa · estimate: 1
Jugar 5 minutos, anotar bugs como issues `bug`, grabar un GIF para `docs/`.
**Criterios de aceptación**
- Cero bugs bloqueantes abiertos al cerrar la fase.

---

## Fase 3 — Game feel

### T-063 · Tuberías con movimiento vertical
labels: fase:3, area:code · estimate: 3
A partir de cierta puntuación (`MOVING_PIPE_MIN_SCORE` en `GameConfig`), algunos pares de tuberías oscilan arriba/abajo despacio dentro de un rango que sigue dejando el hueco completo dentro de pantalla. Son `StaticBody2D` (ADR-0008): mover su `position` cada frame no rompe la colisión, pero hay que decidir si necesitan `constant_linear_velocity` para que `move_and_slide()` de Flapo las trate bien en un roce — documentarlo en la ADR.
**Criterios de aceptación**
- El rango de oscilación nunca saca el hueco de la zona jugable (`playable_height()`), en toda la curva de dificultad.
- Probabilidad de que un par sea móvil como función pura de la puntuación, igual que el resto de la curva (T-045).
- Test en `tests/` que compruebe que el hueco oscilante nunca se sale de los límites y que a puntuación baja nunca aparecen (no rompe la rampa de entrada de T-046).
- ADR-0023 documenta la decisión de física y cómo convive con ADR-0008 y ADR-0018.
- Raúl revisa que el movimiento se lee bien en el navegador y no se siente injusto.

### T-064 · Ráfagas de viento
labels: fase:3, area:code · estimate: 3
Tramos puntuales (`Timer` global, no por tubería) donde `SCROLL_SPEED` efectivo sube o baja un `WIND_FACTOR` durante unos segundos, siempre anunciados visualmente (parallax/partículas) al menos `WIND_WARNING_TIME` s antes de que empiece.
**Criterios de aceptación**
- El viento nunca lleva el scroll fuera de `[SCROLL_SPEED, SCROLL_SPEED_MAX]` combinado con la curva de dificultad ya existente.
- Test en `tests/` que compruebe el aviso previo y que el factor de viento se deshace solo al terminar el tramo.
- Raúl revisa en el navegador que el aviso da tiempo real a reaccionar.

### T-065 · Tubería giratoria
labels: fase:3, area:code · estimate: 2
Variante visual: un par de tuberías especial gira despacio sobre su propio eje sin cambiar el hueco real de colisión (el giro es del sprite, no de la hitbox) — más barato y más justo que mover el hueco físico.
**Criterios de aceptación**
- La hitbox de colisión no cambia por el giro; solo el dibujo.
- Test en `tests/` que compruebe que la puntuación y la colisión son idénticas con y sin la variante giratoria activada.
- Raúl revisa que el giro se distingue de las tuberías normales de un vistazo.

### T-066 · Tubería "blandita"
labels: fase:3, area:code · estimate: 2
Cada `SOFT_PIPE_INTERVAL` tuberías (no aleatorio: predecible para que se pueda buscar a propósito), una tubería identificable visualmente que al tocarla no mata: rebota a Flapo y le cuesta aliento/puntos en vez de la partida. Coherente con "nunca burla, nunca castigo total" del GDD.
**Criterios de aceptación**
- Visualmente distinguible de una tubería normal desde que entra en pantalla, no solo al chocar.
- Test en `tests/` que compruebe que tocarla no dispara `GAME_OVER` y sí aplica el coste definido.
- ADR-0023 recoge esta variante junto con T-063 (mismo sistema de tuberías especiales).
- Raúl revisa el feedback de rebote en el navegador.

### T-067 · Tramo especial al superar récord
labels: fase:3, area:code · estimate: 2
Depende de T-063, T-064, T-065, T-066. Al superar el récord guardado, el siguiente tramo combina 2-3 de los gimmicks anteriores a la vez y cambia el color de las tuberías para que se note que es especial (celebración/reto, no un muro de dificultad).
**Criterios de aceptación**
- Solo se activa una vez por partida, justo tras superar el récord de esa sesión.
- Test en `tests/` que compruebe que el tramo especial no se dispara si no se ha superado el récord.
- ADR-0024 documenta por qué combinar gimmicks aquí y no en cualquier momento (evitar que se sienta injusto fuera de este contexto).
- Raúl revisa el ritmo del tramo en el navegador: debe notarse especial, no imposible.

### T-040 · Tuning de constantes
labels: fase:3, area:code · estimate: 2
Iterar gravedad/impulso/velocidad/hueco hasta que el salto sea legible y transmita el peso de Flapo (ver GDD, Concepto y tono). Registrar valores finales en el GDD.
**Criterios de aceptación**
- Tabla del GDD actualizada con valores finales y por qué.

### T-045 · Curva de dificultad
labels: fase:3, area:code · estimate: 2
La dificultad sube con la puntuación: velocidad de scroll y hueco de las tuberías, con tope. Funciones puras de la puntuación en `GameConfig`, empujadas por `Main` a cada sistema.
**Criterios de aceptación**
- Con 0 puntos salen exactamente los valores del GDD.
- La velocidad nunca baja y el hueco nunca crece al subir la puntuación.
- **Nunca caben menos de 3 aleteos entre tuberías** en ninguna puntuación.
- Reiniciar devuelve la dificultad inicial.

### T-047 · Frutas con efectos
labels: fase:3, area:code · estimate: 5
Frutas flotantes entre tuberías con cinco efectos: inmunidad, pesado, ligero, grande y lento. Sistema de efectos temporales, spawner, arte, audio y HUD.
**Criterios de aceptación**
- Un solo efecto temporal a la vez; el escudo va aparte y no caduca.
- Las frutas de castigo dan puntos.
- La fruta que agranda a Flapo no sale cuando el hueco es estrecho.
- El escudo absorbe un golpe y solo uno.
- Ni las frutas ni sus efectos sobreviven a un reinicio.
- El HUD enseña qué efecto está activo y cuánto le queda.

### T-048 · Aliento: recurso de vuelo
labels: fase:3, area:code · estimate: 3
Reinterpreta el único botón sin añadir inputs: pulsación corta sigue siendo el aleteo actual (impulso fijo, ADR-0006); mantener pulsado activa **planeo** (cae despacio en vez de con gravedad completa). Ambos gastan `breath` (planear más despacio que aletear); `breath` se recupera pasando por la franja central del hueco entre tuberías. A `breath` 0 el planeo deja de frenar la caída, pero el aleteo corto sigue funcionando siempre: nunca se queda sin poder aletear.
**Criterios de aceptación**
- `GameConfig` expone `MAX_BREATH`, `BREATH_DRAIN_FLAP`, `BREATH_DRAIN_GLIDE`, `BREATH_RECOVER_ON_GAP`, documentadas como el resto (valor + por qué).
- Test en `tests/` que simule aletear y planear y compruebe que `breath` sube y baja dentro de `[0, MAX_BREATH]`.
- HUD muestra el nivel de aliento sin tapar la puntuación.
- ADR-0020 documenta por qué se reabre el modelo de física de ADR-0006 y cómo convive con `bird.gd`.
- `docs/GDD.md` actualizado con la regla y sus constantes.

### T-049 · Fatiga por aleteo sin pausa
labels: fase:3, area:code · estimate: 2
Depende de T-048. Aletear muchas veces seguidas sin planear ni recuperar aliento (más de `FATIGUE_FLAP_COUNT` aleteos en menos de `FATIGUE_WINDOW` s) reduce el impulso del siguiente aleteo un `FATIGUE_PENALTY` %; se recupera planeando una vez o dejando pasar el tiempo. Nunca deja a Flapo sin control, solo penaliza machacar el botón.
**Criterios de aceptación**
- Constantes en `GameConfig` como función pura del historial de aleteos, no estado oculto en `bird.gd`.
- Test en `tests/` que simule una ráfaga de aleteos y compruebe la reducción de impulso y su recuperación.
- `tools/medir_feel.gd` reporta también el caso de aleteo fatigado.
- Recogido en ADR-0020 (junto con T-048).

<!-- Renumerado: este ticket entró como T-050, número que ya usaba
     "Sprite de Flapo" en la Fase 4 y que está referenciado en ADR-0015 y en
     el historial de commits. Pasa a T-056, el primero libre. -->

### T-056 · Reacciones variables al morir
labels: fase:3, area:code|docs · estimate: 2
Cada Game Over elige al azar (sin repetir la última) una frase corta de una lista, coherente con "Concepto y tono" del GDD: ánimo torpe, nunca burla. Sustituye el texto fijo actual de la pantalla de Game Over.
**Criterios de aceptación**
- ≥8 frases en un recurso de datos propio, no hardcodeadas en la escena, fácil de ampliar.
- Test en `tests/` que compruebe que no sale la misma frase dos veces seguidas y que el selector no rompe con una lista de un solo elemento.
- Raúl revisa el tono de las frases: son contenido, no solo código.
- `docs/GDD.md`, sección "Concepto y tono", enlaza al recurso de frases.

### T-046 · Hueco de salida más ancho
labels: fase:3, area:code · estimate: 1
Subir el hueco inicial de 100 a 118 px para que los primeros puntos perdonen más, manteniendo el mínimo de 82 en el tope de la curva.
**Criterios de aceptación**
- El hueco de salida es mayor que el "normal" del género (100 px) y la curva llega a 100 px alrededor de los 15 puntos.
- El hueco cabe entre techo y suelo en todo el rango de sorteo, en toda la curva.

### T-041 · Animación de aleteo
labels: fase:3, area:code · estimate: 1
`AnimatedSprite2D` con 3 frames placeholder; velocidad de animación según estado (más rápida al saltar).
**Criterios de aceptación**
- Animación se pausa al morir.

### T-042 · Feedback de muerte: flash, sacudida y hit-stop
labels: fase:3, area:code · estimate: 2
Flash blanco (ColorRect con tween), sacudida de cámara (offset aleatorio decreciente), pausa de 60-100 ms, rebote de Flapo en el suelo y ojos en espiral (`Engine.time_scale` o timer).
**Criterios de aceptación**
- Intensidades como `@export` en un nodo `Juice`.
- No rompe el reinicio.

### T-043 · Parallax de fondo
labels: fase:3, area:code · estimate: 1
`ParallaxBackground` con 2 capas placeholder (nubes, ciudad) a distintas velocidades.
**Criterios de aceptación**
- Se detiene en `GAME_OVER`.

### T-044 · Transiciones entre estados
labels: fase:3, area:code · estimate: 1
Fundido `READY → PLAYING`, retardo de 0,5 s antes de mostrar Game Over.
**Criterios de aceptación**
- Ninguna transición bloquea la entrada más de 1 s.

#### Ola 2 — innovación

### T-200 · Descubrir el planeo en un segundo
labels: fase:3, area:code · estimate: 2
Depende de T-048. El planeo es la mecánica que ningún clon tiene y hoy nadie la descubre. En `READY`, la primera vez que se juega (flag en `SaveManager`), un pictograma "mantén pulsado" con Flapo planeando en bucle; en la primera partida, si a los 3 huecos no se ha planeado nunca, un aviso de una línea sin pausar. Se apaga solo en cuanto el jugador planea una vez.
**Criterios de aceptación**
- Nunca bloquea la entrada: aletear en `READY` sigue empezando la partida igual que ahora.
- El aviso sale como máximo en las `GLIDE_HINT_MAX_GAMES` primeras partidas (`GameConfig`) y desaparece para siempre tras el primer planeo.
- Test en `tests/` que compruebe el flag persistido, que el aviso no sale tras planear y que un guardado ausente/corrupto cuenta como "primera vez".
- Raúl comprueba en el navegador que el pictograma se lee a 1x y no tapa a Flapo.

### T-201 · Jadeo visible: el aliento se ve en Flapo
labels: fase:3, area:code|art · estimate: 2
La barra de aliento es UI; el aliento tiene que verse en el cuerpo. Por debajo de `BREATH_LOW_RATIO` (0,3): alas temblando (frames alternos más rápidos), mejillas rojas (modulación de color, no sprites nuevos) y gotas de sudor como partículas; a 0, un "¡puf!" de vaho. `CPUParticles2D`, no `GPUParticles2D`: tiene que funcionar en headless (ADR-0007).
**Criterios de aceptación**
- La hitbox no cambia con ningún estado de jadeo.
- Umbrales en `GameConfig`; el estado visual es función pura de `breath`, sin estado propio en `bird.gd`.
- Test en `tests/` que compruebe que el jadeo se activa/desactiva en los umbrales y no queda activo tras reiniciar.
- Raúl revisa en el navegador que el jadeo se nota sin mirar la barra.

### T-202 · Bocanada: feedback al recuperar aliento
labels: fase:3, area:code|audio · estimate: 1
Depende de T-048. Hoy cruzar el hueco por el centro recupera +25 en silencio. Marcar la franja central del hueco con un brillo sutil mientras Flapo se acerca, y al cruzarla: partícula de aire, sonido de inhalación y un tirón visible de la barra. Es lo que enseña la regla sin texto.
**Criterios de aceptación**
- La franja marcada coincide exactamente con `BREATH_BAND_RATIO` (mismo cálculo, no un número duplicado).
- Test en `tests/` que compruebe que la señal `breath_recovered` se emite una sola vez por hueco y solo en la franja.
- Raúl revisa que el brillo no se confunde con una fruta ni con el tramo especial (T-067).

### T-203 · Térmicas: columnas de aire ascendente
labels: fase:3, area:code · estimate: 3
Depende de T-048. Cada `THERMAL_INTERVAL` tuberías aparece entre dos pares una columna vertical de aire caliente, visible por partículas ascendentes (polvo, hojas) desde que entra en pantalla. Dentro, **planear sube** en vez de caer despacio (`THERMAL_LIFT` px/s²); el aleteo no cambia. Es un `Area2D` que avisa a `bird.gd` por señal, igual que las frutas (T-047). Da un segundo uso al planeo: no solo ahorrar, también trepar.
**Criterios de aceptación**
- Dentro de una térmica, planear nunca supera el tope superior de pantalla ni saca a Flapo del control (tope de subida en `GameConfig`).
- Nunca coincide con una tubería móvil (T-063) ni con el tramo especial (T-067): lo garantiza el spawner, no el azar.
- Test en `tests/` que simule planeo dentro y fuera de la térmica y compruebe las velocidades resultantes y que el efecto se retira al salir.
- ADR-0026 documenta el sistema de "aire" (térmicas y rebufo de T-204) y por qué se modela con `Area2D` propio y no con la gravedad de área de Godot.
- Raúl revisa en el navegador que la columna se ve venir con tiempo.

### T-204 · El hermano pasa: estela de rebufo
labels: fase:3, area:code|art · estimate: 3
Depende de T-203 (mismo sistema de aire). Cada `BROTHER_INTERVAL` tuberías, el hermano famoso cruza la pantalla por delante, sin esfuerzo, y deja una estela horizontal que dura `SLIPSTREAM_TIME` s: planear dentro de ella no gasta aliento. No colisiona, no puntúa, no se le alcanza. El chiste es que él pasa y tú aprovechas el rebufo; el humor es con Flapo, nunca contra él (GDD).
**Criterios de aceptación**
- El hermano nunca tapa el hueco que hay que cruzar: su trayectoria sale de la franja jugable del siguiente par.
- Test en `tests/` que compruebe que el drenaje de aliento es 0 dentro de la estela y vuelve a `BREATH_DRAIN_GLIDE` fuera, y que la estela se libera sola.
- ADR-0026 recoge que el hermano es puro escenario (sin física), no un `CharacterBody2D`.
- Raúl revisa el sprite del hermano (esbelto, mismo estilo que Flapo) y que el paso se lee como broma, no como obstáculo.

### T-205 · Racha de huecos centrados: multiplicador
labels: fase:3, area:code · estimate: 2
Cruzar `STREAK_LENGTH` (3) huecos seguidos por la franja central (la misma de T-048) activa un ×2 en los puntos mientras dure la racha; el primer hueco fuera de la franja la rompe sin castigo. Une puntuación y aliento en la misma decisión: ir por el centro paga dos veces.
**Criterios de aceptación**
- El récord y las medallas siguen midiendo tuberías cruzadas; el multiplicador afecta solo a `score`, documentado en `docs/GDD.md`.
- HUD enseña la racha actual sin tapar aliento ni puntuación.
- Test en `tests/` que compruebe activación, mantenimiento y ruptura de la racha, y que reiniciar la pone a 0.
- Raúl revisa que el ×2 se entiende sin leer nada.

### T-206 · "Casi": roces que se celebran
labels: fase:3, area:code · estimate: 2
Pasar a menos de `NEAR_MISS_PX` (4) de una tubería sin tocarla dispara un "¡uf!" (texto flotante, sonido corto, hit-stop de 30 ms) y devuelve `NEAR_MISS_BREATH` (+5) de aliento. La hitbox generosa (ADR-0015) ya crea estos momentos; hoy pasan desapercibidos. Se detecta con un segundo `CollisionShape2D` de radio mayor en un `Area2D` hijo, sin tocar la hitbox de muerte.
**Criterios de aceptación**
- La colisión de muerte no cambia en nada (los tests de T-028 siguen idénticos).
- Un solo "casi" por tubería aunque se roce arriba y abajo.
- Test en `tests/` con trayectorias a 3 px y a 6 px que compruebe cuál dispara el roce.
- Raúl revisa que el "uf" no se confunde con un golpe.

### T-207 · Siesta en READY
labels: fase:3, area:code|art|audio · estimate: 2
Si en `READY` o `MENU` no pasa nada durante `NAP_IDLE_TIME` s (10), Flapo se duerme: ojos cerrados, "z" flotando, ronquido suave. El primer toque le despierta con un sobresalto (frame extra) y **ese toque empieza la partida igual que siempre**: la siesta es puro personaje, no un estado nuevo de la máquina.
**Criterios de aceptación**
- No añade estados a `Main` (ADR-0005): es una animación dentro de `READY`.
- El aleteo de despertar tiene el mismo impulso que uno normal; ningún retardo por encima de los 50 ms del GDD.
- Test en `tests/` que compruebe que la siesta arranca a los `NAP_IDLE_TIME` s, se cancela al primer input y nunca aparece en `PLAYING`.
- Raúl revisa que el ronquido no suena con el juego en segundo plano (T-072 ya pausa).

### T-208 · Eructo propulsor
labels: fase:3, area:code|audio · estimate: 2
Depende de T-047. Comer `BURP_FRUITS` (3) frutas en la misma partida sin morir carga un eructo: el siguiente aleteo tiene impulso ×`BURP_FACTOR` (1,5), onda expansiva de partículas y sonido. Se consume solo, no hay botón extra. Humor de hermano gordito y recompensa por arriesgarse a por las frutas.
**Criterios de aceptación**
- El impulso resultante nunca saca a Flapo por el tope superior en un solo aleteo (cap en `GameConfig`).
- HUD muestra que hay eructo cargado (icono junto al efecto activo de T-047).
- Test en `tests/` que compruebe la carga, el consumo en un solo aleteo y el reset al reiniciar.
- Raúl revisa que el sonido es simpático, no asqueroso (tono del GDD).

### T-209 · Fin del viaje: el nido
labels: fase:3, area:code|art · estimate: 3
A `JOURNEY_END_SCORE` puntos (50) las tuberías paran, el fondo se abre y Flapo llega a un nido donde le espera su hermano: 3 s de escena sin input, una línea ("Ha llegado. Gordo, pero ha llegado.") y la partida **continúa** con la dificultad en tope. Da un final alcanzable a un género que no lo tiene, sin quitar el bucle infinito a quien quiera seguir.
**Criterios de aceptación**
- Durante la escena no se puede morir ni puntuar; al terminar, `PLAYING` sigue con todo intacto (aliento, efectos, racha).
- Se guarda `journey_completed` en `SaveManager`; el menú lo enseña con un nido pequeño junto al récord.
- Test en `tests/` que compruebe que la escena se dispara exactamente a `JOURNEY_END_SCORE`, una vez por partida, y que el spawner reanuda después.
- ADR-0027 documenta por qué un final en un juego infinito y por qué se implementa como pausa del spawner y no como estado nuevo (ADR-0005).
- Raúl revisa la escena en el navegador: tiene que emocionar un poco.

### T-210 · Sombra en el suelo
labels: fase:3, area:code|art · estimate: 1
Una sombra elíptica bajo Flapo, en el suelo, que se encoge y aclara con la altura. Es el truco clásico de plataformas para leer la altura: en un juego donde cada aleteo son 2,4 alturas de Flapo (GDD), ayuda a estimar dónde acabará el salto. Un `Sprite2D` hijo de `Ground` actualizado con la `y` de Flapo, sin física.
**Criterios de aceptación**
- Escala y alpha son funciones puras de la altura, en `GameConfig`.
- La sombra no se dibuja en `GAME_OVER` cuando Flapo está en el suelo.
- Test en `tests/` que compruebe los valores en altura mínima y máxima.
- Raúl decide en el navegador si ayuda o distrae: es una hipótesis de legibilidad y puede caer.

---

## Fase 4 — Arte

### T-057 · Variantes de escenario (clima/hora del día)
labels: fase:4, area:art|code · estimate: 2
Amplía el parallax de fondo (T-052) con 2-3 variantes cosméticas (atardecer, lluvia suave, noche) que se eligen al azar por partida o al superar un récord. No toca dificultad ni física, solo arte y selección aleatoria de las capas ya existentes.
**Criterios de aceptación**
- Al menos 2 variantes además de la actual, con el mismo criterio de paleta del `docs/art-guide.md`.
- Test en `tests/` que compruebe que la variante se elige sin romper el parallax existente y que reiniciar puede cambiarla.
- Raúl revisa que las variantes se leen bien en el navegador tras reexportar.

### T-058 · Compañero silencioso
labels: fase:4, area:code|art · estimate: 2
Un segundo pajarillo (NPC, no jugable, sin colisión) que vuela cerca de Flapo y reacciona a eventos del juego (se asusta al pasar un hueco muy justo, aplaude al conseguir medalla) mediante animaciones simples. No es controlable ni afecta a la puntuación ni a la física.
**Criterios de aceptación**
- No colisiona con tuberías, suelo ni frutas (no es `CharacterBody2D` con colisión activa).
- Test en `tests/` que compruebe que su presencia no altera la puntuación ni el estado de la partida (misma puntuación con y sin él, mismo resultado en `test_t047_frutas.gd` u otro test de referencia).
- Raúl revisa el timing de las reacciones en el navegador: no debe distraer del hueco a cruzar.

### T-050 · Sprite de Flapo (idle + aleteo)
labels: fase:4, area:art · estimate: 3
3 frames 16×12 con la paleta del proyecto. Silueta redonda con tripa y alas pequeñas; aleteo exagerado (ver GDD, Concepto y tono). Fuente `.pxo` en `assets/sprites/src/`, PNG exportado en `assets/sprites/`.
**Criterios de aceptación**
- Silueta legible a 1x sobre fondo claro y oscuro.
- Hitbox ajustada al nuevo sprite (ligeramente menor que el dibujo).

### T-051 · Tubería
labels: fase:4, area:art · estimate: 1
Cuerpo repetible (`NinePatchRect` o `TextureRect` en modo tile) + cabeza.
**Criterios de aceptación**
- Se estira a cualquier altura sin deformar la cabeza.

### T-052 · Suelo y fondo
labels: fase:4, area:art · estimate: 2
Tile de suelo 32 px, cielo, nubes, silueta de ciudad para las capas de parallax.
**Criterios de aceptación**
- Tiles enlazan sin costura.

### T-053 · UI: números, botones, logo, medallas
labels: fase:4, area:art · estimate: 2
Fuente de números (sprite font o BitmapFont), botón "Otra vez", logo con la tripa como O, medallas croqueta/tortilla/jamón.
**Criterios de aceptación**
- Botones ≥ 48 px en móvil tras el escalado.

### T-054 · Icono y splash
labels: fase:4, area:art · estimate: 1
Icono 512×512 (y adaptativo Android), splash con fondo de paleta.
**Criterios de aceptación**
- Configurados en `project.godot` y en el preset de Android.

### T-055 · Sustituir placeholders e importación
labels: fase:4, area:code · estimate: 1
Cambiar todas las texturas, confirmar filtro `Nearest` y sin mipmaps en cada import.
**Criterios de aceptación**
- `grep` de "placeholder" en `scenes/` devuelve 0 resultados.

#### Ola 2 — innovación

### T-220 · Expresiones de Flapo
labels: fase:4, area:art|code · estimate: 2
Cara según lo que pasa, sin sprites completos nuevos: una capa de ojos y boca (`Sprite2D` hijo con hoja de 8×8) que se combina con los 3 frames de aleteo. Estados: decidido (por defecto), asustado (tubería a menos de 40 px), feliz (punto), agotado (aliento bajo, T-201), dormido (T-207). Tamaños según `docs/art-guide.md`.
**Criterios de aceptación**
- Fuente `.pxo` de la hoja de caras en `assets/sprites/src/`.
- La expresión es función pura del estado del juego, con prioridad documentada (asustado gana a todo, agotado gana a feliz).
- Test en `tests/` que compruebe la prioridad de expresiones.
- Raúl revisa que las caras se leen a 1x y son Flapo, no un emoji.

### T-221 · Tuberías con cara
labels: fase:4, area:art|code · estimate: 2
Una de cada `FACE_PIPE_EVERY` tuberías lleva una cara pintada en la cabeza que reacciona: mueca cuando Flapo roza (T-206), bostezo si pasa lejos, ojos cerrados al chocar. Solo cambia el sprite de la cabeza (T-051); la hitbox no.
**Criterios de aceptación**
- Hitbox y puntuación idénticas con y sin cara (mismo test de referencia que T-065).
- Las caras nunca burlan (GDD): susto sí, risa no.
- Test en `tests/` que compruebe que cada reacción se dispara con la señal correcta.
- Raúl revisa las caras: son personaje.

### T-222 · Tramos del viaje: parque, tejados, nubes, cielo
labels: fase:4, area:art|code · estimate: 3
Depende de T-057 y T-209. El fondo cambia cada `JOURNEY_STAGE_SCORE` puntos (parque → tejados → nubes → cielo abierto, con el nido de T-209 al final), con fundido del parallax, no de golpe. Convierte "cuántas tuberías" en "hasta dónde he llegado": el paisaje dice lo cerca que está el récord.
**Criterios de aceptación**
- Las capas nuevas usan la paleta del proyecto y se generan con `tools/generar_arte.py` como el resto (ADR-0016).
- El tramo es función pura de la puntuación; reiniciar vuelve al parque.
- Test en `tests/` que compruebe los umbrales y que la transición no deja capas huérfanas.
- Raúl revisa que el cambio de tramo se nota sin distraer del hueco.

### T-223 · Reloj real: el cielo del juego es el de fuera
labels: fase:4, area:code · estimate: 1
Depende de T-057. Sin ajuste manual, la variante de escenario sigue la hora del dispositivo (`Time.get_time_dict_from_system()`): amanecer, día, atardecer, noche. La selección aleatoria de T-057 queda como opción (`SCENERY_MODE` en `GameConfig`).
**Criterios de aceptación**
- Umbrales horarios en `GameConfig`; si la partida cruza la hora, fundido en vivo, no corte.
- Test en `tests/` con la hora inyectada (nunca la del sistema) que compruebe cada franja.
- Raúl lo abre de noche y de día.

### T-224 · La ciudad reacciona
labels: fase:4, area:art|code · estimate: 2
Depende de T-052. Detalles en la capa de ciudad que responden a la partida: ventanas que se encienden con cada punto, un vecino que asoma y aplaude en cada medalla, cortinas que se cierran al morir. Sprites pequeños sobre el parallax, sin lógica de juego.
**Criterios de aceptación**
- Ninguna reacción toca `Main` ni la física: escuchan señales existentes (`scored`, `medal_earned`, `died`).
- Test en `tests/` que compruebe que las reacciones se disparan con las señales y no dejan nodos tras reiniciar.
- Raúl revisa que no roban la atención al hueco.

### T-225 · Complementos ganados
labels: fase:4, area:art|code · estimate: 3
Depende de T-244. Cada logro desbloquea un complemento cosmético (bufanda, gorro de chef, gafas de aviador, chapa de "casi"), elegible en el menú: capa `Sprite2D` sobre el aleteo, sin cambiar hitbox. El GDD deja "skins" fuera de v1; se reabre con ADR como hizo ADR-0019, con una regla dura: **nunca se compran, solo se ganan jugando**.
**Criterios de aceptación**
- Complementos y su logro asociado en `assets/data/accessories.tres`, no en código.
- El elegido se persiste en `user://save.cfg`; uno no desbloqueado no se activa aunque se edite el fichero (se revalida al cargar).
- Test en `tests/` que compruebe desbloqueo, selección y revalidación.
- ADR-0028 documenta la reapertura y la regla "ganados, no comprados"; `docs/GDD.md` actualizado.
- Raúl revisa que Flapo sigue siendo Flapo con cualquier complemento (es la mascota de Plazoleta).

### T-226 · Batacazos según la causa
labels: fase:4, area:art|code · estimate: 2
Depende de T-075. Tres animaciones de muerte en vez de una: contra tubería (se espachurra y resbala), contra suelo (rebota y queda panza arriba), agotado (cae como un saco con "puf" de vaho). Misma duración total que hoy para no tocar el retardo de T-044.
**Criterios de aceptación**
- La causa que elige la animación es la misma que elige la frase (T-075): una sola fuente de verdad.
- Test en `tests/` que compruebe que cada causa selecciona su animación y que todas terminan antes del panel.
- Raúl revisa que las tres son cómicas y ninguna es cruel.

---

## Fase 5 — Audio

### T-060 · Efectos de sonido
labels: fase:5, area:audio · estimate: 2
Aleteo, punto, golpe, caída, botón. Generar con jsfxr o Freesound (CC0), normalizar y recortar en Audacity, exportar OGG.
**Criterios de aceptación**
- Créditos y licencia de cada sonido en `assets/audio/CREDITS.md`.

### T-061 · Buses de audio y silencio persistente
labels: fase:5, area:code · estimate: 1
Buses `SFX` y `Music`; botón mute que guarda en `user://settings.cfg`.
**Criterios de aceptación**
- El estado de mute sobrevive a cerrar y abrir el juego.

### T-062 · Música de fondo (opcional)
labels: fase:5, area:audio · estimate: 2
Loop corto (8-16 compases) en LMMS o pista CC0. Volumen bajo, sin cortes en el loop.

**Descartado en la Fase 5** (ver ADR-0017): el Flappy original no tiene música
y un loop mediocre cansa más que el silencio en partidas de veinte segundos.
El bus `Music` existe y está a −6 dB por si se retoma.
**Criterios de aceptación**
- Loop sin click audible en el punto de unión.

#### Ola 2 — innovación

### T-230 · Jadeo dinámico
labels: fase:5, area:audio|code · estimate: 2
Depende de T-201. Loop de respiración generado con `tools/generar_audio.py` (ADR-0017) cuyo volumen y velocidad siguen el aliento: inaudible por encima del 60 %, resuello claro por debajo del 30 %. Es el aliento contado por el oído, para poder jugar sin mirar la barra.
**Criterios de aceptación**
- `AudioStreamPlayer` propio en el bus `SFX`, con `pitch_scale` y volumen como funciones puras de `breath` en `GameConfig`.
- Test en `tests/` que compruebe los valores al 100 %, 50 % y 0 % y que el loop para en `GAME_OVER` y `MENU`.
- Raúl revisa que no cansa en una partida larga.

### T-231 · Aleteo con peso
labels: fase:5, area:audio|code · estimate: 1
El sonido de aleteo cambia con el estado: más grave y arrastrado con fatiga (T-049) o fruta roja, más agudo y ligero con fruta verde, seco con el eructo (T-208). Un solo sample con `pitch_scale` y volumen; sin samples nuevos.
**Criterios de aceptación**
- Mapeo estado → pitch en `GameConfig`, documentado.
- Test en `tests/` que compruebe el pitch en cada estado.
- Raúl revisa que la diferencia se oye con los altavoces del móvil.

### T-232 · Cada aleteo, una nota
labels: fase:5, area:audio|code · estimate: 3
El aleteo dispara además una nota de una escala pentatónica (siempre suena bien: no hay notas falsas): sube por la escala con la racha de huecos centrados (T-205) y vuelve al inicio al romperla. Jugar bien compone una melodía; es la música que ADR-0017 descartó, pero generada por el jugador en vez de por un loop. `AudioStreamGenerator` con ondas simples, sin samples.
**Criterios de aceptación**
- Opción de apagarlo independiente del mute general, persistida en `user://settings.cfg`.
- Latencia aleteo → nota por debajo de 50 ms (medida con `AudioServer.get_output_latency()` y anotada en `docs/perf.md`).
- Test en `tests/` que compruebe la secuencia de notas para una racha dada.
- ADR-0029 revisa ADR-0017: por qué esto no es la "música de fondo" descartada.
- Raúl decide si queda activado por defecto tras jugar 10 partidas con y 10 sin.

### T-233 · La voz de Flapo
labels: fase:5, area:audio · estimate: 2
Gruñidos cortos sintetizados ("uf" al aletear fatigado, "ay" al rozar, "¡ah!" al recuperar aliento, ronquido en la siesta, "¡hala!" en medalla), generados con `tools/generar_audio.py`: formantes simples, nunca voz grabada, para que envejezca bien y no dependa de una persona.
**Criterios de aceptación**
- Cada voz enlazada a una señal existente, con un límite de una voz cada `VOICE_COOLDOWN` s para no machacar.
- Test en `tests/` que compruebe el cooldown y que en `MENU` solo suena el ronquido.
- Raúl revisa que suena a Flapo (gordito, simpático) y no a alarma.

### T-234 · Silencio antes del golpe
labels: fase:5, area:audio|code · estimate: 1
Depende de T-042. En el hit-stop de 80 ms, todo el bus `SFX` se atenúa a −24 dB y el golpe entra después, solo, a volumen completo. Ducking con `AudioEffectAmplify` en un bus hijo, no tocando cada player. Es la diferencia entre "sonó un golpe" y "¡pum!".
**Criterios de aceptación**
- La atenuación se deshace sola al terminar el hit-stop, también si se reinicia dentro de él.
- Test en `tests/` que compruebe el volumen del bus antes, durante y después.
- Raúl revisa con auriculares y con altavoz de móvil.

---

## Fase 6 — Persistencia y pulido

### T-075 · Causa de muerte en el Game Over
labels: fase:6, area:code · estimate: 1
Depende de T-048 y T-056. La pantalla de Game Over ya sabe si Flapo chocó o se quedó sin aliento; hoy no se lo dice al jugador. Añadir una frase corta que combine la reacción variable (T-056) con la causa real ("chocó de morros", "se quedó sin fuelle").
**Criterios de aceptación**
- Reutiliza el recurso de frases de T-056, con variantes por causa (colisión / sin aliento).
- Test en `tests/` que compruebe que la causa mostrada coincide con el motivo real de la muerte (mock de ambos casos).
- Raúl revisa que el texto no alarga el retardo de 0,5 s antes del panel (T-044).

### T-076 · Modo espejo desbloqueable
labels: fase:6, area:code · estimate: 3
Tras alcanzar cierto récord (`MIRROR_UNLOCK_SCORE` en `GameConfig`), se ofrece un modo opcional con la gravedad y el control invertidos (mantener para subir, soltar para caer). El GDD deja "modos de juego" fuera de v1: esta ADR reabre esa decisión igual que hizo ADR-0019 con las frutas, a sabiendas de que retrasa un poco más la publicación.
**Criterios de aceptación**
- El modo normal no cambia en nada; el espejo es opt-in desde un botón en Game Over o menú, nunca automático.
- Test en `tests/` que compruebe que la inversión de gravedad/control es consistente y que el desbloqueo depende del récord guardado.
- ADR-0023 documenta la decisión y por qué no contradice el resto de "fuera de alcance en v1" (skins, ranking online, anuncios, compras).
- `docs/GDD.md` actualizado: el modo espejo pasa de "fuera de alcance" a excepción documentada.

### T-077 · Captura del mejor salto
labels: fase:6, area:code · estimate: 3
Al superar el récord, generar automáticamente una imagen (o GIF corto) de los últimos segundos de vuelo, para compartir junto al botón ya existente de T-071. Pensado para redes, no cambia el gameplay.
**Criterios de aceptación**
- Usa `Viewport.get_texture()` (o equivalente) sin depender de hardware gráfico específico — documentar en ADR si se necesita algo no trivial en Godot 4.
- Test en `tests/` que compruebe que la captura solo se dispara al superar récord, no en cualquier Game Over.
- Raúl revisa la calidad de la imagen/GIF resultante en el navegador y en Android.

### T-078 · Pantalla de inicio (título, jugar, dificultad, estadísticas)
labels: fase:6, area:code · estimate: 3
Añade un estado `MENU` antes de `READY`: logo/nombre del juego, botón "Jugar", selector de dificultad (fácil/normal/difícil, escala el punto de partida de la curva de T-045 con un multiplicador en `GameConfig` sobre los valores iniciales, no una tabla paralela) y una entrada a la pantalla de estadísticas (T-084). La dificultad elegida se recuerda entre partidas.
**Criterios de aceptación**
- Nuevo estado en la máquina de `Main` (`MENU → READY → PLAYING → GAME_OVER`, y vuelta a `MENU` desde Game Over), documentado junto a ADR-0005 (ver ADR-0022).
- Constantes de las 3 dificultades en `GameConfig`, derivadas de las funciones existentes (`scroll_speed_for`, `pipe_gap_for`, etc.), no tablas duplicadas.
- Persistida la última dificultad elegida en `user://save.cfg`.
- Test en `tests/` que compruebe que cada dificultad produce los valores esperados a puntuación 0 y que el estado inicial del juego es `MENU`.
- Raúl revisa el flujo completo en el navegador: menú → jugar → Game Over → menú, y que el logo/nombre se lee bien en 1x.

### T-079 · Nombre de jugador
labels: fase:6, area:code · estimate: 2
Depende de T-078. Campo de texto simple en la pantalla de inicio para un nombre corto, persistido junto al récord y usado en la pantalla de compartir (T-071) y, si aplica, en la causa de muerte (T-075).
**Criterios de aceptación**
- Límite de caracteres en `GameConfig` (`PLAYER_NAME_MAX_LEN`) y saneado de caracteres que rompan el texto de compartir.
- Persistido en `user://save.cfg`; vacío usa un nombre por defecto sin bloquear la partida.
- Test en `tests/` que compruebe guardado/recuperación y el saneado.
- Raúl revisa la usabilidad del teclado táctil en Android.

### T-084 · Pantalla de estadísticas
labels: fase:6, area:code · estimate: 2
Depende de T-078. Accesible desde el menú: partidas jugadas, mejor puntuación (ya existe), medalla más alta conseguida, y algún dato nuevo que ya se puede derivar sin más estado (p. ex. racha de mejora, aleteos totales) — decidir en el ticket cuáles aportan algo y no inflar `SaveManager` con contadores que nadie mira.
**Criterios de aceptación**
- Los contadores nuevos se persisten en `user://save.cfg` junto al resto (mismo `ConfigFile`).
- Test en `tests/` que compruebe que los contadores se acumulan bien entre partidas y sobreviven a un fichero de guardado ausente/corrupto (igual que T-070/T-074).
- Raúl revisa qué estadísticas se muestran; son contenido de producto, no solo dato técnico.

### T-085 · Layout adaptativo real (RWD por ventana)
labels: fase:6, area:code · estimate: 3
Depende de T-073. Sustituye la idea de "layout móvil vs. layout escritorio" por un cálculo continuo: escucha el resize de la ventana en vivo (no solo al arrancar) y recalcula el mejor `scale` entero para el playfield de 288×512 (ADR-0002 sigue mandando: nunca fractional) más cuánto espacio sobra alrededor. El playfield no cambia nunca de tamaño lógico ni de posición relativa; lo único que se adapta es cuánto "extra" hay y dónde queda.
**Criterios de aceptación**
- Redimensionar la ventana en vivo (sin reiniciar) recalcula el `scale` entero sin dejar píxeles fraccionados.
- El playfield queda siempre centrado, en cualquier proporción (16:9, 21:9, 4:3, vertical extremo).
- Test en `tests/` que, dado un conjunto de tamaños de ventana, compruebe que el `scale` elegido es siempre entero y el mayor que cabe.
- ADR-0025 documenta que se abandona el par fijo de layouts por un cálculo continuo y por qué no contradice el resto de ADR-0002 (`integer`, `viewport`, `keep` siguen mandando en el playfield).
- Raúl prueba redimensionando la ventana en directo en el navegador, no solo abriendo tamaños distintos.

### T-086 · Contenido adaptativo en el espacio sobrante
labels: fase:6, area:code · estimate: 2
Depende de T-085 y T-084. Define 2-3 tramos de espacio sobrante (nada, panel pequeño, panel grande) y qué se muestra en cada uno: nada o algo decorativo si no cabe nada útil, récord y datos básicos si cabe un panel pequeño, estadísticas completas (T-084) si cabe más. Nunca contenido interactivo que distraiga de la partida en curso.
**Criterios de aceptación**
- Los umbrales de cada tramo están en `GameConfig` (px de espacio sobrante), no hardcodeados en la escena.
- Test en `tests/` que compruebe qué contenido se activa en cada tramo, dado un tamaño de ventana simulado.
- Raúl revisa que el panel no compita visualmente con el playfield ni distraiga durante `PLAYING`.

### T-074 · Progresión de confianza
labels: fase:6, area:code · estimate: 3
Depende de T-048/T-049 y de `SaveManager` (T-070, ADR-0013). Cada `CONFIDENCE_STEP` partidas jugadas (no puntuación), Flapo gana una mejora pequeña y permanente hasta un tope: más `MAX_BREATH` o menos penalización de fatiga. Es progresión narrativa ("va cogiendo el truco"), no un desbloqueable comprado ni un menú de mejoras: se nota jugando, no se elige.
**Criterios de aceptación**
- Persistido en `user://save.cfg` junto al récord (mismo `ConfigFile`, nueva clave); sobrevive a cerrar y reabrir.
- Tope documentado en `GameConfig` (no crece indefinidamente).
- Test en `tests/` con fichero de guardado ausente/corrupto, igual que cubre `SaveManager`, que compruebe que la progresión no rompe el arranque.
- ADR-0021 documenta la decisión y por qué no es meta-progresión visible/comprada (para no contradecir "Fuera de alcance en v1").
- `docs/GDD.md` actualizado: aclara que esto es distinto de un power-up comprado.

### T-070 · Guardado de récord
labels: fase:6, area:code · estimate: 1
`SaveManager` autoload con `ConfigFile` en `user://save.cfg`. Récord, partidas jugadas.
**Criterios de aceptación**
- Fichero corrupto o ausente no rompe el juego (valores por defecto).

### T-071 · Pantalla de Game Over completa
labels: fase:6, area:code · estimate: 2
Puntuación, récord, medalla según umbrales, animación de entrada, botones reintentar y compartir (Android: intent de texto).
**Criterios de aceptación**
- Umbrales de medalla en `GameConfig`.

### T-072 · Pausa y pérdida de foco
labels: fase:6, area:code · estimate: 1
Acción `pause`; en Android, `NOTIFICATION_APPLICATION_PAUSED` pausa automáticamente.
**Criterios de aceptación**
- Volver del segundo plano no provoca muerte instantánea.

### T-073 · Márgenes seguros y pantallas altas
labels: fase:6, area:code · estimate: 1
HUD respeta `DisplayServer.get_display_safe_area()`; fondo cubre relaciones 16:9 a 21:9.
**Criterios de aceptación**
- Probado en emulador con notch.

#### Ola 2 — innovación

### T-240 · Semilla determinista
labels: fase:6, area:code · estimate: 2
Base de T-241, T-242, T-243, T-260 y T-261. Toda la aleatoriedad de una partida (huecos, tuberías móviles, frutas, térmicas, hermano) sale de un único `RandomNumberGenerator` con semilla conocida, inyectado desde `Main`; nada usa `randi()` global. Con la misma semilla y los mismos inputs, la partida es idéntica frame a frame (física a 60 Hz fija, T-020).
**Criterios de aceptación**
- `grep -r "randi\|randf" scripts/` solo encuentra usos del RNG inyectado.
- Test en `tests/` que corra dos partidas con la misma semilla y los mismos inputs simulados y compare posiciones de tuberías y puntuación; y que semillas distintas den partidas distintas.
- ADR-0030 documenta el RNG único, qué garantiza y qué no (el determinismo no sobrevive a cambiar `GameConfig`).

### T-241 · Reto del día
labels: fase:6, area:code · estimate: 2
Depende de T-240. Botón en el menú: "Reto de hoy". La semilla es la fecha (`AAAAMMDD`), así que todo el mundo juega las mismas tuberías ese día, sin servidor. Guarda la mejor marca del día y el histórico de retos; al compartir (T-071) dice "Reto del 8 de septiembre: 14".
**Criterios de aceptación**
- Semilla derivada solo de la fecha local; modo y frutas no cambian respecto al juego normal.
- El récord general no se mezcla con el del reto (claves separadas en `SaveManager`).
- Test en `tests/` que compruebe que dos arranques el mismo día dan la misma partida y que cambia al día siguiente.
- Raúl revisa el texto de compartir.

### T-242 · Semilla compartible
labels: fase:6, area:code · estimate: 2
Depende de T-240. Cada partida enseña en Game Over un código corto (semilla en base 36, 5-6 caracteres) y el menú tiene "Jugar un código". Dos amigos juegan exactamente las mismas tuberías y comparan, sin ranking online ni servidor.
**Criterios de aceptación**
- El código va en el texto de compartir (T-071/T-079).
- Un código inválido no rompe nada: aviso corto y se queda en el menú.
- Test en `tests/` que compruebe codificación/decodificación y el rechazo de códigos inválidos.
- Raúl revisa que el código cabe en la pantalla de Game Over a 1x.

### T-243 · Fantasma del récord
labels: fase:6, area:code · estimate: 3
Depende de T-240. Al superar el récord se guardan la semilla y la lista de inputs (frame + aleteo/planeo) en `user://ghost.dat`. Al jugar el reto o un código con la misma semilla, un Flapo translúcido reproduce ese vuelo. Es la única forma honesta de competir contigo mismo sin online. Un `AnimatedSprite2D` sin física que sigue las posiciones reproducidas, no un segundo `Bird`.
**Criterios de aceptación**
- El fantasma no colisiona, no puntúa ni toca el RNG.
- Fichero de fantasma ausente o corrupto no rompe el arranque (mismo trato que `SaveManager`).
- Test en `tests/` que grabe una partida simulada, la reproduzca y compruebe que las posiciones coinciden.
- Raúl revisa que el fantasma se distingue de Flapo y no confunde en un hueco estrecho.

### T-244 · Logros con nombre de tapa
labels: fase:6, area:code · estimate: 2
Doce logros offline con nombre de bar ("Pincho de tortilla": 5 huecos centrados seguidos; "De rasante": 10 roces en una partida; "Siesta": dormir a Flapo; "Ha llegado": el nido…), definidos en `assets/data/achievements.tres` y mostrados en estadísticas (T-084). Sin recompensa más que el nombre y, con T-225, un complemento.
**Criterios de aceptación**
- Cada logro es una condición sobre señales o contadores existentes; ninguno añade estado al juego más que su propio flag.
- Aviso al desbloquear: una línea en el HUD, nunca un popup que pare la partida.
- Test en `tests/` que compruebe el desbloqueo de al menos 3 logros y su persistencia.
- Raúl revisa los nombres: son contenido.

### T-245 · Soplar para aletear
labels: fase:6, area:code · estimate: 5
Modo de entrada opcional: el micrófono. Un soplido corto aletea, uno sostenido planea. Es el juego del aliento controlado con el aliento de verdad. `AudioEffectCapture` en un bus de entrada, detección por energía con umbral e histéresis, calibración de 3 s al activarlo. Web y Android; el botón sigue funcionando siempre.
**Criterios de aceptación**
- Opt-in desde el menú con explicación de una línea; permiso de micrófono pedido solo entonces; nada se graba ni se guarda (documentado en `docs/tiendas.md` para la declaración de datos de Google Play).
- Umbrales en `GameConfig`; la calibración se persiste en `user://settings.cfg`.
- Test en `tests/` con señal de audio sintética inyectada (no micrófono real) que compruebe soplido corto → aleteo y sostenido → planeo.
- ADR-0031 documenta la entrada por micrófono y por qué no sustituye al botón (ADR-0004).
- Raúl prueba en el navegador y en Android en un sitio con ruido.

### T-246 · Dos Flapos en una pantalla
labels: fase:6, area:code · estimate: 5
Modo local para dos en el mismo dispositivo: mitad izquierda/derecha de la pantalla táctil (o espacio y flecha arriba), dos Flapos (el segundo con complemento distinto, T-225) en el mismo túnel. Al morir uno, el otro sigue hasta morir; gana quien más aguanta. El GDD deja "modos de juego" fuera de v1: se reabre con ADR como T-076.
**Criterios de aceptación**
- Los dos pájaros usan la misma escena `Bird` con la acción de input parametrizada; ninguna lógica duplicada.
- Sin colisión entre Flapos; frutas y aliento son por jugador.
- Test en `tests/` que compruebe que la muerte de uno no termina la partida y que las puntuaciones son independientes.
- ADR-0032 documenta el modo y cómo `Main` gestiona dos `Bird` sin romper ADR-0005.
- Raúl prueba con otra persona en el móvil.

### T-247 · Mapa de calor de muertes
labels: fase:6, area:code · estimate: 2
Depende de T-084. `SaveManager` acumula, por índice de tubería (1ª, 2ª… hasta 60) y por causa, dónde muere el jugador. La pantalla de estadísticas dibuja una tira con cada índice teñido según las muertes. Sirve al jugador ("siempre caigo en la 7") y al proyecto (T-260 mide lo mismo con el bot).
**Criterios de aceptación**
- Datos agregados, sin lista de partidas: el fichero no crece con el número de partidas.
- Test en `tests/` que compruebe la acumulación y la tolerancia a guardado ausente/corrupto.
- Raúl revisa que la tira se lee a 1x.

### T-248 · Accesibilidad de verdad: formas, movimiento, vibración
labels: fase:6, area:code|art · estimate: 2
Tres ajustes persistidos: las frutas llevan forma además de color (círculo, rombo, estrella…) para daltonismo; "menos movimiento" quita sacudida de cámara, flash y parallax rápido conservando el hit-stop; vibración háptica en Android (`Input.vibrate_handheld`) al aletear fatigado y al morir. Amplía `tests/test_a11y.gd`.
**Criterios de aceptación**
- Con "menos movimiento" ninguna animación de cámara ni flash se ejecuta (test), y el juego es el mismo.
- Las formas van en el mismo sprite de fruta (sin sprites duplicados por opción).
- Test en `tests/` que compruebe los tres ajustes y su persistencia.
- Raúl revisa las formas a 1x y la vibración en Android.

### T-249 · "Hasta yo descanso"
labels: fase:6, area:code · estimate: 1
Tras `REST_HINT_GAMES` partidas seguidas (15) en la misma sesión, en el siguiente Game Over Flapo, con la cara agotada de T-220, sugiere un descanso en una línea. Una vez por sesión, no bloquea nada, no vuelve hasta cerrar el juego. Coherente con "se ríe con él": cuidar al jugador también es tono.
**Criterios de aceptación**
- Una vez por sesión de proceso, sin persistir.
- Test en `tests/` que compruebe que aparece en la partida 15 y no en la 16.
- Raúl revisa el texto: ánimo, no regañina.

### T-250 · Novedades en el menú
labels: fase:6, area:code|docs · estimate: 1
Al arrancar con una versión distinta de la última guardada, el menú enseña "Novedades" con 2-3 líneas leídas de `assets/data/changelog.tres` (rellenado en cada release; automático con T-271). El jugador que vuelve ve qué cambió sin pasar por la tienda.
**Criterios de aceptación**
- Versión leída de `ProjectSettings` (`application/config/version`), comparada con la persistida en `user://settings.cfg`.
- Test en `tests/` que compruebe que solo aparece al cambiar de versión.
- `docs/qa-checklist.md` añade "changelog actualizado" al checklist de release.

---

## Fase 7 — Calidad

### T-080 · Tests unitarios
labels: fase:7, area:qa · estimate: 2
Instalar GUT o gdUnit4 y **migrar a su formato los tests de `tests/`** escritos desde T-006; `harness.gd` desaparece. Cubrir además: máquina de estados, puntuación única por tubería, `SaveManager` con fichero ausente/corrupto.
**Criterios de aceptación**
- Tests ejecutables en headless: `godot --headless -s addons/gut/gut_cmdln.gd`.
- Ningún test de `tests/` se pierde en la migración.

### T-081 · Checklist de QA manual
labels: fase:7, area:qa · estimate: 1
`docs/qa-checklist.md`: reinicio, pausa, rotación, foco, mute, récord, rendimiento, distintas resoluciones.
**Criterios de aceptación**
- Ejecutada y firmada antes de cada release.

### T-082 · Perfilado y rendimiento
labels: fase:7, area:qa · estimate: 1
Medir fps y nodos vivos con el profiler y `Performance.get_monitor`; objetivo 60 fps en Android de gama baja.
**Criterios de aceptación**
- Resultados en `docs/perf.md`.

### T-083 · Lint y formato con pre-commit
labels: fase:7, area:ci · estimate: 1
gdtoolkit (`gdformat`, `gdlint`) vía pre-commit; `.gdlintrc` en el repo. Quitar el `|| true` del job `lint` de `export.yml`.

Estado actual (medido en CI, T-091): **17 problemas**. Casi todos son
`class-definitions-order` (gdlint quiere señales → constantes → exports →
variables → onready → métodos, y el proyecto agrupa por tema), tres líneas de
más de 100 caracteres en `tests/`, y `_connect_children` de `main.gd` con más
de 6 `return`. Decidir en el ticket qué reglas se acatan y cuáles se relajan
en `.gdlintrc`; el orden de definiciones probablemente se acata y el resto se
refactoriza.
**Criterios de aceptación**
- `pre-commit run --all-files` pasa limpio.
- El job `lint` del CI ya no lleva `|| true`.

#### Ola 2 — innovación

### T-260 · Bot que juega: métrica de justicia
labels: fase:7, area:qa · estimate: 3
Depende de T-240. Un jugador automático en `tools/bot_flapo.gd` con una política simple y fija (aletea cuando la `y` prevista cae por debajo del centro del siguiente hueco, planea cuando está por encima). Corre 200 partidas en headless con semillas distintas y reporta media, mediana y el histograma de muertes por índice de tubería (mismo formato que T-247). No mide diversión; mide **si la curva es justa**: si el bot muere siempre en la misma tubería, hay un pico.
**Criterios de aceptación**
- `./tests/run.sh` no lo ejecuta (es lento); comando propio documentado en `docs/testing.md`.
- Test en `tests/` que corra 5 partidas y compruebe que el bot puntúa > 0 y que el reporte se genera.
- Resultado inicial anotado en `docs/perf.md` como línea base para T-040 y para cada cambio de `GameConfig`.
- ADR-0033 documenta qué garantiza la métrica del bot y qué no.

### T-261 · Replay determinista para reproducir bugs
labels: fase:7, area:qa · estimate: 2
Depende de T-240 y T-243. Cualquier partida se vuelca (semilla + inputs) a un fichero `.replay`, y `tests/replay.gd` la reproduce en headless y compara el resultado. Un bug reportado con su replay se reproduce en CI sin que nadie tenga que jugar.
**Criterios de aceptación**
- Volcado desde el menú de pausa ("guardar esta partida") y automático de la última partida en cada muerte (`user://last.replay`).
- Test en `tests/` que reproduzca un replay de referencia versionado en `tests/fixtures/` y compruebe la puntuación esperada.
- `docs/testing.md` explica cómo adjuntar un replay a una issue; la plantilla de bug (T-005) lo pide.

---

## Fase 8 — CI/CD y exportación

### T-090 · Presets de exportación
labels: fase:8, area:ci · estimate: 1
`export_presets.cfg` para Web, Android, Linux y Windows. Sin secretos dentro.
**Criterios de aceptación**
- Exportación manual de los 4 presets funciona en local. Android solo en
  depuración: el release necesita el keystore de T-092.

### T-091 · Workflow de export en GitHub Actions
labels: fase:8, area:ci · estimate: 3
`export.yml`: en push a `main` y en PR ejecuta los tests headless (`tests/run.sh` dentro del contenedor godot-ci, ver ADR-0007) **y un export a Web**, que es lo que garantiza que `main` sigue siendo exportable; en tag `v*` exporta los presets con imagen godot-ci y publica en GitHub Releases.
**Criterios de aceptación**
- Un push a `main` con un test roto pone el workflow en rojo.
- Un tag `v0.1.0` genera una release con un artefacto descargable por preset existente.
- La matriz de presets crece con T-090 (Android, Linux, Windows).

### T-092 · Firma de Android
labels: fase:8, area:ci · estimate: 2
Keystore de release generado en local, subido como secreto base64; `version/code` autoincrementado en CI.
**Criterios de aceptación**
- APK/AAB firmado instala en dispositivo real.
- El keystore nunca aparece en el historial de git.

### T-093 · Build web verificado en itch.io
labels: fase:8, area:ci · estimate: 1
Subir build web de prueba; activar SharedArrayBuffer si Godot lo requiere.
**Criterios de aceptación**
- Juega en Chrome, Firefox y Safari móvil.

#### Ola 2 — innovación

### T-270 · Build jugable por cada PR
labels: fase:8, area:ci · estimate: 2
Depende de T-091. Cada PR publica su export Web en GitHub Pages bajo `/pr-NNN/` y un bot comenta el enlace. Raúl prueba desde el móvil sin clonar nada; al cerrar la PR se borra la carpeta.
**Criterios de aceptación**
- El enlace aparece en la PR en menos de 5 minutos tras el push.
- Las cabeceras COOP/COEP funcionan en Pages, o la build usa el modo sin threads; documentar cuál.
- `main` publica en la raíz de Pages la build actual, que es la que enlaza el README.

### T-271 · Versionado semántico automático
labels: fase:8, area:ci · estimate: 1
Depende de T-091. Los Conventional Commits ya llevan la información: un job calcula la siguiente versión (`feat` → minor, `fix` → patch), escribe `application/config/version` en `project.godot`, genera `CHANGELOG.md` y `assets/data/changelog.tres` (T-250) y crea el tag. Nadie edita versiones a mano.
**Criterios de aceptación**
- Un `feat:` mergeado en `main` produce un tag minor con release y changelog.
- El número de versión del menú (T-250) coincide con el tag.

---

## Fase 9 — Publicación

### T-100 · Página de itch.io
labels: fase:9, area:release · estimate: 2
Capturas, GIF, descripción, build web embebido, descargas de escritorio, botler o subida manual.
**Criterios de aceptación**
- Página pública y enlazada desde README.

### T-101 · Google Play: ficha y requisitos
labels: fase:9, area:release · estimate: 3
Cuenta de desarrollador, ficha, capturas, política de privacidad (página estática en GitHub Pages), clasificación de contenido, declaración de datos.
**Criterios de aceptación**
- Ficha completa sin avisos pendientes.

### T-102 · Prueba cerrada de Google Play
labels: fase:9, area:release · estimate: 2
Prueba cerrada con 12+ testers durante 14 días (requisito para cuentas nuevas). Recoger feedback como issues.
**Criterios de aceptación**
- Aprobado para producción.

### T-103 · Release v1.0.0
labels: fase:9, area:release · estimate: 1
Tag, notas de versión, badges y enlaces a tiendas en README.
**Criterios de aceptación**
- Release publicada y README actualizado.

#### Ola 2 — innovación

### T-280 · Instalable y compartible desde la web
labels: fase:9, area:release|code · estimate: 3
La build web se convierte en PWA: `manifest.json`, icono (T-054) y service worker que cachea la build para jugar sin conexión y con icono en el móvil, sin pasar por Google Play. Y el botón de compartir usa `navigator.share` vía `JavaScriptBridge` cuando existe (texto + código de T-242), con el portapapeles como respaldo.
**Criterios de aceptación**
- Lighthouse marca la página como instalable; la segunda carga funciona en modo avión.
- El service worker se invalida al cambiar la versión (T-271): nunca sirve una build vieja de una nueva.
- Test en `tests/` que compruebe el texto de compartir y el respaldo cuando `JavaScriptBridge` no está (escritorio).
- ADR-0034 documenta la PWA y sus límites frente a la tienda.
- Raúl instala desde Chrome en Android y desde Safari en iPhone.

---

## Fase 10 — Retrospectiva

### T-110 · Retrospectiva
labels: fase:10, area:docs · estimate: 1
`docs/retro.md`: qué funcionó, qué no, horas reales vs estimadas por fase, aprendizajes para el siguiente proyecto.
**Criterios de aceptación**
- Tabla de estimado vs real por fase.

### T-111 · Devlog público
labels: fase:10, area:docs · estimate: 2
Post en itch.io o blog contando el proceso con GIFs por fase.
**Criterios de aceptación**
- Publicado y enlazado desde README.

#### Ola 2 — innovación

### T-290 · Museo de placeholders
labels: fase:10, area:code|docs · estimate: 2
Pantalla desbloqueada al completar el viaje (T-209): la evolución del juego, de los rectángulos de la Fase 2 al arte final, con una línea por hito y su fecha, leídas de `docs/museo.tres` (capturas versionadas de cada fase). El proyecto es público y de aprendizaje: el "making of" está dentro del juego, no solo en el devlog (T-111).
**Criterios de aceptación**
- Capturas de cada fase en `docs/museo/` con licencia CC BY 4.0 como el resto de assets.
- Test en `tests/` que compruebe que el desbloqueo depende de `journey_completed`.
- Raúl elige las capturas y escribe las líneas: es la retro (T-110) contada al jugador.
