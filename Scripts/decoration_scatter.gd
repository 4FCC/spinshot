extends Node2D

# =============================================================================
# DECORATION SCATTER — Coloca obstáculos al azar en el DEV-ROOM
# =============================================================================
# Reparte árboles, rocas, arbustos y tocones en posiciones aleatorias dentro
# del área de la sala, evitando la zona de aparición del jugador y el
# amontonamiento entre obstáculos.

@export var room_width_px: float = 2048.0
@export var room_height_px: float = 2048.0
@export var margin: float = 140.0
@export var safe_zone_center: Vector2 = Vector2(1024.0, 1024.0)
@export var safe_zone_radius: float = 220.0
@export var min_spacing: float = 150.0
@export var obstacle_count: int = 10   # Al menos 8 obstáculos

@export_group("Texturas")
@export var tree_texture: Texture2D
@export var rock_textures: Array[Texture2D] = []
@export var bush_texture: Texture2D
@export var stump_texture: Texture2D

const TREE_REGION := Rect2(0, 0, 192, 256)
const BUSH_REGION := Rect2(0, 0, 128, 128)

func _ready() -> void:
	randomize()
	_scatter()

func _scatter() -> void:
	var placed: Array[Vector2] = []
	var attempts := 0
	while placed.size() < obstacle_count and attempts < obstacle_count * 50:
		attempts += 1
		var pos := Vector2(
			randf_range(margin, room_width_px - margin),
			randf_range(margin, room_height_px - margin)
		)
		if pos.distance_to(safe_zone_center) < safe_zone_radius:
			continue
		var overlaps := false
		for p in placed:
			if p.distance_to(pos) < min_spacing:
				overlaps = true
				break
		if overlaps:
			continue
		placed.append(pos)
		_spawn_obstacle(pos)

func _spawn_obstacle(pos: Vector2) -> void:
	match randi() % 4:
		0:
			_make_tree(pos)
		1:
			_make_rock(pos)
		2:
			_make_bush(pos)
		_:
			_make_stump(pos)

func _make_tree(pos: Vector2) -> void:
	if tree_texture == null:
		return
	var body := _make_body(pos)
	var sprite := Sprite2D.new()
	sprite.texture = tree_texture
	sprite.region_enabled = true
	sprite.region_rect = TREE_REGION
	body.add_child(sprite)
	_add_shape(body, 45.0, Vector2(0, 60))

func _make_rock(pos: Vector2) -> void:
	if rock_textures.is_empty():
		return
	var body := _make_body(pos)
	var sprite := Sprite2D.new()
	sprite.texture = rock_textures[randi() % rock_textures.size()]
	body.add_child(sprite)
	_add_shape(body, 32.0, Vector2.ZERO)

func _make_bush(pos: Vector2) -> void:
	if bush_texture == null:
		return
	var body := _make_body(pos)
	var sprite := Sprite2D.new()
	sprite.texture = bush_texture
	sprite.region_enabled = true
	sprite.region_rect = BUSH_REGION
	body.add_child(sprite)
	_add_shape(body, 28.0, Vector2.ZERO)

func _make_stump(pos: Vector2) -> void:
	if stump_texture == null:
		return
	var body := _make_body(pos)
	var sprite := Sprite2D.new()
	sprite.texture = stump_texture
	body.add_child(sprite)
	_add_shape(body, 18.0, Vector2.ZERO)

func _make_body(pos: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = pos
	add_child(body)
	return body

func _add_shape(body: StaticBody2D, radius: float, offset: Vector2) -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	col.position = offset
	body.add_child(col)
