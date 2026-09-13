# Roadmap — Flapo

Flapo es un juego de un solo botón inspirado en Flappy Bird; el pájaro protagonista también se llama Flapo. Primer proyecto de aprendizaje de desarrollo de videojuegos, hecho de principio a fin: diseño, arte, código, audio, pruebas, exportación y publicación. El objetivo no es el juego, es recorrer el pipeline completo y documentarlo.

- Motor: Godot 4.x (GDScript)
- Plataformas objetivo: Web (itch.io) y Android. PC (Windows/Linux/macOS) como extra.
- Resolución base: 288×512 (vertical), pixel art, escalado entero.
- Licencia: MIT para el código; el personaje Flapo con todos los derechos reservados (mascota de Plazoleta); resto de assets propios bajo CC BY 4.0, assets de terceros con su licencia original.

Estado: 🔲 pendiente · 🔄 en curso · ✅ hecho

---

## Fase 0 — Preparación (1-2 días)

Objetivo: entorno listo y repo con estructura profesional desde el día uno.

- ✅ Instalar Godot 4.x (versión estable) y verificar que arranca. → 4.7.2.stable, con export templates y export a Web verificado (T-001)
- 🔲 Instalar Pixelorama (arte), Audacity (audio), Tiled/LDtk no hace falta para este juego.
- ✅ Crear el repo público con esta estructura:

```
flapo/
├─ project.godot
├─ assets/
│  ├─ sprites/      # PNG fuente y hojas de sprites
│  ├─ audio/        # WAV/OGG
│  └─ fonts/
├─ scenes/          # .tscn
├─ scripts/         # .gd
├─ docs/            # GDD, decisiones, retrospectiva
│  ├─ GDD.md
│  ├─ decisions/    # ADR-0001-motor.md, ...
│  └─ retro.md
├─ .github/workflows/export.yml
├─ .gitignore       # plantilla Godot 4
├─ README.md
├─ ROADMAP.md
└─ LICENSE
```

- ✅ `.gitignore` de Godot 4 (`.godot/`, `export/`, `*.import` NO se ignora).
- ✅ README con: qué es, captura, cómo ejecutar, cómo contribuir, licencias.
- ✅ ADR-0001: elección de motor y lenguaje (por qué Godot/GDScript).

Entregable: repo con proyecto vacío que abre en Godot y `README.md` legible.

---

## Fase 1 — Diseño (1 día)

Objetivo: GDD de una página. Si no cabe en una página, el alcance es demasiado grande.

- ✅ `docs/GDD.md` con:
  - Pitch en una frase.
  - Bucle central: tocar → aletear → cruzar huecos → morir → reintentar.
  - Reglas: gravedad, fuerza de salto, velocidad de scroll, separación y hueco de tuberías, condición de muerte, puntuación.
  - Estados del juego: `Ready → Playing → GameOver`.
  - Controles: toque/click/espacio.
  - Feedback: sonidos (aleteo, punto, golpe), parpadeo al morir, sacudida de cámara.
  - Lo que NO está en el alcance v1 (skins, ranking online, power-ups).
- ✅ Paleta propia de 16 colores, Flapo 24×24, tubería 26 px. → T-011 y ADR-0015

Entregable: GDD cerrado y paleta elegida.

---

## Fase 2 — Prototipo jugable con placeholders (2-3 días)

Objetivo: el bucle completo funciona con rectángulos de colores. Nada de arte todavía.

- ✅ Escena `Main` con estados `Ready / Playing / GameOver` (máquina de estados simple). → T-022
- ✅ `Bird` (`CharacterBody2D`): gravedad, impulso al pulsar, rotación según velocidad, límite superior. → T-023
- ✅ `Pipe`: par de tuberías con hueco aleatorio; se mueve a la izquierda y se libera al salir de pantalla. → T-024 (con `StaticBody2D`, no `Area2D`: ver ADR-0008)
- ✅ `PipeSpawner`: `Timer` que instancia tuberías a intervalo fijo. → T-025
- ✅ Zona de puntuación entre las tuberías → +1 al atravesar. → T-026
- ✅ Suelo con scroll infinito y colisión. → T-027
- ✅ Muerte por contacto con tubería o suelo; pantalla de Game Over con reinicio. → T-028
- ✅ HUD: puntuación en pantalla. → T-029
- ✅ Input unificado en `InputMap` (acción `flap`: click, toque, espacio). → T-021

