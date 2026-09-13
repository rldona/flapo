# ADR-0006 — Tipo de cuerpo físico de Flapo

Fecha: 2026-09-07 · Estado: aceptada

## Contexto
Flapo cae, sube de golpe al aletear, rota según su velocidad vertical y choca
con tuberías y suelo. Godot 4 ofrece cuatro cuerpos 2D y la elección
condiciona todo el resto del juego.

## Opciones
- **`RigidBody2D`**: simulación real. Le aplicas fuerzas o impulsos y el motor
  decide dónde acaba. Suena a lo "correcto" para algo que cae… y es la
  elección equivocada aquí, por tres motivos:
  1. **No es determinista de forma cómoda**: el solver puede dar resultados
     ligeramente distintos, y en un juego donde pasar un hueco de 100 px se
     juega al píxel, eso es injusto.
  2. **El control se pelea con la simulación**: fijar la velocidad de golpe
     (que es lo que hace un Flappy: `velocity.y = impulso`, no "sumar fuerza")
     obliga a escribir dentro de `_integrate_forces`, luchando contra el motor.
  3. **Rebotes y giros gratis**: al rozar una tubería, un rigid body rebota y
     rota por su cuenta. Nosotros queremos que la muerte sea una animación
     escrita, no una simulación.
- **`CharacterBody2D`**: pensado para personajes con control directo. Tú
  escribes `velocity`, llamas a `move_and_slide()` y el motor solo resuelve el
  desplazamiento y las colisiones. Determinista y predecible.
- **`Area2D`**: detecta solapamientos pero no colisiona ni mueve. Sirve para
  la zona de puntuación (**T-026**), no para Flapo.
- **`AnimatableBody2D`**: para plataformas móviles que empujan a otros; Flapo
  no empuja nada.

## Decisión
`CharacterBody2D`, con toda la lógica en `_physics_process` y estas piezas:

- **`_physics_process` y no `_process`.** El primero corre a 60 Hz fijos
  (ADR-0002); el segundo, a los fps que dé la máquina. Con `_process`, la
  gravedad en px/s² daría alturas de salto distintas en un M1 y en un Android
  viejo. La física del juego va donde el reloj es fijo.
- **`Input.is_action_just_pressed` dentro de `_physics_process`.** Godot 4
  sabe desde qué tipo de frame lo llamas, así que no se pierden ni se duplican
  pulsaciones aunque haya varios frames de dibujo por tick de física.
- **Tope de caída (`max_fall_speed`).** Sin él, una caída larga acelera hasta
  que ningún aleteo la compensa y el jugador siente que el control se rompió.
  Es una mentira física deliberada al servicio del control.
- **Rotación por interpolación exponencial**:
  `lerp_angle(rotation, target, 1.0 - exp(-speed * delta))`. Un
  `lerp(rotation, target, 0.2)` a pelo parece equivalente pero depende de los
  fps: a 120 fps gira el doble de rápido que a 60.
- **Techo por `clamp` de posición, no por colisión.** Un `StaticBody2D` arriba
  haría a Flapo rebotar o quedarse pegado; clampeando la posición y cortando
  la velocidad negativa, tocar el techo simplemente frena.

## Consecuencias
- Las constantes (`gravity`, `flap_impulse`, `max_fall_speed`, ángulos) son
  `@export` en el nodo, tuneables en caliente desde el inspector. Se han
  **retirado de `GameConfig`** para que no haya dos fuentes de verdad, tal y
  como anticipaba la ADR-0003. La tabla del GDD sigue siendo la documentación,
  y se cierra con los valores finales en **T-040**.
- Flapo detecta que ha chocado (`get_slide_collision_count() > 0`) y emite
  `died`; **Main** es quien decide que eso significa `GAME_OVER`. El nodo no
  conoce la máquina de estados, solo su propia desgracia.
- `fall_death_y` es una **red de seguridad provisional**: hoy no hay suelo con
  el que chocar, así que Flapo muere al pasar del borde inferior. En **T-027**
  aparece el suelo real y esta comprobación pasa a ser solo un seguro contra
  caídas fuera del mundo.
- Capas de colisión: Flapo en la capa 2, con máscara a la capa 3 (obstáculos:
  tuberías y suelo). Se nombrarán en `project.godot` cuando exista el primer
  obstáculo (**T-024**); hoy la máscara no encuentra nada, que es lo correcto.
- Si algún día hiciera falta física emergente (cajas, ragdoll al morir), no se
  cambia el tipo de Flapo: se añaden rigid bodies aparte.
