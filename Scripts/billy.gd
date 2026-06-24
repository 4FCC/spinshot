class_name Personaje
extends CharacterBody2D

# Se emite cuando el jugador muere (lo usa el GameMode para la pantalla de muerte)
signal died

# =============================================================================
# MÁQUINA DE ESTADOS DEL PERSONAJE
# =============================================================================
# Estados esenciales: movimiento, esquive y recibir daño.
enum State {
	MOVE,            # Movimiento normal
	DODGE,           # Esquive (gira sobre sí mismo e invulnerable)
	TAKING_DAMAGE,   # Recibiendo daño (invulnerabilidad temporal)
	DEAD             # Muerto
}
var current_state: State = State.MOVE

# Cuántos píxeles de mundo se ven verticalmente independientemente del tamaño de ventana
const _CAMERA_TARGET_HEIGHT := 768.0

# =============================================================================
# NODOS DE LA ESCENA
# =============================================================================
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

# UI (HUD): barra de vida y barra/etiqueta del esquive
@onready var health_bar: TextureProgressBar = $HUD/Root/HealthBar
@onready var health_label: Label = $HUD/Root/HealthBar/HealthLabel
@onready var dodge_bar: TextureProgressBar = $HUD/Root/DodgeBar
@onready var coins_label: Label = $HUD/Root/Coins/CoinsLabel

# =============================================================================
# PROPIEDADES CONFIGURABLES
# =============================================================================
@export var speed: float = 300.0
@export var acceleration: float = 1500.0
@export var friction: float = 1800.0
@export var vida: int = 20
@export var vida_max: int = 20

@export_group("Esquive")
@export var dodge_speed: float = 600.0       # Velocidad durante el esquive
@export var dodge_duration: float = 0.4      # Cuánto dura el esquive
@export var dodge_cooldown_time: float = 1.0 # Tiempo hasta poder esquivar de nuevo
@export var dodge_spin_turns: float = 1.0    # Vueltas completas que gira el sprite

@export_group("Daño")
@export var invulnerability_duration: float = 0.9

@export_group("Spin-Bullet")
@export var spin_bullet_scene: PackedScene   # Escena de la bala que orbita
@export var bullet_damage: int = 3           # Daño de cada Spin-Bullet (mejorable)
@export var shoot_cooldown_time: float = 0.5  # Cadencia de disparo (mejorable)

# =============================================================================
# VARIABLES INTERNAS
# =============================================================================
var input_direction: Vector2
var last_direction: Vector2 = Vector2.DOWN
var is_invulnerable: bool = false
var is_frozen: bool = false   # Congelado mientras la tienda está abierta

# Dirección y giro acumulado del esquive (para la animación de girar)
var dodge_direction: Vector2 = Vector2.ZERO
var dodge_elapsed: float = 0.0

# Timers
var dodge_timer: Timer        # Duración del esquive
var dodge_cooldown: Timer     # Enfriamiento del esquive
var damage_timer: Timer       # Invulnerabilidad tras recibir daño
var shoot_cooldown: Timer     # Cadencia entre Spin-Bullets

# =============================================================================
# NIVELES DE ÍTEMS (habilidades especiales, ver tienda y docs/items.md)
# =============================================================================
var coin_heal_level: int = 0   # Robo de vida al recoger monedas (máx 3 -> 75%)
var bounce_level: int = 0      # Rebote ofensivo: SpinShots extra al impactar (máx 3)
var has_split: bool = false    # División de proyectil (única)
var lethal_level: int = 0      # Giro letal: +1% por nivel (ilimitado)
var autododge_level: int = 0   # Esquiva automática al recibir daño (máx 3 -> 75%)

# Inventario de ítems comprados: id -> {name, desc, icon, count}
var inventory: Dictionary = {}

# Depuración (solo DEV-ROOM)
var debug_invincible: bool = false

# Código secreto (estilo Konami): arriba arriba abajo abajo izquierda derecha izquierda derecha
# alterna el modo dios. Disponible en cualquier partida, no solo en DEV-ROOM.
const _CHEAT_SEQUENCE := ["Arriba", "Arriba", "Abajo", "Abajo", "Izquierda", "Derecha", "Izquierda", "Derecha"]
const _CHEAT_RESET_MS := 1500
var _cheat_step: int = 0
var _cheat_last_ms: int = 0
var _god_mode_tween: Tween = null

# Efecto de partículas (nube de polvo de la esquiva automática)
const EFFECT_SCENE := preload("res://Scenes/Effect.tscn")

# =============================================================================
# INICIALIZACIÓN
# =============================================================================
func _ready():
	add_to_group("player")
	_setup_timers()
	vida = clamp(vida, 0, vida_max)
	health_bar.max_value = vida_max
	_update_health_ui()
	_update_dodge_ui()
	sprite.play("idle")
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	_update_camera_zoom()
	get_viewport().size_changed.connect(_update_camera_zoom)
	_style_hud()
	# Contador de monedas (sprite + cantidad) bajo la barra de esquive
	Game.coins_changed.connect(_update_coins_ui)
	_update_coins_ui(Game.coins)

