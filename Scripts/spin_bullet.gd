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
@export var max_radius: float = 550.0

@export var lifetime: float = 8.0
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

# Habilidades otorgadas por ítems
var bounce_count: int = 0       # Nuevas SpinShots que genera al impactar (rebote ofensivo)
var has_split: bool = false     # Se divide en dos a mitad de trayectoria
var lethal_chance: float = 0.0  # Probabilidad de aplicar "giro letal" al impactar
var bullet_scene: PackedScene = null   # Escena para auto-replicarse (rebote/división)
var _did_split: bool = false


func _ready() -> void:
	add_to_group("spin_bullet")
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
	"""Centro de órbita = posición del jugador al disparar. Llamar tras add_child."""
	player = target
	_apply_setup(target.global_position, direction, mode)

func setup_world(center: Vector2, direction: Vector2, mode: int = 0) -> void:
	"""Centro de órbita en un punto del mundo (usado por rebote/división)."""
	player = null
	_apply_setup(center, direction, mode)

func _apply_setup(center: Vector2, direction: Vector2, mode: int) -> void:
	_center = center   # Centro fijo: no se mueve
	pattern_mode = mode
	_radius = start_radius
	_time_alive = 0.0

	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	global_position = _center + dir * start_radius
	_angle = dir.angle()
	_apply_tint()

func _apply_tint() -> void:
	# Tinte distinto según el patrón para distinguir ambos disparos
	if has_node("Sprite2D"):
		$Sprite2D.modulate = Color(0.6, 0.9, 1.0) if pattern_mode == 1 else Color(1.0, 0.85, 0.5)

func _configure_clone(center: Vector2, angle: float, radius: float, mode: int, cw: bool, t: float) -> void:
	"""Coloca a esta bala como mitad de una división, continuando la trayectoria."""
	player = null
	_center = center
	_angle = angle
	_radius = radius
	pattern_mode = mode
	clockwise = cw
	_time_alive = t
	global_position = _center + Vector2(cos(_angle), sin(_angle)) * _radius
	_apply_tint()


func _process(delta: float) -> void:
	_time_alive += delta

	if (lifetime > 0.0 and _time_alive >= lifetime) or _radius >= max_radius:
		queue_free()
		return

	# División de proyectil: a mitad de su vida se divide en dos
	if has_split and not _did_split and lifetime > 0.0 and _time_alive >= lifetime * 0.5:
		_did_split = true
		_spawn_split()

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
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		# Giro letal: probabilidad de matar al girar (reemplaza el daño normal)
		if lethal_chance > 0.0 and randf() < lethal_chance and body.has_method("apply_lethal_spin"):
			body.apply_lethal_spin()
		else:
			body.take_damage(damage)
		_spawn_bounce(global_position)
		queue_free()
	elif body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()

# =============================================================================
# REPLICACIÓN (ítems de rebote y división)
# =============================================================================
func _make_child():
	var b = bullet_scene.instantiate()
	b.damage = damage
	b.has_split = has_split
	b.lethal_chance = lethal_chance
	b.bullet_scene = bullet_scene
	return b

func _spawn_bounce(pos: Vector2) -> void:
	"""Rebote ofensivo: genera 'bounce_count' SpinShots nuevas en el impacto.
	No vuelven a rebotar (evita bucles), pero sí pueden dividirse."""
	if bounce_count <= 0 or bullet_scene == null:
		return
	var host := get_parent()
	if host == null:
		return
	for i in bounce_count:
		var b = _make_child()
		b.bounce_count = 0
		host.add_child(b)
		var ang := TAU * float(i) / float(bounce_count) + randf() * 0.6
		b.setup_world(pos, Vector2.RIGHT.rotated(ang), pattern_mode)

func _spawn_split() -> void:
	"""División: crea la segunda mitad, que gira en sentido contrario y ya no
	se vuelve a dividir."""
	if bullet_scene == null:
		return
	var host := get_parent()
	if host == null:
		return
	var b = _make_child()
	b.bounce_count = bounce_count
	b._did_split = true
	host.add_child(b)
	b._configure_clone(_center, _angle, _radius, pattern_mode, not clockwise, _time_alive)
