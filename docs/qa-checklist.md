# Checklist de QA manual

Se ejecuta **antes de cada release** (T-081). Lo que está aquí es
deliberadamente lo que los tests automáticos **no** pueden comprobar: todo lo
visual, lo sonoro y lo que se siente. Lo demás lo cubre `./tests/run.sh`.

Fecha de la última pasada: _(sin ejecutar)_ · Versión: _(—)_

## 1. Arranque y presentación
- [ ] El splash aparece nítido, sin suavizado, y no se queda colgado.
- [ ] El icono de la app se ve correcto en el escritorio o el lanzador.
- [ ] En `READY` el mundo está vivo: suelo y parallax se mueven, Flapo flota
      quieto y **sin girarse**.
- [ ] El marcador NO se ve en `READY`.

## 2. Escalado y pantalla
- [ ] A 1x, 2x y 3x los píxeles son cuadrados y del mismo tamaño.
- [ ] Al redimensionar, la imagen salta entre tamaños discretos con barras
      **del color del cielo**, nunca negras.
- [ ] En vertical con notch, el marcador queda por debajo del recorte.
- [ ] Rotar el dispositivo no rompe la colocación del HUD.

## 3. Bucle de juego
- [ ] El primer toque arranca la partida **y** hace aletear a Flapo.
- [ ] Flapo no se sale por arriba, y al soltar baja sin quedarse pegado.
- [ ] Chocar con tubería mata. Chocar con el suelo mata.
- [ ] Pasar el hueco suma exactamente 1, aunque se aletee dentro.
- [ ] Jugar 5 minutos seguidos sin nada raro.

## 4. Muerte y reinicio
- [ ] Se ve el flash, se nota la sacudida y la congelación de 80 ms.
- [ ] Flapo rebota, gira aturdido y se queda sobre el suelo.
- [ ] El panel tarda ~0,5 s en salir y entra creciendo.
- [ ] La medalla que sale es la que toca (10 croqueta, 20 tortilla, 40 jamón).
- [ ] "¡Nuevo récord!" solo aparece cuando de verdad lo es.
- [ ] Reiniciar 10 veces seguidas deja el juego como nuevo cada vez.

## 5. Pausa y foco
- [ ] La acción `pause` para el mundo entero y saca el velo.
- [ ] Mandar la app a segundo plano y volver **no mata a Flapo**.
- [ ] Al reanudar, Flapo sigue donde estaba.

## 6. Audio
- [ ] Suenan aleteo, punto, golpe y botón, y ninguno crepita.
- [ ] El aleteo no corta el sonido del punto al puntuar aleteando.
- [ ] El botón de silencio calla todo.
- [ ] El silencio sobrevive a cerrar y abrir el juego.

## 7. Persistencia
- [ ] El récord sobrevive a cerrar y abrir.
- [ ] Borrar `user://save.cfg` a mano no rompe el juego: empieza a 0.

## 8. Web (itch.io)
- [ ] Carga en Chrome, Firefox y Safari móvil.
- [ ] El toque en móvil funciona igual que el click.
- [ ] No hay errores en la consola del navegador.

## 9. Cierre
- [ ] `./tests/run.sh` en verde.
- [ ] CI en verde en el commit que se va a etiquetar.
- [ ] Cero issues `bug` bloqueantes abiertas.
