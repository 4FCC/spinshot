extends Node2D

# =============================================================================
# DEV-ROOM — Sala de pruebas de mecánicas
# =============================================================================
# Genera por código un suelo de césped en el TileMapLayer usando el autotile
# del pack Tiny Swords. Pensada para probar el movimiento, el esquive y la
# Spin-Bullet en un entorno con tiles y decoraciones.

@onready var ground: TileMapLayer = $Ground

const SOURCE_ID := 0

# Coordenadas del atlas (rejilla 3x3 de césped del tileset)
const TILE_TL := Vector2i(0, 0)
const TILE_TOP := Vector2i(1, 0)
const TILE_TR := Vector2i(2, 0)
const TILE_LEFT := Vector2i(0, 1)
const TILE_CENTER := Vector2i(1, 1)
const TILE_RIGHT := Vector2i(2, 1)
const TILE_BL := Vector2i(0, 2)
const TILE_BOTTOM := Vector2i(1, 2)
const TILE_BR := Vector2i(2, 2)

@export var width: int = 24    # Ancho del suelo en tiles
@export var height: int = 16   # Alto del suelo en tiles

func _ready():
	_build_floor()

func _build_floor():
	"""Rellena un rectángulo de césped: centro liso y bordes/esquinas con el
	autotile para que parezca una isla."""
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
