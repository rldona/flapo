# Flapo

Un juego de un solo botón: toca para que **Flapo** aletee, cruza los huecos entre tuberías y no toques nada. Inspirado en Flappy Bird.

Primer proyecto de [Plazoleta](https://plazoleta.dev) en desarrollo de videojuegos, hecho de principio a fin en público: diseño, arte, código, audio, pruebas, CI/CD y publicación en itch.io y Google Play.

> Estado: 🔄 Fase 0 — Preparación · [Roadmap](ROADMAP.md) · [Tickets](TICKETS.md) · [GDD](docs/GDD.md)

## Stack

- Godot 4.x · GDScript
- Pixel art: Pixelorama · Audio: Audacity / jsfxr
- CI: GitHub Actions (export Web, Android, Linux, Windows)

## Ejecutar

1. Instala [Godot 4.x](https://godotengine.org/download) (versión en `docs/environment.md`).
2. Clona el repo y abre `project.godot` desde el gestor de proyectos.
3. F5 para ejecutar.

Exportar en local: `godot --headless --export-release "Web" export/web/index.html`.

## Contribuir

Proyecto de aprendizaje, pero las issues y PRs son bienvenidas. Lee `TICKETS.md` para ver el backlog y `docs/decisions/` para las decisiones técnicas. Convenciones: Conventional Commits, `main` siempre exportable, una rama por feature, GIF en el PR si cambia algo visible.

## Licencia

Código: [MIT](LICENSE). El personaje Flapo (nombre, diseño, sprites, logo) es propiedad de Plazoleta, todos los derechos reservados. Resto de assets propios: CC BY 4.0. Assets de terceros: ver `assets/**/CREDITS.md`.
