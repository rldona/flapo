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
| gdtoolkit | 4.5.0 | `gdformat` y `gdlint`, en `.venv/` |
| pre-commit | 4.6.2 | hooks de formato y lint, en `.venv/` |
| Python | 3.12 | scripts de utilidad y gdtoolkit en CI |

## Sistema de desarrollo
- macOS (Darwin 25.6), Apple M1 Pro.
- Render en ejecución: `OpenGL API 4.1 Metal - Compatibility`.

## Trampas de `project.godot`

- **Comenta con `;`, no con `#`.** Una línea que empiece por `#` no se ignora:
  Godot la funde con la clave siguiente y acaba escribiendo algo como
  `"#Elsplashsedibuja...boot_splash/bg_color"=Color(...)`. El ajuste queda sin
  aplicar y **no hay ningún error**. Pasó con el color de fondo del splash.
- Godot **borra** del fichero todo ajuste que coincida con el valor por
  defecto del motor, y reescribe la serialización a su gusto. Lo que hay en
  disco tras abrir el editor es la verdad; ver ADR-0004.

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

## Formato y lint

Las herramientas de Python viven en un `.venv/` del proyecto (ignorado por
git), para no tocar el Python del sistema. Tras clonar:

```bash
python3 -m venv .venv
./.venv/bin/pip install gdtoolkit pre-commit
./.venv/bin/pre-commit install
```

A partir de ahí cada commit pasa `gdformat` y `gdlint`. Para lanzarlo a mano
sobre todo el repo:

```bash
./.venv/bin/pre-commit run --all-files
```

El mismo `.pre-commit-config.yaml` lo ejecuta el CI, así que local y CI no
pueden discrepar.

## Exportación

El preset `Web` está en `export_presets.cfg` (versionado, sin secretos). Se
exporta en 3,6 s sin abrir el editor:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --export-release "Web" export/Web/index.html
```

Para probarlo, **usa el script**, que exporta y sirve en ese orden:

```bash
./tools/servir_web.sh          # http://localhost:8060
```

No sirvas `export/Web/` a mano. Servir un build viejo no da ningún error: el
juego carga, funciona, y le faltan las últimas features. Pasó con las frutas
de T-047 y costó un rato de diagnóstico.

Y **recarga forzada en el navegador** (⌘⇧R): el `.wasm` y el `.pck` se cachean
con ganas y una recarga normal puede seguir sirviendo el anterior.

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

Presets disponibles (`export_presets.cfg`, versionado y sin secretos):

| Preset | Salida | Estado |
|---|---|---|
| `Web` | `export/Web/index.html` | ✅ verificado en local y en CI |
| `Linux` | `export/Linux/flapo.x86_64` | ✅ 70 MB |
| `Windows` | `export/Windows/flapo.exe` | ✅ 104 MB |
| `Android` | `export/Android/flapo.apk` | ⚠️ solo depuración |

El export de **release** de Android falla a propósito con *"Could not find
release keystore"*: el keystore de firma es **T-092** y no puede estar en el
repo. El de depuración sí funciona y firma con el keystore que genera Godot:

```bash
godot --headless --path . --export-debug "Android" export/Android/flapo-debug.apk
```

Dos ajustes que exige el export y no son obvios:

- Escritorio necesita `texture_format/s3tc_bptc=true` y Android
  `texture_format/etc2_astc=true`. Godot exige **al menos un formato de
  textura**, aunque nuestro pixel art se importe sin comprimir: el flag solo
  decide qué variantes se empaquetan.
- Android exige además `rendering/textures/vram_compression/import_etc2_astc`
  a `true` en `project.godot`, o el export ni empieza.

## Notas
- El binario de Godot no está en el `PATH`; para invocarlo en headless desde
  la terminal hay que usar la ruta del `.app`:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless ...`
- Godot corre **sin ventana ni GPU** con `--headless`, así que el juego se
  puede verificar desde la terminal y desde CI: ver `docs/testing.md` y
  ADR-0007. Es la base de `./tests/run.sh`.
- Renderizador objetivo: **Compatibility** (OpenGL/WebGL2). Es el único que
  garantiza Web y Android de gama baja; Forward+ no exporta a Web.
