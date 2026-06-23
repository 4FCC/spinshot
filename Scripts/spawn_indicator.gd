extends AnimatedSprite2D

# =============================================================================
# SPAWN INDICATOR — Aviso visual del punto donde aparecerán enemigos
# =============================================================================
# Usa la animación del spritesheet "Spritesheet_UI_Flat_Animated" y se tiñe de
# rojo por código para que el jugador identifique rápido las zonas de aparición.
# El GameMode lo crea unos segundos antes del grupo y lo elimina al spawnear.

var _base_scale: float = 1.0

func _ready() -> void:
	add_to_group("spawn_indicator")

func setup(world_pos: Vector2, color: Color, base_scale: float = 1.8) -> void:
	global_position = world_pos
	modulate = color
	_base_scale = base_scale
	scale = Vector2(base_scale, base_scale)
	play("spawn")
	# Pulso de escala para llamar la atención sobre la zona de aparición.
	var tw := create_tween().set_loops()
	tw.tween_property(self, "scale", Vector2(base_scale, base_scale) * 1.15, 0.35) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "scale", Vector2(base_scale, base_scale), 0.35) \
		.set_trans(Tween.TRANS_SINE)
