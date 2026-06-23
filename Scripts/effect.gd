extends AnimatedSprite2D

# =============================================================================
# EFFECT — Efecto de partículas de un solo uso (spritesheet animado)
# =============================================================================
# Reproduce una animación no cíclica ("dust" o "burst") y se autodestruye al
# terminar. Lo usan la esquiva automática (nube de polvo) y las habilidades de
# división/rebote (estallido).

func _ready() -> void:
	animation_finished.connect(queue_free)

func play_effect(anim_name: String) -> void:
	if sprite_frames != null and sprite_frames.has_animation(anim_name):
		play(anim_name)
	else:
		queue_free()
