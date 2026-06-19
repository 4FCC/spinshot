extends Node2D

# --- Configuración exportada ---
@export var player_path: NodePath          # Arrastra aquí el nodo del jugador
@export var angular_speed: float = 360.0    # Grados por segundo que gira la bala
@export var clockwise: bool = true          # true = sentido horario, false = antihorario

@export var start_radius: float = 30.0      # Radio inicial (qué tan lejos del jugador empieza)
@export var radius_growth_speed: float = 60.0 # Cuánto crece el radio por segundo (espiral hacia afuera)
@export var max_radius: float = 400.0       # Radio máximo antes de destruirse

@export var lifetime: float = 4.0           # Tiempo de vida en segundos (0 = infinito)

var _player: Node2D = null
var _angle: float = 0.0
var _radius: float = 0.0
var _time_alive: float = 0.0


func _ready() -> void:
	if player_path != NodePath(""):
		_player = get_node(player_path) as Node2D

	_radius = start_radius

	var center := _get_center()
	_angle = (global_position - center).angle()


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
	if _player != null:
		return _player.global_position
	return Vector2.ZERO
