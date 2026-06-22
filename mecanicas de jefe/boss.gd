extends CharacterBody2D

# =============================================================================
# BOSS — Jefe final (máquina de estados)
# =============================================================================
# Diseño ORIGINAL inspirado en los scripts de referencia de "mecanicas de jefe"
# (Follow / Attack / Teleport / SpawnMinion / Death). En lugar de copiarlos,
# combina esos conceptos en un solo jefe con FASES según su vida:
#
#   Fase 1 (>66% vida): perseguir + golpe cuerpo a cuerpo; teletransportes ocasionales.
#   Fase 2 (33–66%):    añade invocación de minions y voleas de proyectiles.
#   Fase 3 (<33%):      enfurecido: más rápido, teletransportes y voleas dobles.
#
# Reutiliza assets existentes (Black Warrior como sprite). Las "animaciones" de
# ataque/teleport se simulan con tintes/escala porque el pack no trae esos
# fotogramas (ver docs/jefe.md para los assets que faltarían).

signal died

enum S { FOLLOW, ATTACK, TELEPORT, SPAWN, RANGED, DEAD }

@export_group("Estadísticas")
@export var max_health: int = 90
@export var move_speed: float = 300.0
@export var contact_damage: int = 4
@export var contact_cooldown: float = 0.8

@export_group("Ataques")
@export var attack_range: float = 170.0
@export var slam_damage: int = 10
@export var slam_radius: float = 150.0
@export var decide_interval: float = 2.0
@export var teleport_distance: float = 220.0
@export var spawn_count: int = 3
@export var ranged_count: int = 14
@export var bullet_damage: int = 3

@export_group("Recompensa")
@export var coin_scene: PackedScene
@export var coins_dropped: int = 12

@export_group("Invocaciones / Proyectiles")
@export var minion_scene: PackedScene
@export var bullet_scene: PackedScene

@export_group("Visual")
@export var idle_sheet: Texture2D
@export var run_sheet: Texture2D
@export var idle_frames: int = 8
@export var run_frames: int = 6
@export var frame_size: int = 192
@export var sprite_scale: float = 1.6

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var bar: ProgressBar = $UI/BossBar

var health: int
var player: Node2D = null
var state: int = S.FOLLOW
var _t: float = 0.0           # temporizador del estado actual
var _acted: bool = false      # si el efecto del estado ya se ejecutó
var _decide_cd: float = 0.0
var _contact_cd: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	health = max_health
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	_build_frames()
	sprite.play("idle")
	player = _find_player()
	bar.max_value = max_health
	bar.value = health
	_decide_cd = decide_interval
	state = S.FOLLOW

# =============================================================================
# CICLO PRINCIPAL
# =============================================================================
func _physics_process(delta: float) -> void:
	if state == S.DEAD:
		return
	if player == null or not is_instance_valid(player):
		player = _find_player()

	_contact_cd = maxf(0.0, _contact_cd - delta)

	match state:
		S.FOLLOW:
			_state_follow(delta)
		S.ATTACK:
			_state_attack(delta)
		S.TELEPORT:
			_state_teleport(delta)
		S.SPAWN:
			_state_spawn(delta)
		S.RANGED:
			_state_ranged(delta)

	move_and_slide()
	_update_facing()
	_contact_check()

func _phase() -> int:
	var f := float(health) / float(max_health)
	if f > 0.66:
		return 1
	elif f > 0.33:
		return 2
	return 3

func _speed_mult() -> float:
	return 0.85 + 0.15 * (_phase() - 1)   # fase 1 lento / fase 2 igual al jugador / fase 3 rápido

# =============================================================================
# ESTADOS
# =============================================================================
func _state_follow(delta: float) -> void:
	if player == null:
		velocity = Vector2.ZERO
		return
	var to_player := player.global_position - global_position
	velocity = to_player.normalized() * move_speed * _speed_mult()
	sprite.play("run")

	if to_player.length() <= attack_range:
		_enter(S.ATTACK)
		return

	_decide_cd -= delta
	if _decide_cd <= 0.0:
		_decide_cd = decide_interval / _phase()
		_choose_special()

func _choose_special() -> void:
	var options := ["teleport"]
	var phase := _phase()
	if phase >= 1 and minion_scene != null:
		options.append("spawn")
	if phase >= 2 and bullet_scene != null:
		options.append("ranged")
		options.append("teleport")
	if phase >= 3:
		options.append("ranged")
	match options[randi() % options.size()]:
		"spawn":
			_enter(S.SPAWN)
		"ranged":
			_enter(S.RANGED)
		_:
			_enter(S.TELEPORT)

