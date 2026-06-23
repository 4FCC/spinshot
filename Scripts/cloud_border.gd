extends Node2D

# =============================================================================
# CLOUD BORDER — Cubre el exterior del mapa con nubes (assets Tiny Swords)
# =============================================================================
# Oculta el fondo por defecto de Godot rodeando el área jugable con nubes y un
# fondo de cielo. El área jugable (césped) queda libre porque el TileMap se
# dibuja por encima (las nubes van detrás, z_index negativo).

@export var area_width: float = 1920.0    # Ancho del césped en píxeles
@export var area_height: float = 1152.0   # Alto del césped en píxeles
@export var cloud_margin: float = 1000.0  # Cuánto se extienden las nubes hacia afuera
@export var bg_margin: float = 3000.0     # Tamaño del cielo de fondo (barato, 1 polígono)
@export var sky_color: Color = Color(0.42, 0.58, 0.69)  # Cielo detrás de las nubes
@export var step_x: float = 300.0         # Separación horizontal entre nubes
@export var step_y: float = 150.0         # Separación vertical entre nubes

const CLOUD_PATHS := [
	"res://Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_01.png",
	"res://Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_02.png",
	"res://Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_03.png",
	"res://Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_04.png",
	"res://Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_05.png",
	"res://Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_06.png",
	"res://Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_07.png",
	"res://Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_08.png",
]

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var textures: Array = []
	for p in CLOUD_PATHS:
		var t = load(p)
		if t != null:
			textures.append(t)

	_build_sky()
	if not textures.is_empty():
		_build_clouds(textures, rng)

func _build_sky() -> void:
	# Fondo de cielo: un único polígono grande detrás de todo para que nunca se
	# vea el gris por defecto, aunque las nubes dejen huecos.
	var sky := Polygon2D.new()
	sky.color = sky_color
	sky.z_index = -100
	sky.polygon = PackedVector2Array([
		Vector2(-bg_margin, -bg_margin),
		Vector2(area_width + bg_margin, -bg_margin),
		Vector2(area_width + bg_margin, area_height + bg_margin),
		Vector2(-bg_margin, area_height + bg_margin),
	])
	add_child(sky)

func _build_clouds(textures: Array, rng: RandomNumberGenerator) -> void:
	# Banda de nubes alrededor del césped. Se omiten las posiciones que caen
	# dentro del área jugable (allí el césped tapa de todos modos).
	var inset := 80.0   # solapan un poco sobre el borde de piedra
	var y := -cloud_margin
	while y <= area_height + cloud_margin:
		var x := -cloud_margin
		while x <= area_width + cloud_margin:
			var inside := x > inset and x < area_width - inset and y > inset and y < area_height - inset
			if not inside:
				_place_cloud(textures, rng, Vector2(x, y))
			x += step_x
		y += step_y

func _place_cloud(textures: Array, rng: RandomNumberGenerator, pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = textures[rng.randi() % textures.size()]
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_index = -50
	s.position = pos + Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(-40.0, 40.0))
	var sc := rng.randf_range(0.7, 1.15)
	s.scale = Vector2(sc, sc)
	s.flip_h = rng.randf() < 0.5
	s.modulate = Color(1, 1, 1, rng.randf_range(0.9, 1.0))
	add_child(s)
