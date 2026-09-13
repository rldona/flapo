class_name Snapshot
extends Node
## La captura del mejor salto (T-077).
##
## Al batir el récord se guarda una imagen de los **últimos segundos de
## vuelo**: el cielo del escenario, las siluetas de las tuberías y Flapo
## repetido a lo largo de su arco, del más transparente al más opaco. Una
## cronofotografía, no una foto fija — porque lo que se quiere compartir es el
## vuelo, no el instante en que se acabó.
##
## ## Por qué no `Viewport.get_texture()`
##
## El ticket lo propone y no se usa, y esto es la decisión de fondo (ADR-0039):
##
## 1. **En headless no hay render.** `get_texture().get_image()` no devuelve
##    nada, así que el criterio del ticket —un test que compruebe cuándo se
##    dispara la captura— sería literalmente inverificable.
## 2. **En Web leer el framebuffer es asíncrono** y depende del navegador. Una
##    captura que a veces sale negra es peor que no tener captura.
##
## Componiendo la imagen a mano, lo que sale es idéntico en el navegador, en
## Android y en un test sin ventana. Y de paso queda mejor: una captura de
## pantalla enseña el frame en que te estrellaste; esta enseña cómo volabas.

## La imagen que se guarda.
const RUTA: String = "user://mejor_salto.png"

## Flapo, para saber a quién seguir. Se asigna en el inspector.
@export var bird: Bird

## El generador de tuberías, para dibujar sus siluetas.
@export var pipe_spawner: PipeSpawner

## Cuántas capturas se han pedido y cuántas han salido. Lo usan los tests: el
## criterio del ticket es *cuándo* se dispara, y eso sí se puede contar.
var _pedidas: int = 0
var _hechas: int = 0

var _estela: Array = []
var _frames: int = 0
var _activo: bool = false
var _cielo: Color = GameConfig.SCENERY_SKY[0]


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	match to:
		GameState.State.MENU, GameState.State.READY:
			_estela.clear()
			_frames = 0
			_activo = false
		GameState.State.PLAYING:
			_activo = true
		GameState.State.GAME_OVER:
			_activo = false


## Main le dice de qué color es el cielo de esta partida (T-057).
func set_sky(color: Color) -> void:
	_cielo = color


func _physics_process(_delta: float) -> void:
	if not _activo or bird == null:
		return
	_frames += 1
	if _frames % _cada_cuantos() != 0:
		return
	_estela.append({"y": bird.position.y, "x": bird.position.x, "tuberias": _tuberias()})
	# Anillo: solo interesan los últimos segundos, así que lo viejo se tira en
	# vez de acumularse hasta el final de la partida.
	while _estela.size() > GameConfig.SNAPSHOT_SAMPLES:
		_estela.pop_front()


## Cada cuántos frames se toma una muestra.
func _cada_cuantos() -> int:
	var total: int = int(GameConfig.SNAPSHOT_SECONDS * 60.0)
	return maxi(total / GameConfig.SNAPSHOT_SAMPLES, 1)


## Las tuberías que hay ahora mismo, como rectángulos.
func _tuberias() -> Array:
	var rects: Array = []
	if pipe_spawner == null:
		return rects
	for hijo in pipe_spawner.get_children():
		if hijo is Pipe:
			var p: Pipe = hijo
			rects.append([p.position.x, p.get_gap_center(), p.gap, p.width])
	return rects


## Compone y guarda la captura. `false` si no había vuelo que contar.
##
## Main solo llama a esto al batir el récord. Se cuenta igual lo pedido y lo
## hecho: así un test puede comprobar que **no se pide** en un Game Over
## normal, que es el criterio del ticket.
func capturar() -> bool:
	_pedidas += 1
	if _estela.is_empty():
		return false
	var img: Image = _componer()
	if img == null:
		return false
	if img.save_png(RUTA) != OK:
		push_warning("No se ha podido guardar la captura del mejor salto.")
		return false
	_hechas += 1
	return true


## Cuántas capturas se han pedido. Lo usan los tests.
func pedidas() -> int:
	return _pedidas


## Cuántas han salido. Lo usan los tests.
func hechas() -> int:
	return _hechas


## Las muestras que se llevan grabadas. Lo usan los tests.
func estela() -> Array:
	return _estela


## Dibuja el cielo, las tuberías del último instante y el arco de Flapo.
func _componer() -> Image:
	var ancho: int = GameConfig.VIEWPORT_SIZE.x
	var alto: int = GameConfig.VIEWPORT_SIZE.y
	var img: Image = Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	img.fill(_cielo)

	# Las tuberías del último instante: dibujar las de cada muestra dejaría la
	# imagen llena de rayas y no se entendería por dónde se pasó.
	for r in _estela[-1]["tuberias"] as Array:
		_pintar_tuberia(img, r, ancho, alto)

	var sprite: Image = _sprite_de_flapo()
	for i in _estela.size():
		var peso: float = float(i) / float(maxi(_estela.size() - 1, 1))
		var alfa: float = lerpf(GameConfig.SNAPSHOT_FADE_MIN, 1.0, peso)
		_pintar_flapo(img, sprite, _estela[i], alfa)

	if GameConfig.SNAPSHOT_SCALE > 1:
		# `INTERPOLATE_NEAREST`: es pixel art, y cualquier otro filtro lo
		# convierte en una acuarela (ADR-0002).
		img.resize(
			ancho * GameConfig.SNAPSHOT_SCALE,
			alto * GameConfig.SNAPSHOT_SCALE,
			Image.INTERPOLATE_NEAREST
		)
	return img


func _pintar_tuberia(img: Image, r: Array, ancho: int, alto: int) -> void:
	var x: int = int(r[0])
	var centro: float = r[1]
	var hueco: float = r[2]
	var grosor: int = maxi(int(r[3]), 1)
	if x + grosor < 0 or x > ancho:
		return
	var arriba: int = clampi(int(centro - hueco * 0.5), 0, alto)
	var abajo: int = clampi(int(centro + hueco * 0.5), 0, alto)
	var x0: int = clampi(int(x - grosor * 0.5), 0, ancho)
	var x1: int = clampi(int(x + grosor * 0.5), 0, ancho)
	if x1 <= x0:
		return
	img.fill_rect(Rect2i(x0, 0, x1 - x0, arriba), GameConfig.SNAPSHOT_PIPE_COLOR)
	img.fill_rect(Rect2i(x0, abajo, x1 - x0, alto - abajo), GameConfig.SNAPSHOT_PIPE_COLOR)


func _pintar_flapo(img: Image, sprite: Image, muestra: Dictionary, alfa: float) -> void:
	if sprite == null:
		return
	var copia: Image = sprite.duplicate()
	if alfa < 1.0:
		_desvanecer(copia, alfa)
	var destino := Vector2i(
		int(muestra["x"]) - copia.get_width() / 2, int(muestra["y"]) - copia.get_height() / 2
	)
	img.blend_rect(copia, Rect2i(Vector2i.ZERO, copia.get_size()), destino)


## Baja el alfa de una imagen pequeña píxel a píxel.
##
## `blend_rect` no acepta un tinte, así que la única forma de tener siluetas
## más transparentes es fabricarlas. Son 16×12 píxeles seis veces: cuesta
## menos que discutirlo.
func _desvanecer(img: Image, alfa: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			c.a *= alfa
			img.set_pixel(x, y, c)


func _sprite_de_flapo() -> Image:
	var tex: Texture2D = load("res://assets/sprites/flapo_0.png")
	return tex.get_image() if tex != null else null
