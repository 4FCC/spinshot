extends Node2D

# =============================================================================
# SPIN-BULLET — Mecánica principal (tema: GIRAR)
# =============================================================================
# Bala que el jugador dispara y que orbita a su alrededor describiendo una
# espiral hacia afuera hasta agotar su vida o alcanzar el radio máximo.
#
# Se puede inicializar de dos formas:
#   1) Desde el editor: asignando "player_path" en el inspector.
#   2) Desde código: llamando a setup(jugador, direccion) tras instanciarla.

# --- Configuración exportada ---
@export var player_path: NodePath           # (Opcional) jugador asignado desde el editor
@export var angular_speed: float = 360.0    # Grados por segundo que gira la bala
@export var clockwise: bool = true          # true = horario, false = antihorario

@export var start_radius: float = 30.0      # Radio inicial (distancia al jugador al nacer)
@export var radius_growth_speed: float = 60.0 # Crecimiento del radio por segundo (espiral)
@export var max_radius: float = 400.0       # Radio máximo antes de destruirse

@export var lifetime: float = 4.0           # Tiempo de vida en segundos (0 = infinito)

# --- Estado interno ---
var player: Node2D = null
var _angle: float = 0.0
var _radius: float = 0.0
var _time_alive: float = 0.0


func _ready() -> void:
	# Si no se inicializó por código, intentar resolver el jugador del editor
	if player == null and player_path != NodePath(""):
		player = get_node_or_null(player_path) as Node2D

	_radius = start_radius
	_angle = (global_position - _get_center()).angle()


func setup(target: Node2D, direction: Vector2) -> void:
	"""Inicializa la bala desde código: define el centro de giro (el jugador) y
	la posición inicial en la dirección de disparo. Llamar DESPUÉS de añadirla
	al árbol para que la posición global sea coherente con la escena."""
	player = target
	_radius = start_radius
	_time_alive = 0.0

	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	global_position = _get_center() + dir * start_radius
	_angle = dir.angle()


func _process(delta: float) -> void:
	_time_alive += delta

	if (lifetime > 0.0 and _time_alive >= lifetime) or _radius >= max_radius:
		queue_free()
		return

	var dir := 1.0 if clockwise else -1.0
	_angle += deg_to_rad(angular_speed) * dir * delta
	_radius += radius_growth_speed * delta

	var offset := Vector2(cos(_angle), sin(_angle)) * _radius
	global_position = _get_center() + offset


func _get_center() -> Vector2:
	if player != null:
		return player.global_position
	return global_position
