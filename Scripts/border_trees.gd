extends Node2D

@export var tree_texture: Texture2D
@export var room_width_px: int = 2560
@export var room_height_px: int = 2560
@export var spacing: int = 192

func _ready() -> void:
	_spawn_border()

func _spawn_border() -> void:
	var w := room_width_px
	var h := room_height_px
	var s := spacing
	var hs := s / 2   # mitad del espaciado: cuánto sobresale el árbol fuera del borde

	# Fila superior e inferior (fuera del área de tiles)
	var x := -hs
	while x <= w + hs:
		_add_tree(Vector2(x, -hs))
		_add_tree(Vector2(x, h + hs))
		x += s

	# Columnas izquierda y derecha (sin repetir las esquinas)
	var y := hs
	while y <= h - hs:
		_add_tree(Vector2(-hs, y))
		_add_tree(Vector2(w + hs, y))
		y += s

func _add_tree(pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	add_child(body)
	if tree_texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = tree_texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, 192, 256)
	body.add_child(sprite)
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 45.0
	col.shape = shape
	col.position = Vector2(0, 60)
	body.add_child(col)
