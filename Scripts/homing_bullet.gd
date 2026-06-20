extends Area2D

# =============================================================================
# HOMING BULLET — Proyectil teledirigido del BulletMinion
# =============================================================================
# Viaja hacia el jugador corrigiendo su rumbo poco a poco (teledirigido).
# Al impactar al jugador le hace daño y desaparece.

@export var speed: float = 230.0
@export var turn_rate: float = 2.5    # Qué tan rápido corrige el rumbo (rad/s)
@export var lifetime: float = 5.0

var target: Node2D = null
var damage: int = 2
var _dir: Vector2 = Vector2.RIGHT
var _life: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(new_target: Node2D, new_damage: int) -> void:
	target = new_target
	damage = new_damage
	if target != null and is_instance_valid(target):
		_dir = (target.global_position - global_position).normalized()
	rotation = _dir.angle()

func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= lifetime:
		queue_free()
		return

	# Teledirigido: girar el rumbo hacia el jugador suavemente
	if target != null and is_instance_valid(target):
		var desired := (target.global_position - global_position).normalized()
		_dir = _dir.slerp(desired, clampf(turn_rate * delta, 0.0, 1.0)).normalized()

	global_position += _dir * speed * delta
	rotation = _dir.angle()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
