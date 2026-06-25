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
@export var damage_buff: int = 1               # +daño que otorga a aliados en rango

const EFFECT_SCENE := preload("res://Scenes/Effect.tscn")

var _heal_timer: float = 0.0
var _pink_tween: Tween = null

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

	# Aura de daño: refresca el +daño en todos los aliados dentro del radio cada
	# frame. Al salir del rango deja de refrescarse y la bonificación caduca.
	_apply_damage_aura()

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

func _apply_damage_aura() -> void:
	if damage_buff <= 0:
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e):
			continue
		if global_position.distance_to(e.global_position) <= heal_radius and e.has_method("apply_damage_buff"):
			# Duración corta: se renueva cada frame mientras siga en rango.
			e.apply_damage_buff(damage_buff, 0.3)

func _heal_allies() -> void:
	var healed := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e):
			continue
		if global_position.distance_to(e.global_position) <= heal_radius and e.has_method("heal"):
			e.heal(heal_amount)
			_spawn_hearts(e)   # efecto de corazones sobre el aliado beneficiado
			healed = true
	if healed:
		_spawn_hearts(self)   # también sobre el propio Apoyo
		_pink_flash()

func _spawn_hearts(node: Node2D) -> void:
	"""Efecto de corazones (sheet del Apoyo). Se añade como hijo del beneficiado
	para que se renderice sobrepuesto y le siga; se autodestruye al terminar."""
	if not is_instance_valid(node):
		return
	var fx = EFFECT_SCENE.instantiate()
	node.add_child(fx)
	fx.position = Vector2(0, -12)
	fx.z_index = 60
	fx.play_effect("hearts")

func _pink_flash() -> void:
	# Pintar el sprite de rosa de manera intermitente mientras usa su habilidad.
	if _pink_tween != null and _pink_tween.is_valid():
		_pink_tween.kill()
	_pink_tween = create_tween()
	_pink_tween.set_loops(3)
	_pink_tween.tween_property(sprite, "modulate", Color(1.0, 0.5, 0.85), 0.13)
	_pink_tween.tween_property(sprite, "modulate", _base_modulate(), 0.13)
