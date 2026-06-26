extends Node2D

# =============================================================================
# FLOOR BUILDER — Suelo de césped con borde de piedra en el TileMapLayer "Ground"
# =============================================================================
# Reutilizable por cualquier escena (Main, DEV-ROOM). Construye:
#   - Un campo de césped (autotile 3x3 con bordes de maleza) de width x height.
#   - Un anillo de PIEDRA alrededor que delimita visualmente el área jugable.
# Las colisiones (muros) y las nubes exteriores las ponen la escena / CloudBorder.

@export var width: int = 30     # Ancho del césped en tiles (≈25% menos que antes)
@export var height: int = 18    # Alto del césped en tiles
@export var stone_border: int = 2   # Grosor del anillo de piedra (en tiles)

@export_group("Contraste del fondo")
# Atenúan el suelo/fondo para que jugador, enemigos y UI resalten. Tunables.
@export var ground_darken: float = 0.74         # 1 = sin cambio, <1 más oscuro
@export var ground_desaturation: float = 0.40   # 0 = color original, 1 = gris
@export var ground_tint: Color = Color(1, 1, 1) # tinte multiplicativo (leve)
@export var dim_clouds: float = 0.7             # oscurecer las nubes/cielo (modulate)

const GROUND_SHADER := preload("res://Shaders/ground_tint.gdshader")

@onready var ground: TileMapLayer = $Ground

const SOURCE_ID := 0
# Césped (bloque autotile superior-izquierdo del Tilemap)
const TILE_TL := Vector2i(0, 0)
const TILE_TOP := Vector2i(1, 0)
const TILE_TR := Vector2i(2, 0)
const TILE_LEFT := Vector2i(0, 1)
const TILE_CENTER := Vector2i(1, 1)
const TILE_RIGHT := Vector2i(2, 1)
const TILE_BL := Vector2i(0, 2)
const TILE_BOTTOM := Vector2i(1, 2)
const TILE_BR := Vector2i(2, 2)
# Piedra (cara de roca del Tilemap) para el borde
const TILE_STONE := Vector2i(6, 4)

func _ready() -> void:
	_build_floor()
	_apply_contrast()

func _apply_contrast() -> void:
	# Aplica el shader de atenuación/desaturación al suelo (césped + piedra) por
	# código, sin redibujar assets. Y oscurece un poco las nubes/cielo del borde.
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("darken", ground_darken)
	mat.set_shader_parameter("desaturation", ground_desaturation)
	mat.set_shader_parameter("tint", ground_tint)
	ground.material = mat

	var clouds := get_node_or_null("CloudBorder")
	if clouds != null:
		# Node2D (CanvasItem): el modulate se hereda a sus nubes y cielo.
		clouds.modulate = Color(dim_clouds, dim_clouds, dim_clouds, 1.0)

func _build_floor() -> void:
	# Anillo de piedra alrededor del césped
	for y in range(-stone_border, height + stone_border):
		for x in range(-stone_border, width + stone_border):
			if x >= 0 and x < width and y >= 0 and y < height:
				ground.set_cell(Vector2i(x, y), SOURCE_ID, _tile_for(x, y))
			else:
				ground.set_cell(Vector2i(x, y), SOURCE_ID, TILE_STONE)

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
