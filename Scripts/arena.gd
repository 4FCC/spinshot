extends Node2D

# =============================================================================
# ARENA — Bucle de juego principal (oleadas estilo Brotato)
# =============================================================================
# - Construye el suelo con el TileMapLayer.
# - Gestiona las oleadas: tecla para iniciar (N) y para terminar (M).
# - Cada etapa hace aparecer un tipo de enemigo:
#       Etapa 1 -> Minions   (frecuente)
#       Etapa 2 -> BigMinions (menos frecuente)
#       Etapa 3 -> BulletMinions (aún menos frecuente)
# - Al terminar una oleada abre la tienda; al continuar se prepara la siguiente.

@export_group("Escenas de enemigos")
@export var minion_scene: PackedScene
@export var bigminion_scene: PackedScene
@export var bulletminion_scene: PackedScene

@export_group("Oleadas")
@export var spawn_radius: float = 650.0   # Distancia a la que aparecen del jugador
@export var wave_duration: float = 60.0   # Segundos que dura cada oleada
@export var arena_width: int = 40         # Suelo en tiles
@export var arena_height: int = 24

@onready var ground: TileMapLayer = $Ground
@onready var player: Node2D = $Player
@onready var coins_label: Label = $UI/CoinsLabel
@onready var wave_label: Label = $UI/WaveLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var info_label: Label = $UI/InfoLabel
@onready var shop = $UI/Shop

# Coordenadas del atlas (rejilla 3x3 de césped del tileset)
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

var wave_number: int = 0
var wave_active: bool = false
var time_left: float = 0.0
var _spawn_accum: float = 0.0

func _ready() -> void:
	randomize()
	_build_floor()
	Game.reset()
	Game.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(Game.coins)

	shop.continue_pressed.connect(_on_shop_continue)
	shop.visible = false

	# Centrar al jugador en el suelo
	player.global_position = Vector2(arena_width, arena_height) * 64.0 * 0.5

	_update_wave_label()
	timer_label.text = ""
	info_label.text = "Pulsa N para empezar la oleada 1"

func _process(delta: float) -> void:
	if not wave_active:
		return

	# Cuenta atrás de la oleada
	time_left -= delta
	_update_timer_label()
	if time_left <= 0.0:
		_end_wave()
		return

	_spawn_accum -= delta
	if _spawn_accum <= 0.0:
		_spawn_accum = _spawn_interval()
		_spawn_enemy()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start_wave") and not wave_active and not shop.visible:
		_start_wave()
	elif event.is_action_pressed("end_wave") and wave_active:
		_end_wave()

# =============================================================================
# OLEADAS
# =============================================================================
func _start_wave() -> void:
	wave_number += 1
	wave_active = true
	time_left = wave_duration
	_spawn_accum = 0.0
	_update_wave_label()
	_update_timer_label()
	info_label.text = "Oleada %d en curso — pulsa M para terminar antes" % wave_number

func _end_wave() -> void:
	wave_active = false
	time_left = 0.0
	timer_label.text = ""
	_clear_enemies()
	info_label.text = ""
	shop.open()

func _on_shop_continue() -> void:
	# Al cerrar la tienda comienza automáticamente la siguiente oleada
	_start_wave()

func _stage() -> int:
	return clampi(wave_number, 1, 3)

func _spawn_interval() -> float:
	match _stage():
		1:
			return 0.7    # Minions: frecuentes
		2:
			return 1.6    # BigMinions: menos frecuentes
		_:
			return 2.6    # BulletMinions: aún menos frecuentes

func _current_enemy_scene() -> PackedScene:
	match _stage():
		1:
			return minion_scene
		2:
			return bigminion_scene
		_:
			return bulletminion_scene

func _spawn_enemy() -> void:
	var scene := _current_enemy_scene()
	if scene == null or player == null:
		return
	var enemy = scene.instantiate()
	var angle := randf() * TAU
	add_child(enemy)
	enemy.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * spawn_radius

func _clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()

# =============================================================================
# UI
# =============================================================================
func _on_coins_changed(total: int) -> void:
	coins_label.text = "Monedas: %d" % total

func _update_wave_label() -> void:
	if wave_number == 0:
		wave_label.text = "Oleada: -"
	else:
		wave_label.text = "Oleada %d  (Etapa %d)" % [wave_number, _stage()]

func _update_timer_label() -> void:
	timer_label.text = "Tiempo: %d s" % ceili(maxf(time_left, 0.0))

# =============================================================================
# SUELO
# =============================================================================
func _build_floor() -> void:
	for y in range(arena_height):
		for x in range(arena_width):
			ground.set_cell(Vector2i(x, y), SOURCE_ID, _tile_for(x, y))

func _tile_for(x: int, y: int) -> Vector2i:
	var left := x == 0
	var right := x == arena_width - 1
	var top := y == 0
	var bottom := y == arena_height - 1
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
