extends Enemy

# =============================================================================
# BULLET MINION GÓTICA (variante) — Teletransporte + patrones
# =============================================================================
# Se teletransporta con frecuencia manteniendo una distancia prudente del
# jugador. Justo tras teletransportarse suelta 2 patrones de HomingBullet
# (un círculo y un triángulo) que NO siguen al jugador. Luego evade hasta que
# se recarga el teletransporte.

@export_group("A distancia")
@export var projectile_scene: PackedScene
@export var projectile_damage: int = 2
@export var safe_distance: float = 380.0
@export var ring_count: int = 10
@export var ring_speed: float = 190.0

@export_group("Teletransporte")
@export var teleport_cooldown: float = 3.0

# Límites del área jugable (para no teletransportarse fuera del mapa).
const ARENA_MIN := Vector2(96, 96)
const ARENA_MAX := Vector2(1824, 1056)

var _tp_timer: float = 0.0

func _ready() -> void:
	super._ready()
	melee_enabled = false
	add_to_group("bullet_minion_gotica")
	_tp_timer = teleport_cooldown * 0.5

func _update_ai(delta: float) -> void:
	if player == null:
		velocity = Vector2.ZERO
		return

	_tp_timer -= delta
	if not passive and _tp_timer <= 0.0:
		_tp_timer = teleport_cooldown
		_teleport_and_attack()
		return

	# Evadir: mantenerse a distancia segura del jugador.
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()
	if dist < safe_distance:
		velocity = -dir * get_speed()
	else:
		velocity = dir.rotated(PI / 2.0) * get_speed() * 0.4

func _teleport_and_attack() -> void:
	# Reaparecer a distancia segura del jugador, en un punto dentro del mapa.
	var ang := randf() * TAU
	var pos: Vector2 = player.global_position + Vector2.RIGHT.rotated(ang) * safe_distance
	pos.x = clampf(pos.x, ARENA_MIN.x, ARENA_MAX.x)
	pos.y = clampf(pos.y, ARENA_MIN.y, ARENA_MAX.y)
	global_position = pos
	velocity = Vector2.ZERO

	# Destello de teletransporte.
	sprite.modulate = Color(0.7, 0.4, 1.0)
	var t := create_tween()
	t.tween_property(sprite, "modulate", _base_modulate(), 0.25)

	# 2 patrones: un círculo y un triángulo (ninguno sigue al jugador).
	_fire_pattern(ring_count, 0.0)
	_fire_pattern(3, deg_to_rad(30.0))

func _fire_pattern(count: int, offset: float) -> void:
	if projectile_scene == null or count <= 0:
		return
	var host := get_parent()
	if host == null:
		return
	for i in count:
		var ang := offset + TAU * float(i) / float(count)
		var p = projectile_scene.instantiate()
		host.add_child(p)
		p.global_position = global_position
		if p.has_method("setup_straight"):
			p.setup_straight(Vector2.RIGHT.rotated(ang), projectile_damage)
			if "speed" in p:
				p.speed = ring_speed
