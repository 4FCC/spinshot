extends Enemy

# =============================================================================
# SUPPORT MINION — Enemigo de Apoyo
# =============================================================================
# No ataca al jugador. Mantiene distancia y cura (regenera vida) a los enemigos
# cercanos. Intenta colocarse DETRÁS de otros enemigos para protegerse.

@export_group("Apoyo")
@export var heal_amount: int = 2
@export var heal_interval: float = 1.5
@export var heal_radius: float = 240.0
@export var preferred_distance: float = 360.0  # Distancia mínima al jugador

var _heal_timer: float = 0.0

func _ready() -> void:
	super._ready()
	melee_enabled = false   # no ataca cuerpo a cuerpo
	_heal_timer = heal_interval

func _update_ai(delta: float) -> void:
	if player == null:
		velocity = Vector2.ZERO
		return

	var ppos := player.global_position
	var away := (global_position - ppos)
	away = away.normalized() if away.length() > 0.0 else Vector2.RIGHT
	var dist := global_position.distance_to(ppos)

	var target: Vector2
	var ally := _nearest_ally()
	if dist < preferred_distance:
		# Demasiado cerca del jugador: retroceder
		target = global_position + away * 120.0
	elif ally != null:
		# Esconderse en el lado del aliado más alejado del jugador
		target = ally.global_position + away * 80.0
	else:
		target = global_position + away * 60.0

	var move := target - global_position
	velocity = move.normalized() * move_speed if move.length() > 10.0 else Vector2.ZERO

	# Curación periódica de aliados cercanos
	_heal_timer -= delta
	if _heal_timer <= 0.0:
		_heal_timer = heal_interval
		_heal_allies()

func _nearest_ally() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _heal_allies() -> void:
	var healed := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e):
			continue
		if global_position.distance_to(e.global_position) <= heal_radius and e.has_method("heal"):
			e.heal(heal_amount)
			healed = true
	if healed:
		# Destello propio para indicar que está curando
		sprite.modulate = Color(0.6, 1.0, 0.7)
		var t := get_tree().create_timer(0.15)
		t.timeout.connect(func():
			if is_instance_valid(self):
				sprite.modulate = Color.WHITE)
