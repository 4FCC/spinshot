class_name Enemy
extends CharacterBody2D

# =============================================================================
# ENEMY — Enemigo base (cuerpo a cuerpo)
# =============================================================================
# Persigue al jugador y le hace daño por contacto. Las subclases (p. ej.
# BulletMinion) pueden redefinir _update_ai() para otros comportamientos.
#
# Las animaciones se construyen en tiempo de ejecución a partir de las hojas
# de sprites asignadas, para no depender de un SpriteFrames por enemigo.

@export_group("Estadísticas")
@export var max_health: int = 6
@export var contact_damage: int = 2
@export var move_speed: float = 120.0
@export var attack_cooldown: float = 0.8
@export var melee_enabled: bool = true
@export var stop_distance: float = 50.0
@export var lethal_spin_time: float = 1.0   # "Giro letal": gira y muere tras este tiempo

@export_group("Recompensa")
@export var coin_scene: PackedScene
@export var coin_value: int = 1

@export_group("Visual")
@export var idle_sheet: Texture2D
@export var run_sheet: Texture2D
@export var idle_frames: int = 8
@export var run_frames: int = 6
@export var frame_size: int = 192
@export var anim_fps: float = 10.0
@export var sprite_scale: float = 0.6

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox

var health: int
var player: Node2D = null
var _attack_timer: float = 0.0
var _dead: bool = false
var _lethal: bool = false      # bajo efecto de "giro letal"
var passive: bool = false      # enemigo de prueba (DEV-ROOM): no ataca

const LETHAL_SPIN_SPEED := 18.0   # rad/s mientras gira hasta morir

func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	# Usar el SpriteFrames asignado en la escena; si no hay, construirlo desde
	# las hojas exportadas (fallback).
	if sprite.sprite_frames == null:
		_build_frames()
	sprite.play("idle")
	player = _find_player()

func _find_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null

func _build_frames() -> void:
	"""Crea un SpriteFrames con las animaciones idle/run cortando las hojas."""
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
	frames.set_animation_speed(anim_name, anim_fps)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		frames.add_frame(anim_name, atlas)

# =============================================================================
# CICLO PRINCIPAL
# =============================================================================
func _physics_process(delta: float) -> void:
	if _dead:
		return

	# Giro letal: el enemigo gira en el sitio hasta morir; no hace nada más.
	if _lethal:
		sprite.rotation += LETHAL_SPIN_SPEED * delta
		velocity = Vector2.ZERO
		return

	_attack_timer = maxf(0.0, _attack_timer - delta)

	if player == null or not is_instance_valid(player):
		player = _find_player()

	_update_ai(delta)
	move_and_slide()
	_update_animation()

	if melee_enabled:
		_try_melee()

func _update_ai(_delta: float) -> void:
	if player == null:
		velocity = Vector2.ZERO
		return
	var to_player := player.global_position - global_position
	if to_player.length() < stop_distance:
		velocity = Vector2.ZERO
	else:
		velocity = to_player.normalized() * move_speed

func make_passive() -> void:
	"""Convierte al enemigo en maniquí de pruebas: no hace daño."""
	passive = true
	melee_enabled = false

func _try_melee() -> void:
	if passive or player == null or _attack_timer > 0.0:
		return
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(contact_damage)
			_attack_timer = attack_cooldown
			break

func _update_animation() -> void:
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
	if velocity.length() > 5.0:
		sprite.play("run")
	else:
		sprite.play("idle")

# =============================================================================
# VIDA Y MUERTE
# =============================================================================
func take_damage(amount: int) -> void:
	if _dead:
		return
	health -= amount
	_flash()
	if health <= 0:
		_die()

func apply_lethal_spin() -> void:
	"""Giro letal (ítem): el enemigo empieza a girar y muere tras un instante.
	Reemplaza el daño normal del impacto que lo activó."""
	if _dead or _lethal:
		return
	_lethal = true
	velocity = Vector2.ZERO
	melee_enabled = false
	sprite.modulate = Color(1.0, 0.9, 0.3)
	var t := get_tree().create_timer(lethal_spin_time)
	t.timeout.connect(func():
		if is_instance_valid(self) and not _dead:
			_die())

func heal(amount: int) -> void:
	"""Regeneración aplicada por el enemigo de Apoyo a los aliados cercanos."""
	if _dead:
		return
	health = min(health + amount, max_health)
	sprite.modulate = Color(0.5, 1.0, 0.5)
	var timer := get_tree().create_timer(0.12)
	timer.timeout.connect(func():
		if is_instance_valid(self) and not _dead:
			sprite.modulate = Color.WHITE)

func _flash() -> void:
	sprite.modulate = Color(1, 0.4, 0.4)
	var timer := get_tree().create_timer(0.1)
	timer.timeout.connect(func():
		if is_instance_valid(self):
			sprite.modulate = Color.WHITE)

func _die() -> void:
	_dead = true
	_drop_coin()
	queue_free()

func _drop_coin() -> void:
	if coin_scene == null:
		return
	var coin = coin_scene.instantiate()
	get_parent().add_child(coin)
	coin.global_position = global_position
	if coin.has_method("set_value"):
		coin.set_value(coin_value)
