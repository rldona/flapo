# Tickets — Flapo

Cada ticket es una issue de GitHub. Formato: `### T-NNN · Título` seguido de metadatos y cuerpo. El script `scripts/create_issues.py` los crea automáticamente.

Estimación en puntos (1 = ~1 h, 2 = media tarde, 3 = una tarde, 5 = dos tardes).
Labels: `fase:N`, `area:code|art|audio|docs|ci|qa|release`.
Milestone = fase.

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

### T-050 · Reacciones variables al morir
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

---

## Fase 4 — Arte

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

---

## Fase 6 — Persistencia y pulido

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
