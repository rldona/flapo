class_name GameState
extends RefCounted
## Estados por los que pasa una partida de Flapo.
##
## Vive en su propio fichero, y no dentro de `main.gd`, para que cualquier
## nodo pueda escribir `GameState.State.PLAYING` en una firma tipada sin
## depender del tipo `Main`. Es solo un contenedor de tipo: nunca se
## instancia y no guarda nada.

enum State {
	MENU,  ## Pantalla de inicio: título, jugar y elección de dificultad.
	READY,  ## Flapo flota sin gravedad, esperando el primer aleteo.
	PLAYING,  ## La partida corre: gravedad, scroll y puntuación.
	GAME_OVER,  ## Flapo ha chocado; el mundo está parado.
}
