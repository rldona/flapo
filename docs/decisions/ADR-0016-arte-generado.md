# ADR-0016 — El arte que no es Flapo se genera por código

Fecha: 2026-09-08 · Estado: aceptada

## Contexto
La Fase 4 pide sustituir todos los placeholders: tubería, suelo, fondo, UI,
medallas, logo, icono y splash. Todo eso es pixel art plano de pocos colores
y formas simples: franjas, siluetas, discos, dígitos.

Dibujarlo a mano en Pixelorama es perfectamente posible, pero tiene un coste
que aquí importa: **si cambia la paleta hay que repintarlo todo**. Y la paleta
acaba de cambiar una vez (T-011) y va a volver a moverse cuando el juego se
vea entero.

## Decisión
`tools/generar_arte.py` dibuja por código todo el arte salvo Flapo, leyendo
los colores de la paleta del proyecto. Se ejecuta con el venv del repo:

```bash
./.venv/bin/python tools/generar_arte.py
```

**Flapo queda fuera a propósito.** Es el personaje y la mascota del estudio:
tiene que dibujarlo una persona. Lo que hay en `assets/sprites/flapo_*.png`
es una reconstrucción del arte entregado (ADR-0015), pendiente de retoque a
mano en `assets/sprites/src/candidatos/`.

## Consecuencias
- Cambiar un color de la paleta es editar una constante y regenerar. No hay
  arte que se quede desincronizado con `docs/art-guide.md`.
- El generador documenta la intención de cada pieza mejor que el PNG: por qué
  la tubería tiene una columna clara y otra oscura, por qué los guijarros del
  suelo no tocan los bordes laterales (costura al repetir), por qué la cabeza
  de la tubería es 4 px más ancha que el cuerpo.
- **La tubería y el suelo se repiten, no se estiran.** Los dos son `Sprite2D`
  con `region_enabled` y `texture_repeat`: la región es mayor que la textura,
  así que el motor la repite. Es lo que cumple el criterio de T-051 ("se
  estira a cualquier altura sin deformar la cabeza") sin `NinePatchRect`.
- **Las cifras del marcador son una fuente de mapa de bits propia.** El atlas
  es un PNG y el descriptor un `.fnt` en formato BMFont, que es texto plano y
  Godot importa directamente: no hace falta ninguna herramienta externa para
  generarlo ni para mantenerlo.
- El icono de la app se dibuja a 64×64 y se escala a 512 con `NEAREST`: así
  el icono de tienda sigue siendo pixel art nítido y no una foto borrosa de
  un pixel art.
- Se elimina `icon.svg`, el icono por defecto de Godot.
- Este arte **sigue siendo placeholder en calidad**, no en integración: está
  en la paleta, importado bien y montado en las escenas, pero es geometría
  simple. Sustituirlo por dibujo a mano es cambiar el PNG, sin tocar código.
