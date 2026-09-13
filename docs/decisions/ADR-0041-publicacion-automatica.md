# ADR-0041 — Publicar sin tocar nada a mano

Fecha: 2026-09-09 · Estado: aceptada · Depende de [ADR-0007](ADR-0007-tests-headless.md)

## Contexto
T-270 quiere que cada PR publique una build jugable, y T-271 que la versión
salga sola de los Conventional Commits. Los dos son el mismo problema:
**quitar pasos manuales de la publicación**, que son los que se olvidan
justo el día que importa.

## GitHub Pages sirve el juego sin cabeceras, y por eso funciona
Un export Web de Godot **con hilos** necesita `SharedArrayBuffer`, y eso exige
las cabeceras COOP/COEP. Pages **no deja poner cabeceras**: ese camino está
cerrado y no hay forma de abrirlo.

La salida es que el preset Web tiene `variant/thread_support=false`. No es un
apaño para que quepa en Pages: el juego es de 288×512 y su bucle de física
ocupa el 0,45 % del presupuesto de frame (`docs/perf.md`). **No tiene nada que
paralelizar.** Es el criterio del ticket, resuelto por la vía de no necesitar
lo que no se puede tener.

Cada PR va a `/pr-NNN/` y `main` a la raíz, en la rama `gh-pages`. Se publica
con `git` a mano —quince líneas que se leen— en vez de con una acción de
terceros —quince líneas que hay que creerse, más una dependencia que
mantener—.

Al borrar el destino antes de copiar hay que excluir dos cosas: `.git`, o se
borra el propio clon y el push falla sin decir por qué, y `pr-*`, o publicar
en `main` se lleva por delante las builds de las PRs abiertas.

## La trampa del token, que decide la forma del workflow
**Un tag empujado con `GITHUB_TOKEN` no dispara ningún workflow.** GitHub lo
impide a propósito para que un workflow no pueda lanzarse a sí mismo en bucle.

Eso invalida el diseño ingenuo de T-271 —"calculo la versión, pongo el tag, y
ya saltará el job de release"—, y lo peor es **cómo falla**: el tag aparece, no
salta nada, y no hay ningún error que mirar.

Por eso el versionado, el export y la release viven en el **mismo workflow**,
encadenados con `needs`. El disparador por tag se conserva para los tags que
pone una persona: esos sí disparan.

## La cuenta de la versión está en GDScript, no en el YAML
`tools/version.gd` decide qué versión toca, y `tests/test_t271_version.gd` lo
comprueba. La alternativa —un puñado de `sed` en el YAML— **no se puede
probar**, y un número de versión equivocado no se ve hasta que ya está
publicado, cuando ya no se puede quitar.

Está en `tools/` y no en `scripts/` porque no es parte del juego. Pero está en
GDScript y no en Python para poder usarlo con el mismo arnés que todo lo demás
(ADR-0007): en este repo, lo que headless puede ver, se prueba.

Qué mueve el número: `feat` la menor, `fix` y `perf` la de parche, `!` o
`BREAKING CHANGE` la mayor. **Lo demás no publica nada**: un `docs:`, un
`chore:` o un `refactor:` no cambian nada para el jugador y no merecen una
versión.

### En 0.x un breaking no salta a 1.0.0
Sube la menor. Llegar al 1.0 es una decisión de producto —"esto ya está"— y no
la consecuencia de que alguien escriba un `!` en un mensaje de commit. Cuando
el proyecto pase de 1.x, la regla estándar vuelve a aplicarse sola.

## Un bug que encontró probarlo con el historial real
`git describe --tags` **falla** en un repo sin tags. Leyendo stderr mezclado
con stdout, el mensaje `fatal: no tags can describe...` se colaba como si
fuera el nombre del último tag: el rango salía corrupto, `git log` fallaba, y
el script concluía que no había nada que publicar. **Un error convertido en
dato, sin avisar.** Ahora se mira el código de salida y stderr va aparte.

Y otro más tonto y más caro: `project.godot` comenta con `;`, no con `#`. Un
comentario con almohadilla hacía que Godot descartara la línea siguiente, así
que `config/version` existía en el fichero y valía `""` al leerlo.

## Consecuencias
- Nadie edita versiones. `project.godot`, `CHANGELOG.md` y
  `assets/data/changelog.tres` los escribe `tools/versionar.gd`.
- El `.tres` de novedades ya se genera, aunque el menú que lo lee es T-250:
  cuando se haga, el dato ya estará ahí.
- **Falta activar Pages en el repositorio.** Es un interruptor de ajustes que
  no toca este workflow.
- Las PRs desde un fork no publican build: no reciben token de escritura. En
  un proyecto de un solo autor no ocurre; queda anotado por si deja de serlo.
