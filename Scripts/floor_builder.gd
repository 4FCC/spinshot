extends Node2D

# =============================================================================
# FLOOR BUILDER — Genera un suelo de césped en el TileMapLayer hijo "Ground"
# =============================================================================
# Reutilizable por cualquier escena (Main, DEV-ROOM, etc.). Solo construye el
# suelo; la lógica de juego vive en GameMode.

@export var width: int = 40    # Ancho del suelo en tiles
@export var height: int = 24   # Alto del suelo en tiles

@onready var ground: TileMapLayer = $Ground

const SOURCE_ID := 0
const TILE_TL := Vector2i(0, 0)
const TILE_TOP := Vector2i(1, 0)
const TILE_TR := Vector2i(2, 0)
const TILE_LEFT := Vector2i(0, 1)
const TILE_CENTER := Vector2i(1, 1)
const TILE_RIGHT := Vector2i(2, 1)
const TILE_BL := Vector2i(0, 2)
const TILE_BOTTOM := Vector2i(1, 2)
const TILE_BR := Vector2i(2, 2)

func _ready() -> void:
	_build_floor()

func _build_floor() -> void:
	for y in range(height):
		for x in range(width):
			ground.set_cell(Vector2i(x, y), SOURCE_ID, _tile_for(x, y))

func _tile_for(x: int, y: int) -> Vector2i:
	var left := x == 0
	var right := x == width - 1
	var top := y == 0
	var bottom := y == height - 1
	if top and left:
		return TILE_TL
	if top and right:
		return TILE_TR
	if bottom and left:
		return TILE_BL
	if bottom and right:
		return TILE_BR
	if top:
		return TILE_TOP
	if bottom:
		return TILE_BOTTOM
	if left:
		return TILE_LEFT
	if right:
		return TILE_RIGHT
	return TILE_CENTER