func _state_attack(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
	_t -= delta
	if not _acted:
		# Telegrafía del golpe
		sprite.modulate = Color(1.0, 0.55, 0.2)
		if _t <= 0.0:
			_do_slam()
			_acted = true
			_t = 0.35   # recuperación
	else:
		if _t <= 0.0:
			sprite.modulate = Color.WHITE
			_enter(S.FOLLOW)

func _do_slam() -> void:
	sprite.modulate = Color(1.0, 0.3, 0.3)
	if player != null and is_instance_valid(player):
		if global_position.distance_to(player.global_position) <= slam_radius:
			if player.has_method("take_damage"):
				player.take_damage(slam_damage)
	# En fases avanzadas el golpe suelta una pequeña onda de balas
	if _phase() >= 2 and bullet_scene != null:
		_fire_ring(8)

func _state_teleport(delta: float) -> void:
	velocity = Vector2.ZERO
	_t -= delta
	if not _acted:
		# Desvanecer
		sprite.modulate.a = clampf(_t / 0.3, 0.0, 1.0)
		if _t <= 0.0:
			if player != null and is_instance_valid(player):
				var off := Vector2.RIGHT.rotated(randf() * TAU) * teleport_distance
				global_position = player.global_position + off
			_acted = true
			_t = 0.25
	else:
		sprite.modulate.a = clampf(1.0 - _t / 0.25, 0.0, 1.0)
		if _t <= 0.0:
			sprite.modulate = Color.WHITE
			# Tras reaparecer, suele golpear o lanzar volea
			if _phase() >= 2 and randf() < 0.5:
				_enter(S.RANGED)
			else:
				_enter(S.ATTACK)

func _state_spawn(delta: float) -> void:
	velocity = Vector2.ZERO
	_t -= delta
	if not _acted:
		sprite.modulate = Color(0.7, 0.5, 1.0)
		if _t <= 0.0:
			_spawn_minions()
			_acted = true
			_t = 0.3
	else:
		if _t <= 0.0:
			sprite.modulate = Color.WHITE
			_enter(S.FOLLOW)

func _spawn_minions() -> void:
	if minion_scene == null:
		return
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	for i in spawn_count:
		var m = minion_scene.instantiate()
		host.add_child(m)
		m.global_position = global_position + Vector2.RIGHT.rotated(randf() * TAU) * 80.0

func _state_ranged(delta: float) -> void:
	velocity = Vector2.ZERO
	_t -= delta
	if not _acted:
		sprite.modulate = Color(0.4, 0.8, 1.0)
		if _t <= 0.0:
			_fire_ring(ranged_count)
			if _phase() >= 3:
				_fire_ring(ranged_count, deg_to_rad(180.0 / ranged_count))  # segundo anillo desfasado
			_acted = true
			_t = 0.3
	else:
		if _t <= 0.0:
			sprite.modulate = Color.WHITE
			_enter(S.FOLLOW)

func _fire_ring(count: int, offset: float = 0.0) -> void:
	if bullet_scene == null:
		return
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	for i in count:
		var ang := offset + TAU * float(i) / float(count)
		var b = bullet_scene.instantiate()
		host.add_child(b)
		b.global_position = global_position
		if b.has_method("setup"):
			b.setup(Vector2.RIGHT.rotated(ang), bullet_damage)

# =============================================================================
# UTILIDADES DE ESTADO
# =============================================================================
func _enter(new_state: int) -> void:
	state = new_state
	_acted = false
	match new_state:
		S.ATTACK:
			_t = 0.45
		S.TELEPORT:
			_t = 0.3
		S.SPAWN:
			_t = 0.4
		S.RANGED:
			_t = 0.35
		_:
			_t = 0.0

func _contact_check() -> void:
	if _contact_cd > 0.0 or player == null:
		return
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(contact_damage)
			_contact_cd = contact_cooldown
			break

func _update_facing() -> void:
	if player != null and is_instance_valid(player):
		sprite.flip_h = player.global_position.x < global_position.x

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null

# =============================================================================
# VIDA Y MUERTE
# =============================================================================
func take_damage(amount: int) -> void:
	if state == S.DEAD:
		return
	health -= amount
	bar.value = health
	_hit_flash()
	if health <= 0:
		_die()

func _hit_flash() -> void:
	# Solo si no está en medio de un telegrafiado coloreado
	if state == S.FOLLOW:
		sprite.modulate = Color(1, 0.5, 0.5)
		var t := get_tree().create_timer(0.08)
		t.timeout.connect(func():
			if is_instance_valid(self) and state == S.FOLLOW:
				sprite.modulate = Color.WHITE)

func _die() -> void:
	state = S.DEAD
	velocity = Vector2.ZERO
	bar.visible = false
	_drop_coins()
	died.emit()
	queue_free()

func _drop_coins() -> void:
	if coin_scene == null:
		return
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	for i in coins_dropped:
		var c = coin_scene.instantiate()
		host.add_child(c)
		c.global_position = global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(20.0, 90.0)

# =============================================================================
# ANIMACIONES (construidas en runtime desde las hojas)
# =============================================================================
func _build_frames() -> void:
	if sprite.sprite_frames != null:
		return
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_animation(frames, "idle", idle_sheet, idle_frames)
	_add_animation(frames, "run", run_sheet, run_frames)
	sprite.sprite_frames = frames

func _add_animation(frames: SpriteFrames, anim_name: String, sheet: Texture2D, count: int) -> void:
	if sheet == null or count <= 0:
		return
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, true)
	frames.set_animation_speed(anim_name, 10.0)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		frames.add_frame(anim_name, atlas)
