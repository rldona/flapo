extends SceneTree
## T-041 — Animación de aleteo.

const MAIN := "res://scenes/Main.tscn"

var h: Harness


func _init() -> void:
	h = Harness.new(self)
	print("--- T-041 · Animación ---")
	await _tiene_tres_frames()
	await _acelera_al_aletear()
	await _se_pausa_al_morir()
	await _vuelve_a_animarse_al_reiniciar()
	quit(h.resumen("T-041"))


func _partida() -> Node:
	var main: Node = await h.montar(MAIN, {"log_transitions": false})
	main.pipe_spawner.random_seed = 3
	return main


func _sprite(main: Node) -> AnimatedSprite2D:
	return main.bird.get_node("Sprite")


func _tiene_tres_frames() -> void:
	var main: Node = await _partida()
	var sp: AnimatedSprite2D = _sprite(main)
	var n: int = sp.sprite_frames.get_frame_count("flap")
	h.check("la animación tiene 3 frames", n == 3, "frames: %d" % n)
	h.check("y se está reproduciendo en READY", sp.is_playing(), "")
	main.free()


## Criterio implícito del ticket: más rápida al saltar.
func _acelera_al_aletear() -> void:
	var main: Node = await _partida()
	var sp: AnimatedSprite2D = _sprite(main)
	h.jugar(main)
	await h.ticks(30)
	var reposo: float = sp.speed_scale * 10.0
	h.pulsa(KEY_SPACE)
	await h.ticks(2)
	var tras_aletear: float = sp.speed_scale * 10.0
	h.pulsa(KEY_SPACE, false)
	h.check(
		"la animación acelera al aletear",
		tras_aletear > reposo,
		"%.1f fps en reposo -> %.1f fps al aletear" % [reposo, tras_aletear]
	)
	# Y vuelve sola: si se quedara rápida, el efecto no significaría nada.
	await h.ticks(30)
	h.check(
		"y vuelve al ritmo de reposo",
		is_equal_approx(sp.speed_scale * 10.0, reposo),
		"%.1f fps tras 0,5 s" % (sp.speed_scale * 10.0)
	)
	main.free()


## Criterio: la animación se pausa al morir.
func _se_pausa_al_morir() -> void:
	var main: Node = await _partida()
	var sp: AnimatedSprite2D = _sprite(main)
	h.jugar(main)
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	var frame_al_morir: int = sp.frame
	await h.ticks(60)
	h.check("al morir la animación se pausa", not sp.is_playing(), "")
	h.check(
		"y se queda en el frame del golpe",
		sp.frame == frame_al_morir,
		"frame %d al morir, %d un segundo después" % [frame_al_morir, sp.frame]
	)
	main.free()


func _vuelve_a_animarse_al_reiniciar() -> void:
	var main: Node = await _partida()
	var sp: AnimatedSprite2D = _sprite(main)
	h.jugar(main)
	for tick in 600:
		await physics_frame
		if main.get_state() == GameState.State.GAME_OVER:
			break
	main.restart()
	await h.ticks(2)
	h.check("al reiniciar vuelve a animarse", sp.is_playing(), "")
	main.free()
