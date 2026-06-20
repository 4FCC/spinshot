extends Node2D

# =============================================================================
# SPIN-BULLET — Mecánica principal (tema: GIRAR)
# =============================================================================
# Bala que el jugador dispara y que orbita un punto FIJO en el mundo
# (la posición del jugador en el momento del disparo), describiendo una
# espiral hacia afuera hasta agotar su vida o alcanzar el radio máximo.
# Si toca al jugador, le inflige daño y desaparece.
#
# Inicialización:
#   1) Desde el editor: asignando "player_path" en el inspector.
#   2) Desde código:    llamando a setup(jugador, direccion) tras add_child.

@export var player_path: NodePath
@export var angular_speed: float = 360.0
@export var clockwise: bool = true

@export var start_radius: float = 30.0
@export var radius_growth_speed: float = 60.0
@export var max_radius: float = 400.0

@export var lifetime: float = 4.0
@export var damage: int = 3

# Patrón de giro: 0 = espiral suave (clic derecho), 1 = espiral ondulada e
# inversa (clic izquierdo). Cada botón genera un movimiento distinto.
@export var pattern_mode: int = 0
@export var wobble_freq: float = 12.0       # Frecuencia de la onda del patrón 1
@export var wobble_amplitude: float = 45.0  # Amplitud de la onda del patrón 1

var player: Node2D = null
var _center: Vector2 = Vector2.ZERO  # Punto fijo de órbita (no sigue al jugador)
var _angle: float = 0.0
var _radius: float = 0.0
var _time_alive: float = 0.0
var _can_damage: bool = false         # Gracia inicial para no dañar al instante
var _hit_enemies: Array = []          # Enemigos ya golpeados (la bala los atraviesa)


func _ready() -> void:
	if player == null and player_path != NodePath(""):
		player = get_node_or_null(player_path) as Node2D
		if player != null:
			_center = player.global_position

	_radius = start_radius
	_angle = (global_position - _center).angle()

	$Area2D.body_entered.connect(_on_body_entered)
	# Pequeña gracia para evitar daño inmediato al disparar
	get_tree().create_timer(0.4).timeout.connect(func(): _can_damage = true)


func setup(target: Node2D, direction: Vector2, mode: int = 0) -> void:
	"""Fija el centro de órbita en la posición actual del jugador y coloca
	la bala en la dirección de disparo. 'mode' elige el patrón de giro.
	Llamar DESPUÉS de add_child."""
	player = target
	_center = target.global_position   # Centro fijo: no se mueve con el jugador
	pattern_mode = mode

	_radius = start_radius
	_time_alive = 0.0

	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	global_position = _center + dir * start_radius
	_angle = dir.angle()

	# Tinte distinto según el patrón para distinguir ambos disparos
	if has_node("Sprite2D"):
		$Sprite2D.modulate = Color(0.6, 0.9, 1.0) if pattern_mode == 1 else Color(1.0, 0.85, 0.5)


func _process(delta: float) -> void:
	_time_alive += delta

	if (lifetime > 0.0 and _time_alive >= lifetime) or _radius >= max_radius:
		queue_free()
		return

	var dir_sign := 1.0 if clockwise else -1.0
	if pattern_mode == 1:
		dir_sign = -dir_sign   # el patrón alterno gira en sentido contrario

	_angle += deg_to_rad(angular_speed) * dir_sign * delta
	_radius += radius_growth_speed * delta

	# El patrón 1 añade una ondulación al radio (trayectoria de "flor")
	var r := _radius
	if pattern_mode == 1:
		r += sin(_time_alive * wobble_freq) * wobble_amplitude

	global_position = _center + Vector2(cos(_angle), sin(_angle)) * r


func _on_body_entered(body: Node2D) -> void:
	if not _can_damage:
		return
	# A los enemigos los atraviesa (los daña una vez y sigue orbitando)
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		if body in _hit_enemies:
			return
		_hit_enemies.append(body)
		body.take_damage(damage)
		return
	# Al jugador le hace daño y desaparece
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
