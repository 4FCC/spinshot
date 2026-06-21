extends Area2D

# =============================================================================
# BOSS BULLET — Proyectil recto del jefe (para voleas radiales)
# =============================================================================

@export var speed: float = 280.0
@export var lifetime: float = 4.0

var direction: Vector2 = Vector2.RIGHT
var damage: int = 3
var _t: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(dir: Vector2, dmg: int) -> void:
	direction = dir.normalized()
	damage = dmg
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= lifetime:
		queue_free()
		return
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
