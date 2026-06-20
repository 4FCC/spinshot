extends Area2D

# =============================================================================
# COIN — Moneda que sueltan los enemigos al morir
# =============================================================================
# Al tocar al jugador se recoge y suma a la economía global (Game).

@export var value: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func set_value(v: int) -> void:
	value = v

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		Game.add_coins(value)
		queue_free()