func _style_hud() -> void:
	# Las barras usan los sprites (04.png) definidos en la escena.
	# Aquí solo damos color/legibilidad al texto que va encima.
	UiTheme.apply_label(health_label)
	UiTheme.apply_label(coins_label)

func _update_coins_ui(total: int) -> void:
	coins_label.text = str(total)

func _update_camera_zoom() -> void:
	var vp_h := get_viewport().get_visible_rect().size.y
	var z := vp_h / _CAMERA_TARGET_HEIGHT
	camera.zoom = Vector2(z, z)

func _setup_timers():
	# Timer que controla la duración del esquive
	dodge_timer = Timer.new()
	dodge_timer.wait_time = dodge_duration
	dodge_timer.one_shot = true
	dodge_timer.timeout.connect(_on_dodge_timer_timeout)
	add_child(dodge_timer)

	# Timer del enfriamiento (cooldown) del esquive
	dodge_cooldown = Timer.new()
	dodge_cooldown.wait_time = dodge_cooldown_time
	dodge_cooldown.one_shot = true
	add_child(dodge_cooldown)

	# Timer de invulnerabilidad tras recibir daño
	damage_timer = Timer.new()
	damage_timer.wait_time = invulnerability_duration
	damage_timer.one_shot = true
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	add_child(damage_timer)

	# Timer de la cadencia de disparo
	shoot_cooldown = Timer.new()
	shoot_cooldown.wait_time = shoot_cooldown_time
	shoot_cooldown.one_shot = true
	add_child(shoot_cooldown)

# =============================================================================
# ENTRADA NO PROCESADA (disparo de la Spin-Bullet)
# =============================================================================
func _unhandled_input(event):
	if current_state == State.DEAD:
		return
	_check_cheat_code(event)
	if is_frozen:
		return
	# Clic derecho: Spin-Bullet con patrón normal (espiral)
	if event.is_action_pressed("shoot"):
		_shoot_spin_bullet(0)
	# Clic izquierdo: Spin-Bullet con patrón alterno (espiral ondulada)
	elif event.is_action_pressed("shoot_alt"):
		_shoot_spin_bullet(1)

# =============================================================================
# CÓDIGO SECRETO (GOD MODE)
# =============================================================================
func _check_cheat_code(event: InputEvent) -> void:
	var pressed_action := ""
	for action in ["Arriba", "Abajo", "Izquierda", "Derecha"]:
		if event.is_action_pressed(action):
			pressed_action = action
			break
	if pressed_action == "":
		return

	var now := Time.get_ticks_msec()
	if _cheat_step > 0 and now - _cheat_last_ms > _CHEAT_RESET_MS:
		_cheat_step = 0

	if pressed_action == _CHEAT_SEQUENCE[_cheat_step]:
		_cheat_step += 1
		_cheat_last_ms = now
		if _cheat_step >= _CHEAT_SEQUENCE.size():
			_cheat_step = 0
			_toggle_secret_god_mode()
	elif pressed_action == _CHEAT_SEQUENCE[0]:
		_cheat_step = 1
		_cheat_last_ms = now
	else:
		_cheat_step = 0

func _toggle_secret_god_mode() -> void:
	debug_invincible = not debug_invincible
	print("Código secreto: God mode %s" % ("ACTIVADO" if debug_invincible else "DESACTIVADO"))
	if debug_invincible:
		_start_god_mode_blink()
	else:
		_stop_god_mode_blink()

func _start_god_mode_blink() -> void:
	_stop_god_mode_blink()
	_god_mode_tween = create_tween()
	_god_mode_tween.set_loops()
	_god_mode_tween.tween_property(sprite, "modulate:a", 0.3, 0.25)
	_god_mode_tween.tween_property(sprite, "modulate:a", 1.0, 0.25)

func _stop_god_mode_blink() -> void:
	if _god_mode_tween != null and _god_mode_tween.is_valid():
		_god_mode_tween.kill()
	_god_mode_tween = null
	sprite.modulate.a = 1.0

# =============================================================================
# MÁQUINA DE ESTADOS PRINCIPAL
# =============================================================================
func _physics_process(delta):
	# El jugador choca con los enemigos (capa 2) normalmente, pero los ATRAVIESA
	# mientras es invulnerable (tras recibir daño o durante el esquive).
	set_collision_mask_value(2, not is_invulnerable)

	if is_frozen:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		_update_walk_animation()
		_update_dodge_ui()
		return

	match current_state:
		State.MOVE:
			move_state(delta)
		State.DODGE:
			dodge_state(delta)
		State.TAKING_DAMAGE:
			taking_damage_state(delta)
		State.DEAD:
			dead_state(delta)

	# El HUD del esquive se refresca siempre (para ver bajar el cooldown)
	_update_dodge_ui()

