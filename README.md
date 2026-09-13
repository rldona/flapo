# Flapo

### 🎮 [Jugar ahora](https://rldona.github.io/flapo/)

[![CI](https://github.com/rldona/flapo/actions/workflows/export.yml/badge.svg)](https://github.com/rldona/flapo/actions/workflows/export.yml)
[![Godot](https://img.shields.io/badge/Godot-4.7.2-478cbf)](https://godotengine.org)
[![Licencia](https://img.shields.io/badge/c%C3%B3digo-MIT-green)](LICENSE)
[![Jugar](https://img.shields.io/badge/jugar-en%20el%20navegador-E6B84A)](https://rldona.github.io/flapo/)

Un juego de un solo botón: toca para que **Flapo** aletee, cruza los huecos entre tuberías y no toques nada. Inspirado en Flappy Bird.

Flapo es el hermano gordito del pájaro famoso: quiere volar como él, pero pesa el doble y le cuesta el triple.

Primer proyecto de [Plazoleta](https://plazoleta.dev) en desarrollo de videojuegos, hecho de principio a fin en público: diseño, arte, código, audio, pruebas, CI/CD y publicación en itch.io y Google Play.

> Estado: 🔄 **Fases 0 a 7 hechas**. Bucle completo, arte, audio, récord, pausa y CI. Pendiente: tuning final, retoque del sprite, y publicación.
> Se juega en el navegador, sin instalar nada: <https://rldona.github.io/flapo/>
> Es la build de `main`, y se actualiza sola en cada push.
>
> [Roadmap](ROADMAP.md) · [Tickets](TICKETS.md) · [GDD](docs/GDD.md) · [Decisiones](docs/decisions/)

<!-- TODO: captura y GIF del juego (T-100). Requieren el juego corriendo con
     render: headless no dibuja. -->

## Stack

- Godot 4.7.2 · GDScript tipado
- Pixel art propio, paleta de 16 colores · efectos de sonido sintetizados
- Tests headless propios · gdformat y gdlint en pre-commit
- CI: GitHub Actions (tests, lint y export en cada push; release en cada tag)

## Ejecutar

1. Instala [Godot 4.7.2](https://godotengine.org/download) (ver `docs/environment.md`).
2. Clona y abre `project.godot` desde el gestor de proyectos.
3. **⌘B** en macOS, **F5** en Windows y Linux.

```bash
# Tests: compila todos los .gd y ejecuta las comprobaciones
./tests/run.sh

# Export a Web y servirlo (exporta siempre antes de servir)
./tools/servir_web.sh

# Regenerar el arte y el audio desde la paleta
./.venv/bin/python tools/generar_arte.py
./.venv/bin/python tools/generar_audio.py

# Medir el game feel antes y después de tunear
godot --headless --fixed-fps 60 --path . -s tools/medir_feel.gd
```

## Documentación

| Documento | Qué contiene |
|---|---|
| [ROADMAP.md](ROADMAP.md) | Fases y estado |
| [TICKETS.md](TICKETS.md) | Backlog con criterios de aceptación |
| [docs/GDD.md](docs/GDD.md) | Reglas, constantes y qué significan al jugar |
| [docs/decisions/](docs/decisions/) | 17 ADRs: cada decisión técnica y por qué |
| [docs/testing.md](docs/testing.md) | Verificación headless y sus trampas |
| [docs/environment.md](docs/environment.md) | Versiones, atajos y exportación |
| [docs/art-guide.md](docs/art-guide.md) | Paleta, tamaños y reglas de arte |
| [docs/perf.md](docs/perf.md) | Medidas de rendimiento y qué no cubren |
| [docs/qa-checklist.md](docs/qa-checklist.md) | Checklist manual antes de cada release |
| [docs/aprendizajes.md](docs/aprendizajes.md) | Lo que ha enseñado el proyecto |

## Contribuir

Proyecto de aprendizaje, pero las issues y PRs son bienvenidas. Lee `TICKETS.md` para el backlog y `docs/decisions/` para las decisiones técnicas.

Convenciones: Conventional Commits, `main` siempre exportable, una rama por ticket, GIF en el PR si cambia algo visible. Antes del primer commit:

```bash
python3 -m venv .venv
./.venv/bin/pip install gdtoolkit pre-commit
./.venv/bin/pre-commit install
```

## Privacidad

Flapo no recoge ningún dato. Ver [política de privacidad](docs/web/privacidad.md).

## Licencia

Código: [MIT](LICENSE). El personaje Flapo (nombre, diseño, sprites, logo) es propiedad de Plazoleta, todos los derechos reservados. Resto de assets propios: CC BY 4.0. Assets de terceros: ver `assets/**/CREDITS.md` (hoy no hay ninguno).
