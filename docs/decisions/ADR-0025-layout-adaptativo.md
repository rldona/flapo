# ADR-0025 — Layout adaptativo: un cálculo continuo, no dos layouts

Fecha: 2026-09-08 · Estado: aceptada · Extiende [ADR-0002](ADR-0002-escalado.md)

## Contexto
Hasta T-085 la idea implícita era "layout de móvil" y "layout de escritorio":
dos casos, elegidos una vez al arrancar. Eso tiene dos problemas. El primero
es que las proporciones reales no son dos —16:9, 21:9, 4:3, un móvil vertical
de 20:9, una ventana de navegador que el usuario arrastra— y cualquier lista
de casos deja fuera el siguiente. El segundo es que **la ventana cambia de
tamaño mientras el juego corre**, y un layout elegido al arrancar se queda
viejo en cuanto alguien toca el borde.

## Decisión
No hay casos. Hay una función del tamaño de la ventana:

```
escala   = clamp(min(ancho ÷ 288, alto ÷ 512), 1, 6)   ← división ENTERA
playfield = 288·escala × 512·escala, centrado
margen    = lo que sobra a UN lado, nunca negativo
```

`LayoutDirector` escucha `size_changed` de la raíz —que se emite en vivo al
arrastrar el borde, no solo al arrancar— y publica escala, caja y margen por
señal. **No dibuja nada**: quien decida qué hacer con el hueco es otro
(T-086). "Signal up", como el resto del juego.

### Por qué no contradice ADR-0002
ADR-0002 sigue mandando **dentro del playfield**, y esto no lo toca:
`project.godot` conserva `stretch/mode=viewport`, `scale_mode=integer` y el
encuadre fijo de 288×512. La escala que calcula este ADR es entera por la
misma razón que allí: un 2,37x haría que unos píxeles midieran 2 y otros 3, y
la imagen herviría al hacer scroll. Hasta el centrado usa división entera,
porque medio píxel de desplazamiento metería el escalado fraccionario por la
puerta de atrás.

Lo que añade este ADR no es una forma distinta de escalar, es **saber** a qué
escala se está dibujando y cuánto sitio sobra. Antes esa información existía
solo dentro del motor.

### Por qué hay un tope de 6x
Sin tope, un monitor 4K daría 4x y uno de 8K daría 8x, y un juego de 288 px
de ancho ocupando una pared se ve absurdo. El tope es una decisión de
producto, no una limitación.

Ojo al número: en 4K la escala es **4x, no 13x**. Manda el alto, porque el
playfield es vertical. Es el tipo de cuenta que uno da por supuesta al revés.

## Consecuencias
- La señal solo se emite cuando el layout **cambia de verdad**. Arrastrar un
  borde dispara `size_changed` en cada píxel, y la escala entera cambia una
  vez cada 288: emitir en cada píxel sería ruido para quien escuche.
- Ventanas imposibles (0 px, negativas, más pequeñas que el playfield) caen
  en la escala mínima y margen 0. Por debajo de 1x no se encoge el pixel art:
  se prefiere que la ventana recorte.
- El margen publicado es el de **un lado**, no la suma. Lo que decide si cabe
  un panel al lado es el hueco de un lado.
- `tests/test_t085_layout.gd` prueba 11 tamaños reales, incluidos los raros
  (300×2000, 2000×300, 200×300). Todo es puro y estático, así que se prueba
  sin ventana — que es lo único posible en headless.

## Aviso para T-086: esto no basta para pintar en el margen
**Con `stretch/mode=viewport` no se puede dibujar nada fuera del playfield.**
Todo el juego, UI incluida, se renderiza en un búfer de 288×512 y ese búfer
se estira; las barras de alrededor son negro del motor, no un lienzo. Este
ADR calcula cuánto sitio sobra, pero ese sitio **hoy no es dibujable**.

T-086 pide enseñar contenido ahí, así que tendrá que elegir entre:

1. **Mover el playfield a un `SubViewport`** dentro de una raíz que corra a
   la resolución real de la ventana. El playfield conserva su pixel art
   exacto y el resto de la escena puede dibujar a resolución nativa. Es lo
   correcto, y obliga a revisar ADR-0002 y a tocar cómo se monta la escena.
2. **Dejar el margen en negro** y considerar T-086 fuera de alcance en v1.

No se decide aquí porque no es el alcance de T-085 y porque la opción 1 es
un cambio estructural que merece su propia ADR y su propio ticket.