# =============================================================================
# ESTADO: MOVIMIENTO
# =============================================================================
func move_state(_delta):
	_read_movement_input(_delta)
	_update_walk_animation()

	# Iniciar esquive: requiere dirección y que el cooldown haya terminado
	if Input.is_action_just_pressed("dodge") and dodge_cooldown.is_stopped():
		start_dodge()

func _read_movement_input(delta: float) -> void:
	input_direction = Input.get_vector("Izquierda", "Derecha", "Arriba", "Abajo")
	var target := input_direction.normalized() * speed
	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(target, acceleration * delta)
		last_direction = input_direction.normalized()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

# =============================================================================
# ESTADO: ESQUIVE (GIRAR)
# =============================================================================
func start_dodge():
	current_state = State.DODGE
	dodge_elapsed = 0.0

	# La dirección del esquive es la del input o, si está quieto, la última
	dodge_direction = input_direction.normalized()
	if dodge_direction == Vector2.ZERO:
		dodge_direction = last_direction

	velocity = dodge_direction * dodge_speed
	is_invulnerable = true

	dodge_timer.start()
	dodge_cooldown.start()

func dodge_state(delta):
	# Mantener el impulso del esquive
	velocity = dodge_direction * dodge_speed
	move_and_slide()

	# GIRAR: el sprite rota proporcionalmente a lo que dura el esquive
	dodge_elapsed += delta
	var t = clampf(dodge_elapsed / dodge_duration, 0.0, 1.0)
	sprite.rotation = t * TAU * dodge_spin_turns

func _on_dodge_timer_timeout():
	is_invulnerable = false
	sprite.rotation = 0.0
	velocity = Vector2.ZERO
	if current_state == State.DODGE:
		current_state = State.MOVE

# =============================================================================
# ESTADO: RECIBIR DAÑO
# =============================================================================
func take_damage(amount: int):
	# Modo invencible de depuración (solo se activa desde DEV-ROOM)
	if debug_invincible:
		return
	# No recibir daño si está muerto, invulnerable o esquivando
	if current_state == State.DEAD or is_invulnerable or current_state == State.DODGE:
		return

	# Esquiva automática (ítem): probabilidad de esquivar el golpe por completo.
	# Suelta una nube de polvo para indicarlo visualmente.
	if autododge_level > 0 and randf() < 0.25 * autododge_level:
		_spawn_autododge_dust()
		start_dodge()
		return

	current_state = State.TAKING_DAMAGE
	vida = clamp(vida - amount, 0, vida_max)
	_update_health_ui()

	# Tinte rojo para indicar el golpe
	sprite.modulate = Color(1, 0.4, 0.4)

	if vida <= 0:
		_die()
		return

	is_invulnerable = true
	damage_timer.start()

func _spawn_autododge_dust() -> void:
	"""Nube de polvo de la esquiva automática (efecto del spritesheet 25)."""
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		return
	var fx = EFFECT_SCENE.instantiate()
	host.add_child(fx)
	fx.global_position = global_position
	fx.scale = Vector2(1.6, 1.6)
	fx.play_effect("dust")

func taking_damage_state(_delta):
	# Se puede seguir moviendo mientras dura la invulnerabilidad
	_read_movement_input(_delta)
	_update_walk_animation()

	# También se puede esquivar para escapar
	if Input.is_action_just_pressed("dodge") and dodge_cooldown.is_stopped():
		start_dodge()

func _on_damage_timer_timeout():
	# Si estamos esquivando, NO tocar la invulnerabilidad: el esquive la controla
	# (así el dodge mantiene invulnerabilidad durante todo su recorrido).
	if current_state == State.DODGE:
		return
	is_invulnerable = false
	sprite.modulate = Color.WHITE
	if current_state == State.TAKING_DAMAGE:
		current_state = State.MOVE

# =============================================================================
# ESTADO: MUERTE
# =============================================================================
func _die():
	current_state = State.DEAD
	velocity = Vector2.ZERO
	sprite.modulate = Color(0.5, 0.5, 0.5)
	sprite.play("idle")
	died.emit()

func dead_state(_delta):
	velocity = Vector2.ZERO
	move_and_slide()

