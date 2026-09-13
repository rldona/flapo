# Entorno

Versiones con las que se desarrolla Flapo. Se actualiza cuando cambie alguna.
La versión de Godot debe coincidir en tres sitios: esta tabla, `GODOT_VERSION`
y la imagen `barichello/godot-ci` de `.github/workflows/export.yml`.

| Herramienta | Versión | Notas |
|---|---|---|
| Godot | 4.7.2.stable.official (ed1daf0bf) | verificado en el banner de arranque |
| Export templates | 4.7.2 | instaladas: Web, Web Single-Threaded, Android, macOS, Windows x86_64, Linux x86_64, ICU Data |
| Pixelorama | | arte (T-050 en adelante) |
| Audacity | | audio (Fase 5) |
| gh CLI | | para `scripts/create_issues.py` |
| Python | 3.12 | scripts de utilidad y gdtoolkit en CI |

## Sistema de desarrollo
- macOS (Darwin 25.6), Apple M1 Pro.
- Render en ejecución: `OpenGL API 4.1 Metal - Compatibility`.

## Atajos del editor en macOS
Godot usa atajos distintos a los de Windows/Linux; F5 y F6 no funcionan (y en
teclados Apple los captura el sistema).

| Acción | macOS |
|---|---|
| Run Project (escena principal) | ⌘B |
| Run Current Scene | ⌘R |
| Detener | ⌘. |
| Project Settings | ⌘⇧O |

También están los botones ▶ / ▶-claqueta / ■ arriba a la derecha.

## Exportación

El preset `Web` está en `export_presets.cfg` (versionado, sin secretos). Se
exporta en 3,6 s sin abrir el editor:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --export-release "Web" export/Web/index.html
```

Para probarlo hay que servirlo por HTTP: el navegador bloquea WebAssembly
sobre `file://`.

```bash
cd export/Web && python3 -m http.server 8060
```

Decisiones del preset:

- `variant/thread_support=false` → usa la plantilla **Web Single-Threaded**,
  que **no exige las cabeceras COOP/COEP** (`SharedArrayBuffer`). Es lo que
  hace que el build funcione en itch.io sin configuración extra. Se revisa en
  T-093 si el rendimiento no da.
- `variant/extensions_support=false` → no usamos GDExtension; el binario
  pesa menos y arranca antes.
- `vram_texture_compression/*=false` → la compresión VRAM es con pérdida y
  emborrona el pixel art. El arte va en modo lossless (`docs/art-guide.md`).
- `exclude_filter="tests/*"` → los tests no se envían al jugador.

Faltan los presets de Android, Linux y Windows: son T-090.

## Notas
- El binario de Godot no está en el `PATH`; para invocarlo en headless desde
  la terminal hay que usar la ruta del `.app`:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless ...`
- Godot corre **sin ventana ni GPU** con `--headless`, así que el juego se
  puede verificar desde la terminal y desde CI: ver `docs/testing.md` y
  ADR-0007. Es la base de `./tests/run.sh`.
- Renderizador objetivo: **Compatibility** (OpenGL/WebGL2). Es el único que
  garantiza Web y Android de gama baja; Forward+ no exporta a Web.
