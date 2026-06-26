extends Area2D

# =============================================================================
# COIN — Moneda que sueltan los enemigos al morir
# =============================================================================
# Al tocar al jugador se recoge y suma a la economía global (Game).

@export var value: int = 1
@export var description: String = "ILOVEBROTATO"

func _ready() -> void:
	add_to_group("coin")
	body_entered.connect(_on_body_entered)

func set_value(v: int) -> void:
	value = v

func collect() -> void:
	"""Recolección automática (p. ej. al terminar la ronda): suma su valor y
	desaparece, sin requerir contacto con el jugador."""
	Game.add_coins(value)
	# Al recoger MUCHAS monedas de golpe, el debounce evita el muro de sonido.
	Audio.play("coin", 0.18, 70)
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		Game.add_coins(value)
		# Variación de tono + debounce para que no sature al recoger en cadena.
		Audio.play("coin", 0.18, 60)
		# Permite efectos al recoger moneda (p. ej. robo de vida)
		if body.has_method("on_coin_collected"):
			body.on_coin_collected()
		queue_free()
