class_name Hud
extends CanvasLayer
## Marcador de la partida en curso.
##
## `CanvasLayer` por lo mismo que el panel de Game Over: la UI vive en
## coordenadas de pantalla y no la arrastra el scroll del mundo.
##
## No cuenta nada ni pregunta nada: se limita a enseñar lo que Main le manda
## por `score_changed`. Si algún día el marcador se desincroniza, el fallo
## está en quien cuenta, no aquí.

@onready var _score_label: Label = $Score


func _ready() -> void:
	visible = false


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	# Solo durante la partida: en READY estorbaría a la pantalla de inicio y
	# en GAME_OVER lo sustituye el panel, que ya enseña la puntuación.
	visible = to == GameState.State.PLAYING


func set_score(score: int) -> void:
	_score_label.text = str(score)
