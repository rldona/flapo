# Entorno

Versiones con las que se desarrolla Flapo. Se actualiza cuando cambie alguna.
La versión de Godot debe coincidir en tres sitios: esta tabla, `GODOT_VERSION`
y la imagen `barichello/godot-ci` de `.github/workflows/export.yml`.

| Herramienta | Versión | Notas |
|---|---|---|
| Godot | 4.7.2 (stable) | editor, canal estable |
| Export templates | 4.7.2 | siempre la misma que el editor |
| Pixelorama | | arte (T-050 en adelante) |
| Audacity | | audio (Fase 5) |
| gh CLI | | para `scripts/create_issues.py` |
| Python | 3.12 | scripts de utilidad y gdtoolkit en CI |

## Sistema de desarrollo
- macOS (Darwin 25.6), Apple Silicon.

## Notas
- El binario de Godot no está en el `PATH`; para invocarlo en headless desde
  la terminal hay que usar la ruta del `.app`:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless ...`
- Renderizador objetivo: **Compatibility** (OpenGL/WebGL2). Es el único que
  garantiza Web y Android de gama baja; Forward+ no exporta a Web.