Definición de hecho: se puede jugar 5 minutos sin bugs y la partida se reinicia limpiamente.

Estado: código completo y verificado en headless (`./tests/run.sh`, 6 ficheros de test).
Queda **T-030**: la sesión de prueba jugada, que por definición no puede
comprobar nadie más que una persona con las manos en el teclado.

---

## Fase 3 — Game feel (1-2 días)

Objetivo: que se sienta bien. Es donde un clon mediocre se separa de uno bueno.

- ✅ Frutas con efectos: inmunidad, pesado, ligero, grande y lento, con castigos que pagan en puntos. → T-047 (ADR-0019)
- ✅ Aliento: mantener pulsado planea, gastando un recurso que se recupera cruzando huecos por el centro. → T-048 (ADR-0020)
- ✅ Fatiga: aletear sin pausa ni planeo reduce el impulso un 30 %. Se quita planeando. → T-049 (ADR-0020)
- 🔲 Reacciones variables al morir, coherentes con el tono (nunca burla). → T-056
- ✅ Curva de dificultad: velocidad sube y hueco se estrecha con la puntuación, con tope a los 30 puntos. Hueco de salida ancho (118 px) como rampa de entrada. → T-045 y T-046 (ADR-0018)
- 🔲 Ajustar constantes hasta que el salto sea legible (documentar valores finales en el GDD). → T-040, aplazado a petición de Raúl
- ✅ Animación de aleteo (3 frames) con `AnimatedSprite2D`. → T-041
- ✅ Flash blanco + sacudida de cámara al morir. → T-042
- ✅ Pequeña pausa (hit-stop) de 50-100 ms al morir. → T-042 (80 ms)
- ✅ Parallax de fondo (2 capas: nubes lentas, ciudad media). → T-043
- ✅ Transiciones: fundido entre `Ready` y `Playing`, retardo antes de mostrar Game Over. → T-044

Entregable: build jugable con vídeo/GIF en `docs/`.

Estado: T-041 a T-044 hechos y verificados en headless. Queda T-040 (tuning),
aplazado, y el GIF, que necesita a alguien jugando.

---

## Fase 4 — Arte (3-5 días)

Objetivo: sustituir todos los placeholders por pixel art propio.

- 🔄 Pájaro: aleteo de 3 frames, **24×24** (ADR-0015). Reconstruido del arte entregado; pendiente de retoque a mano.
- ✅ Tubería: cuerpo repetible + cabeza. → T-051
- ✅ Suelo: tile de 32 px repetible. → T-052
- ✅ Fondo: cielo, nubes, silueta de ciudad. → T-052
- ✅ UI: fuente de cifras propia, logo y medallas croqueta/tortilla/jamón. → T-053
- ✅ Icono 512×512 y splash. → T-054
- ✅ Importación: filtro `Nearest`, sin mipmaps, sin compresión con pérdida. → T-055
- ✅ Stretch `viewport` + `integer`. → T-020 (ADR-0002)

Entregable: juego sin ningún placeholder. Fuentes de arte (`.pxo`) en `assets/sprites/src/`.

Estado: todo el arte salvo Flapo se genera con `tools/generar_arte.py` en la
paleta del proyecto (ADR-0016). Queda el retoque a mano del sprite de Flapo,
que por ser la mascota debe dibujarlo una persona.

---

## Fase 5 — Audio (1 día)

- ✅ Sonidos: aleteo, punto, golpe, caída, botón, sintetizados con `tools/generar_audio.py`. → T-060 (ADR-0017)
- ⏭️ Música: descartada a propósito. El Flappy original no tiene, y un loop mediocre cansa en partidas de 20 s. El bus `Music` queda listo por si se retoma. → T-062
- ✅ `AudioStreamPlayer` por sonido, buses SFX y Music separados. → T-061
- ✅ Botón de silencio persistente en `user://settings.cfg`. → T-061

---

## Fase 6 — Persistencia y pulido (1-2 días)

- ✅ Guardar récord en `user://save.cfg` (`ConfigFile`). → T-070 (ADR-0013)
- ✅ Pantalla Game Over: puntuación, récord, medalla, reintento y compartir. → T-071
- ✅ Pausa, y automática al perder el foco. → T-072 (ADR-0014)
- ✅ Márgenes seguros y letterbox del color del cielo. → T-073. Falta verlo en un emulador con notch.
- ✅ Revisión de accesibilidad: contraste WCAG y 48 dp táctiles verificados en `tests/test_a11y.gd`.
- 🔲 Progresión de confianza: mejoras pequeñas y permanentes con la práctica, persistidas junto al récord. → T-074 (ADR-0021)

