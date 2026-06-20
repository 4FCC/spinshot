extends Enemy

# =============================================================================
# BULLET MINION — Enemigo a distancia
# =============================================================================
# No ataca cuerpo a cuerpo: mantiene la distancia con el jugador y le dispara
# un proyectil teledirigido cada cierto tiempo.

@export_group("Ataque a distancia")
@export var projectile_scene: PackedScene
@export var projectile_damage: int = 2
@export var fire_interval: float = 2.0
@export var preferred_distance: float = 300.0
@export var distance_margin: float = 60.0

var _fire_timer: float = 0.0

func _ready() -> void:
	super._ready()
	melee_enabled = false          # ataca solo con proyectiles
	_fire_timer = fire_interval

func _update_ai(delta: float) -> void:
	if player == null:
		velocity = Vector2.ZERO
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()

	# Mantener la distancia preferida: alejarse si está cerca, acercarse si está
	# lejos y orbitar (strafe) cuando está en el rango ideal.
	if dist < preferred_distance - distance_margin:
		velocity = -dir * move_speed
	elif dist > preferred_distance + distance_margin:
		velocity = dir * move_speed
	else:
		velocity = dir.rotated(PI / 2.0) * move_speed * 0.5

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		_shoot()

func _shoot() -> void:
	if projectile_scene == null or player == null:
		return
	var projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	if projectile.has_method("setup"):
		projectile.setup(player, projectile_damage)
