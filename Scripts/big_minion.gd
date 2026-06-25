extends Enemy

# =============================================================================
# BIG MINION — Minión grande (cuerpo a cuerpo robusto)
# =============================================================================
# Igual que el enemigo base, pero pertenece al grupo "bigminion" para que el
# Bigminion_capitan pueda potenciarlo (buff de daño y velocidad) cuando esté
# dentro de su área de efecto. El buff lo gestiona enemy.gd (apply_buff).

func _ready() -> void:
	super._ready()
	add_to_group("bigminion")