# =============================================================================
# SPIN-BULLET
# =============================================================================
func _shoot_spin_bullet(pattern: int = 0):
	"""Instancia la Spin-Bullet y la pone a orbitar alrededor del jugador en la
	dirección del mouse. 'pattern' elige la trayectoria de giro (0/1)."""
	if spin_bullet_scene == null or not shoot_cooldown.is_stopped():
		return

	var dir = get_global_mouse_position() - global_position
	if dir.length() < 1.0:
		dir = last_direction

	var bullet = spin_bullet_scene.instantiate()
	bullet.damage = bullet_damage
	# Habilidades de ítems que lleva cada SpinShot
	bullet.bounce_count = bounce_level
	bullet.has_split = has_split
	bullet.lethal_chance = lethal_level * 0.01
	bullet.bullet_scene = spin_bullet_scene
	# Añadir a la raíz de la escena para que orbite en espacio de mundo
	var host = get_tree().current_scene
	if host == null:
		host = get_parent()
	host.add_child(bullet)

	# setup() coloca la bala, fija el centro de giro y el patrón de trayectoria
	if bullet.has_method("setup"):
		bullet.setup(self, dir, pattern)

	shoot_cooldown.start()

# =============================================================================
# ANIMACIONES DEL PERSONAJE
# =============================================================================
func _update_walk_animation():
	"""Alterna entre correr/idle y voltea el sprite según la dirección horizontal."""
	if input_direction.x != 0.0:
		sprite.flip_h = input_direction.x < 0.0

	if velocity.length() > 1.0:
		sprite.play("run")
	else:
		sprite.play("idle")

# =============================================================================
# ACTUALIZACIÓN DEL HUD
# =============================================================================
func _update_health_ui():
	health_bar.value = vida
	# Solo la cantidad de vida actual.
	health_label.text = str(vida)

func _update_dodge_ui():
	if dodge_cooldown == null:
		return

	# La barra de esquive no muestra texto; solo se llena/atenúa.
	if dodge_cooldown.is_stopped():
		dodge_bar.value = dodge_bar.max_value
		dodge_bar.modulate = Color.WHITE
	else:
		var ratio = 1.0 - (dodge_cooldown.time_left / dodge_cooldown.wait_time)
		dodge_bar.value = ratio * dodge_bar.max_value
		dodge_bar.modulate = Color(0.75, 0.75, 0.8)

# =============================================================================
# CONGELAR (usado por la tienda)
# =============================================================================
func set_frozen(value: bool) -> void:
	is_frozen = value
	if is_frozen:
		velocity = Vector2.ZERO
		sprite.play("idle")

func set_hud_visible(value: bool) -> void:
	"""Muestra/oculta el HUD del jugador (vida, esquive, ayuda) para que no
	estorbe al abrir el inventario u otras pantallas."""
	if has_node("HUD/Root"):
		$HUD/Root.visible = value

# =============================================================================
# MEJORAS (usadas por la tienda)
# =============================================================================
func full_heal() -> void:
	"""Cura al jugador al máximo (curación automática entre rondas)."""
	vida = vida_max
	_update_health_ui()

func upgrade_max_health(amount: int) -> void:
	vida_max += amount
	vida = clamp(vida + amount, 0, vida_max)  # también cura
	health_bar.max_value = vida_max
	_update_health_ui()

func upgrade_bullet_damage(amount: int) -> void:
	bullet_damage += amount

func upgrade_speed(amount: float) -> void:
	speed += amount

func upgrade_fire_rate(factor: float) -> void:
	"""Mejora la cadencia reduciendo el cooldown entre disparos."""
	shoot_cooldown_time = maxf(0.05, shoot_cooldown_time * factor)
	if shoot_cooldown != null:
		shoot_cooldown.wait_time = shoot_cooldown_time

# =============================================================================
# ÍTEMS CON HABILIDAD ESPECIAL
# =============================================================================
func add_coin_heal() -> void:
	coin_heal_level = min(coin_heal_level + 1, 3)

func add_bounce() -> void:
	bounce_level = min(bounce_level + 1, 3)

func enable_split() -> void:
	has_split = true

func add_lethal() -> void:
	lethal_level += 1   # ilimitado, +1% por compra

func add_autododge() -> void:
	autododge_level = min(autododge_level + 1, 3)

func on_coin_collected() -> void:
	"""Robo de vida: cada moneda tiene 25% por nivel de curar 1-3 (máx 75%)."""
	if coin_heal_level <= 0:
		return
	if randf() < 0.25 * coin_heal_level:
		vida = clamp(vida + randi_range(1, 3), 0, vida_max)
		_update_health_ui()

# =============================================================================
# INVENTARIO (registro de ítems comprados, para la UI de inventario)
# =============================================================================
func register_item(item: Dictionary) -> void:
	var id := String(item.get("id", ""))
	if id == "":
		return
	if inventory.has(id):
		inventory[id]["count"] += 1
	else:
		inventory[id] = {
			"name": item.get("name", id),
			"desc": item.get("desc", ""),
			"icon": item.get("icon", null),
			"count": 1,
		}

func get_item_count(id: String) -> int:
	return inventory[id]["count"] if inventory.has(id) else 0