---

## Fase 7 — Calidad (1-2 días)

- 🔄 Tests: 18 ficheros en `tests/`, uno por ticket, con arnés propio (ADR-0007). Migrar a GUT o gdUnit4 sigue abierto → T-080.
- ✅ Checklist manual de QA en `docs/qa-checklist.md`. → T-081
- 🔄 Perfilado: sin fugas de nodos, verificado en cada push (`docs/perf.md`). → T-082. Los fps en Android de gama baja siguen pendientes: necesitan dispositivo.
- ✅ Formateo y lint con gdtoolkit en pre-commit y en CI. → T-083

---

## Fase 8 — CI/CD y exportación (1-2 días)

- 🔄 GitHub Actions (`export.yml`): en cada push y PR, tests headless + export a Web (T-091, hecho); en cada tag `v*`, exporta Web, Linux y Windows (T-090, hecho). Android espera al keystore de T-092.
- 🔲 Subir artefactos a GitHub Releases automáticamente.
- 🔲 Export Web: comprobar cabeceras COOP/COEP (itch.io las soporta con la opción SharedArrayBuffer).
- 🔲 Export Android: keystore de release (guardado como secreto de GitHub, nunca en el repo), firma, versionado (`version/code` y `version/name`).
- 🔲 Reproducir el build de Android en un dispositivo real.

Entregable: `v1.0.0` con builds descargables desde Releases.

---

## Fase 9 — Publicación (1-2 días)

- 🔲 **itch.io**: página con capturas, GIF, descripción, build web embebido y descargas de escritorio.
- 🔄 **Google Play** (25 $ una vez): textos y política de privacidad listos en `docs/`. Faltan cuenta, capturas, clasificación de contenido, prueba cerrada de 14 días con 12+ testers (requisito actual para cuentas nuevas).
- 🔲 (Opcional) **Steam**: no para este proyecto; se documenta el proceso para el siguiente.
- 🔄 README con badges y documentación. Faltan los enlaces a las tiendas y la captura. → T-103

---

## Fase 10 — Retrospectiva y cierre

- 🔲 `docs/retro.md`: qué salió bien, qué mal, qué haría distinto, horas reales por fase.
- 🔲 Post/hilo público contando el proceso (devlog en itch.io o blog).
- ✅ Lista de aprendizajes reutilizables: `docs/aprendizajes.md`.

---

## Calendario orientativo

| Fase | Días | Acumulado |
|---|---|---|
| 0 Preparación | 1-2 | 2 |
| 1 Diseño | 1 | 3 |
| 2 Prototipo | 2-3 | 6 |
| 3 Game feel | 1-2 | 8 |
| 4 Arte | 3-5 | 13 |
| 5 Audio | 1 | 14 |
| 6 Persistencia y pulido | 1-2 | 16 |
| 7 Calidad | 1-2 | 18 |
| 8 CI/CD y exportación | 1-2 | 20 |
| 9 Publicación | 1-2 | 22 |
| 10 Retrospectiva | 1 | 23 |

A ritmo de tardes y fines de semana: 5-7 semanas.

---

## Convenciones del repo

- Commits: Conventional Commits (`feat:`, `fix:`, `art:`, `docs:`, `ci:`).
- Ramas: `main` siempre exportable; una rama por fase o feature; PR con descripción y GIF cuando cambie algo visible.
- Issues: una por tarea de este roadmap, etiquetadas por fase; milestone por fase.
- Decisiones técnicas relevantes → ADR en `docs/decisions/`.
- Criterios de aceptación comprobables sin ventana → test en `tests/`, un fichero por ticket (`docs/testing.md`, ADR-0007).
- Este archivo se actualiza al cerrar cada fase.

## Recursos

- Docs Godot 4: https://docs.godotengine.org
- Tutorial oficial "Your first 2D game"
- GMTK — *Why does Celeste feel so good to play?*
- Lospec (paletas), Kenney (assets placeholder), jsfxr (SFX)
- gdtoolkit, GUT / gdUnit4, godot-ci (imágenes Docker para Actions)
