extends Node

# =============================================================================
# GAME MODE — Bucle de juego reutilizable (oleadas, tienda y pantallas)
# =============================================================================
# Componente que se instancia en cualquier escena con un jugador (Main, DEV-ROOM).
# Gestiona:
#   - Oleadas por etapas (Minions / BigMinions / BulletMinions), 60s cada una.
#   - Tienda entre oleadas (con tirada de dados).
#   - Pantallas de inicio, victoria y muerte.
# No construye el suelo ni coloca al jugador: de eso se encargan las escenas.

@export_group("Escenas de enemigos")
@export var minion_scene: PackedScene
@export var bigminion_scene: PackedScene
@export var bulletminion_scene: PackedScene
@export var charger_scene: PackedScene
@export var support_scene: PackedScene

@export_group("Jefe")
@export var boss_scene: PackedScene        # Aparece al terminar la última oleada

@export_group("Oleadas")
@export var spawn_radius: float = 650.0   # Distancia a la que aparecen del jugador
@export var wave_duration: float = 40.0   # Segundos que dura cada oleada
@export var total_waves: int = 10         # Tras la última oleada aparece el jefe

@export_group("Aparición por grupos")
@export var spawn_warning_time: float = 1.2   # Aviso visual antes de cada grupo
@export var large_group_chance: float = 0.35  # Probabilidad de grupo grande
@export var small_group_min: int = 2
@export var small_group_max: int = 4
@export var large_group_min: int = 6
@export var large_group_max: int = 10

@export_group("Modo")
# Main: debug_mode = false (auto), DEV-ROOM: debug_mode = true (manual + atajos).
@export var debug_mode: bool = false       # Activa los atajos de depuración (solo DEV-ROOM)
@export var auto_start_waves: bool = true  # Encadena las oleadas automáticamente (Main)

@onready var ui: CanvasLayer = $UI
@onready var coins_label: Label = $UI/CoinsLabel
@onready var wave_label: Label = $UI/WaveLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var info_label: Label = $UI/InfoLabel
@onready var announce_label: Label = $UI/AnnounceLabel
@onready var shop = $UI/Shop

var player: Node2D = null
var wave_number: int = 0
var wave_active: bool = false
var time_left: float = 0.0
var _spawn_accum: float = 0.0
var _waves: Array = []          # Tabla de oleadas (ver _build_waves)
var _boss: Node = null          # Instancia del jefe (si está vivo)
var _boss_pending: bool = false # Tras la oleada final: tienda y luego jefe

# Pantallas
var _start_screen: Control = null
var _victory_screen: Control = null
var _death_screen: Control = null
var _screen_active: bool = false

# Inventario (tecla E)
var _inventory_panel: Control = null
var _inventory_grid: GridContainer = null
var _inventory_open: bool = false
var _inv_stats_holder: Control = null

# Menú de opciones (tecla ESC)
var _options_panel: Control = null
var _options_open: bool = false
var _controls_box: Control = null

const UI_INVENTORY_TEX := preload("res://UI assets/UI_Inventario_E.png")
const UI_ESC_TEX := preload("res://UI assets/UI_ESC.png")
const UI_STAT_TEX := preload("res://UI assets/UI_stat.png")
const RECT_TEX := preload("res://UI assets/Rectangulo_UI_Para_texto.png")
# Recorte del marco de madera dentro del sprite Rectangulo (sin el relleno transparente)
const RECT_REGION := Rect2(18, 23, 108, 39)

# Indicador de aparición de enemigos (rojo, animado)
const SPAWN_INDICATOR := preload("res://Scenes/SpawnIndicator.tscn")
const INDICATOR_COLOR := Color(1.0, 0.22, 0.2, 0.95)

func _ready() -> void:
	randomize()
	# El GameMode (y su UI) sigue activo aunque el árbol esté en pausa,
	# para que las pantallas y sus botones funcionen.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_waves()
	Game.reset()
	Game.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(Game.coins)

	shop.continue_pressed.connect(_on_shop_continue)
	shop.visible = false

	_build_screens()
	_build_inventory()
	_build_options()
	_style_labels()
	_update_wave_label()
	timer_label.text = ""
	info_label.text = ""

	call_deferred("_connect_player")
	_show_start()

func _style_labels() -> void:
	UiTheme.apply_label(coins_label)
	UiTheme.apply_label(wave_label)
	UiTheme.apply_label(info_label)
	UiTheme.apply_title(timer_label, 32)
	UiTheme.apply_title(announce_label, 48)

func _connect_player() -> void:
	player = _find_player()
	if player != null and player.has_signal("died"):
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null

func _process(delta: float) -> void:
	if _screen_active or get_tree().paused or not wave_active:
		return

	# Cuenta atrás de la oleada
	time_left -= delta
	_update_timer_label()
	if time_left <= 0.0:
		_end_wave()
		return

	_spawn_accum -= delta
	if _spawn_accum <= 0.0:
		_spawn_accum = _group_interval()
		_spawn_group()

func _unhandled_input(event: InputEvent) -> void:
	# F11 alterna pantalla completa (en cualquier momento, también en menús)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_toggle_fullscreen()
		return
	if _screen_active:
		return
	# ESC: menú de opciones (o cierra lo que esté abierto)
	if event.is_action_pressed("ui_cancel"):
		if _inventory_open:
			_set_inventory(false)
		else:
			_set_options(not _options_open)
		return
	# E: inventario
	if event.is_action_pressed("inventory"):
		if not _options_open:
			_set_inventory(not _inventory_open)
		return
	if _options_open or _inventory_open:
		return
	# Atajos de depuración: SOLO en DEV-ROOM (debug_mode)
	if debug_mode:
		_handle_debug_input(event)

func _handle_debug_input(event: InputEvent) -> void:
	# Control de oleadas/jefe (DEV-ROOM): M = iniciar, N = terminar, B = jefe
	if event.is_action_pressed("start_wave") and not wave_active and not shop.visible:
		_start_wave()
	elif event.is_action_pressed("end_wave") and wave_active:
		_end_wave()
	elif event.is_action_pressed("spawn_boss"):
		_spawn_boss()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_debug_spawn(minion_scene)
			KEY_2:
				_debug_spawn(bigminion_scene)
			KEY_3:
				_debug_spawn(bulletminion_scene)
			KEY_4:
				_debug_spawn(charger_scene)
			KEY_5:
				_debug_spawn(support_scene)
			KEY_O:
				_enter_shop()
			KEY_C:
				Game.add_coins(100)
			KEY_G:
				_toggle_god_mode()

func _debug_spawn(scene: PackedScene) -> void:
	"""Genera un enemigo de prueba (no ataca) cerca del jugador."""
	if scene == null:
		return
	if player == null or not is_instance_valid(player):
		player = _find_player()
	if player == null:
		return
	var e = scene.instantiate()
	if e.has_method("make_passive"):
		e.make_passive()
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	host.add_child(e)
	e.global_position = player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 320.0

func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _toggle_god_mode() -> void:
	if player == null or not is_instance_valid(player):
		player = _find_player()
	if player == null:
		return
	player.debug_invincible = not player.debug_invincible
	info_label.text = "God mode: %s" % ("ON" if player.debug_invincible else "OFF")

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
	info_label.text = "Oleada %d en curso%s" % [wave_number, ("  —  N: terminar" if debug_mode else "")]

func _end_wave() -> void:
	wave_active = false
	time_left = 0.0
	timer_label.text = ""
	info_label.text = ""
	_clear_enemies()

	# En DEV-ROOM no se encadena nada automáticamente: el jugador usa los atajos.
	if debug_mode:
		info_label.text = "DEV-ROOM:  M = siguiente oleada  ·  O = tienda  ·  B = jefe"
		return

	# Aviso de oleada superada (~2s, centrado y grande) antes de mostrar la tienda.
	var is_final_wave := wave_number >= total_waves
	_show_announce("¡Oleada %d superada!%s" % [wave_number, ("\nEl jefe se aproxima..." if is_final_wave else "")])
	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(self):
		return
	_hide_announce()

	# Curación automática entre rondas, EXCEPTO en la ronda previa al jefe.
	if not is_final_wave:
		if player != null and is_instance_valid(player) and player.has_method("full_heal"):
			player.full_heal()

	# Main: tienda entre oleadas; tras la última, al salir aparece el jefe.
	if is_final_wave:
		_boss_pending = true
		info_label.text = "Compra mejoras y prepárate para el JEFE"
	_enter_shop()

func _show_announce(text: String) -> void:
	announce_label.text = text
	announce_label.visible = true

func _hide_announce() -> void:
	announce_label.visible = false
	announce_label.text = ""

func _enter_shop() -> void:
	# Al entrar a la tienda: las balas en vuelo desaparecen y el jugador se
	# congela (las monedas en el suelo NO se tocan, se recogen en la próxima oleada).
	_clear_bullets()
	if player != null and is_instance_valid(player) and player.has_method("set_frozen"):
		player.set_frozen(true)
	# Ocultar el HUD del jugador para que no estorbe a la tienda
	_set_gameplay_ui_visible(false)
	shop.open(wave_number)

func _clear_bullets() -> void:
	for bullet in get_tree().get_nodes_in_group("spin_bullet"):
		bullet.queue_free()

func _on_shop_continue() -> void:
	if player != null and is_instance_valid(player) and player.has_method("set_frozen"):
		player.set_frozen(false)
	# Restaurar el HUD al salir de la tienda
	_set_gameplay_ui_visible(true)
	if _boss_pending:
		# Al salir de la tienda tras la oleada final, aparece el jefe
		_boss_pending = false
		_spawn_boss()
	elif auto_start_waves:
		# Main: empieza automáticamente la siguiente oleada
		_start_wave()
	elif debug_mode:
		info_label.text = "DEV-ROOM:  M = siguiente oleada  ·  O = tienda  ·  B = jefe"

# =============================================================================
# TABLA DE OLEADAS
# =============================================================================
# Cada oleada define su intervalo de aparición y un "pool" de tipos de enemigo
# con pesos: [escena, peso]. El spawner elige al azar según esos pesos. Para
# modificar o añadir oleadas, edita _build_waves() (ver docs/oleadas.md).
func _build_waves() -> void:
	_waves = [
		{"interval": 0.8, "pool": [[minion_scene, 1]]},
		{"interval": 0.8, "pool": [[minion_scene, 3], [charger_scene, 1]]},
		{"interval": 0.9, "pool": [[minion_scene, 2], [bigminion_scene, 1]]},
		{"interval": 0.9, "pool": [[minion_scene, 2], [charger_scene, 2]]},
		{"interval": 1.0, "pool": [[bigminion_scene, 2], [bulletminion_scene, 1]]},
		{"interval": 0.9, "pool": [[minion_scene, 2], [charger_scene, 2], [support_scene, 1]]},
		{"interval": 1.0, "pool": [[bulletminion_scene, 2], [bigminion_scene, 1], [support_scene, 1]]},
		{"interval": 0.9, "pool": [[charger_scene, 2], [bigminion_scene, 2], [bulletminion_scene, 1]]},
		{"interval": 0.9, "pool": [[minion_scene, 2], [charger_scene, 2], [bulletminion_scene, 1], [bigminion_scene, 1], [support_scene, 1]]},
		{"interval": 0.8, "pool": [[minion_scene, 2], [charger_scene, 2], [bigminion_scene, 2], [bulletminion_scene, 2], [support_scene, 1]]},
	]

func _spawn_interval() -> float:
	var idx := clampi(wave_number - 1, 0, _waves.size() - 1)
	return _waves[idx].get("interval", 1.0)

func _group_interval() -> float:
	# Como ahora aparecen grupos (varios enemigos), se espacian más que el
	# intervalo de un solo enemigo, y se cuenta también el tiempo de aviso.
	return _spawn_interval() * 4.0 + spawn_warning_time

func _pick_enemy_scene() -> PackedScene:
	"""Elige un tipo de enemigo de la oleada actual por peso (ignora nulos)."""
	var idx := clampi(wave_number - 1, 0, _waves.size() - 1)
	var pool: Array = _waves[idx].get("pool", [])
	var total := 0
	for entry in pool:
		if entry[0] != null:
			total += int(entry[1])
	if total <= 0:
		return minion_scene
	var roll := randi() % total
	for entry in pool:
		if entry[0] == null:
			continue
		roll -= int(entry[1])
		if roll < 0:
			return entry[0]
	return minion_scene

func _spawn_host() -> Node:
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	return host

# Genera un grupo (pequeño o grande) precedido de indicadores rojos en cada
# punto exacto donde aparecerá un enemigo.
func _spawn_group() -> void:
	if player == null or not is_instance_valid(player):
		player = _find_player()
	if player == null:
		return

	var is_large := randf() < large_group_chance
	var count := randi_range(large_group_min, large_group_max) if is_large \
		else randi_range(small_group_min, small_group_max)

	# Centro del grupo a distancia fija del jugador; los enemigos se reparten
	# alrededor de ese centro.
	var base_angle := randf() * TAU
	var center: Vector2 = player.global_position + Vector2(cos(base_angle), sin(base_angle)) * spawn_radius
	var spread := 140.0 if is_large else 70.0

	var positions: Array = []
	for i in count:
		positions.append(center + Vector2(randf_range(-spread, spread), randf_range(-spread, spread)))

	_telegraph_and_spawn(positions, is_large)

func _telegraph_and_spawn(positions: Array, is_large: bool) -> void:
	# 1) Mostrar los indicadores de aparición unos segundos
	var indicators: Array = []
	var ind_scale := 2.6 if is_large else 1.9
	for p in positions:
		var ind = SPAWN_INDICATOR.instantiate()
		_spawn_host().add_child(ind)
		ind.setup(p, INDICATOR_COLOR, ind_scale)
		indicators.append(ind)

	await get_tree().create_timer(spawn_warning_time).timeout
	if not is_instance_valid(self):
		return

	# 2) Quitar los indicadores
	for ind in indicators:
		if is_instance_valid(ind):
			ind.queue_free()

	# Si la oleada terminó o se abrió la tienda/pantalla durante el aviso, no
	# aparecen los enemigos.
	if not wave_active or _screen_active or shop.visible:
		return

	# 3) Spawnear el grupo en los puntos avisados
	for p in positions:
		_spawn_enemy_at(p)

func _spawn_enemy_at(pos: Vector2) -> void:
	var scene := _pick_enemy_scene()
	if scene == null:
		return
	var enemy = scene.instantiate()
	_spawn_host().add_child(enemy)
	enemy.global_position = pos

func _clear_enemies() -> void:
	# Limpia los minions de la oleada, pero NO al jefe.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_in_group("boss"):
			continue
		enemy.queue_free()
	# También retira los indicadores de aparición pendientes.
	for ind in get_tree().get_nodes_in_group("spawn_indicator"):
		ind.queue_free()

#=============================================================================
# JEFE
#=============================================================================
func _spawn_boss() -> void:
	if _boss != null and is_instance_valid(_boss):
		return   #ya hay un jefe en juego
	if boss_scene == null:
		_show_victory()   #sin jefe asignado: victoria directa
		return
	if player == null or not is_instance_valid(player):
		player = _find_player()

	var boss = boss_scene.instantiate()
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	host.add_child(boss)
	if player != null:
		boss.global_position = player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 480.0
	if boss.has_signal("died"):
		boss.died.connect(_on_boss_defeated)
	_boss = boss

	wave_active = false
	timer_label.text = ""
	info_label.text = "¡JEFE FINAL!"

func _on_boss_defeated() -> void:
	_boss = null
	_show_victory()

# =============================================================================
# PANTALLAS (inicio / victoria / muerte)
# =============================================================================
func _build_screens() -> void:
	# Inicio: solo el sprite Rectangulo con el texto JUGAR (UI antigua eliminada).
	_start_screen = _build_start_screen()
	# Victoria y muerte: caja del sprite UI_stat con el mensaje y un botón.
	_victory_screen = _build_message_screen("¡VICTORIA!",
		"Has superado todas las oleadas.", "Jugar de nuevo", _on_restart_pressed)
	_death_screen = _build_message_screen("HAS MUERTO",
		"Te han derrotado.", "Reintentar", _on_restart_pressed)

func _dim_screen() -> Control:
	"""Crea una pantalla a rejilla completa con un fondo oscuro translúcido."""
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.05, 0.9)
	screen.add_child(bg)
	return screen

# Botón con el sprite Rectangulo_UI_Para_texto de fondo (marco de madera).
func _make_rect_button(text: String, size: Vector2, font_size: int, cb: Callable) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size = size

	var np := NinePatchRect.new()
	np.set_anchors_preset(Control.PRESET_FULL_RECT)
	np.texture = RECT_TEX
	np.region_rect = RECT_REGION
	np.patch_margin_left = 8
	np.patch_margin_right = 8
	np.patch_margin_top = 7
	np.patch_margin_bottom = 7
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(np)

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.24, 0.15, 0.07))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)

	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.focus_mode = Control.FOCUS_NONE
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	btn.mouse_entered.connect(func(): holder.modulate = Color(1.12, 1.12, 1.12))
	btn.mouse_exited.connect(func(): holder.modulate = Color.WHITE)
	btn.pressed.connect(cb)
	holder.add_child(btn)
	return holder

func _build_start_screen() -> Control:
	var screen := _dim_screen()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 30)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "SPINSHOT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_title(title, 64)
	vbox.add_child(title)

	var play := _make_rect_button("JUGAR", Vector2(260, 96), 30, _on_start_pressed)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(play)

	screen.visible = false
	ui.add_child(screen)
	return screen

func _build_message_screen(title_text: String, body_text: String, button_text: String, cb: Callable) -> Control:
	var screen := _dim_screen()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)

	# Caja del sprite UI_stat (400x400)
	var box := Control.new()
	box.custom_minimum_size = Vector2(400, 400)
	center.add_child(box)

	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = UI_STAT_TEX
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bg)

	# Título en la placa superior del sprite
	var title := Label.new()
	title.position = Vector2(146, 54)
	title.size = Vector2(108, 46)
	title.text = title_text
	title.clip_text = true
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.22, 0.13, 0.06))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	# Cuerpo del mensaje en el panel interior
	var body := Label.new()
	body.position = Vector2(86, 138)
	body.size = Vector2(228, 110)
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.24, 0.15, 0.07))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(body)

	# Botón en la parte baja del panel interior
	var button := _make_rect_button(button_text, Vector2(196, 66), 18, cb)
	button.position = Vector2(102, 270)
	box.add_child(button)

	screen.visible = false
	ui.add_child(screen)
	return screen

func _show_start() -> void:
	_set_screen(_start_screen)

func _show_victory() -> void:
	_set_screen(_victory_screen)

func _show_death() -> void:
	_set_screen(_death_screen)

func _set_screen(screen: Control) -> void:
	_start_screen.visible = screen == _start_screen
	_victory_screen.visible = screen == _victory_screen
	_death_screen.visible = screen == _death_screen
	_screen_active = true
	_set_gameplay_ui_visible(false)
	get_tree().paused = true

func _hide_screens() -> void:
	_start_screen.visible = false
	_victory_screen.visible = false
	_death_screen.visible = false
	_screen_active = false
	_set_gameplay_ui_visible(true)
	get_tree().paused = false

func _on_start_pressed() -> void:
	_hide_screens()
	if debug_mode:
		info_label.text = "DEV-ROOM:  M = oleada · N = terminar · B = jefe · 1-5 = enemigos · O = tienda · C = +100 · G = god"
	elif auto_start_waves:
		_start_wave()   # Main: las oleadas empiezan automáticamente
	else:
		info_label.text = "Pulsa para empezar"

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_player_died() -> void:
	_show_death()

# =============================================================================
# INVENTARIO (ESC o desde la tienda)
# =============================================================================
func _build_inventory() -> void:
	_inventory_panel = Control.new()
	_inventory_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_panel.visible = false

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	_inventory_panel.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inventory_panel.add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	center.add_child(row)

	# Panel de inventario con el sprite UI_Inventario_E (500x400)
	var inv := Control.new()
	inv.custom_minimum_size = Vector2(500, 400)
	row.add_child(inv)

	var inv_bg := TextureRect.new()
	inv_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	inv_bg.texture = UI_INVENTORY_TEX
	inv_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	inv_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inv_bg.stretch_mode = TextureRect.STRETCH_SCALE
	inv_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv.add_child(inv_bg)

	var inv_title := Label.new()
	inv_title.position = Vector2(185, 52)
	inv_title.size = Vector2(130, 40)
	inv_title.text = "Inventario"
	inv_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inv_title.add_theme_font_size_override("font_size", 18)
	inv_title.add_theme_color_override("font_color", Color(0.25, 0.16, 0.08))
	inv_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv.add_child(inv_title)

	_inventory_grid = GridContainer.new()
	_inventory_grid.position = Vector2(74, 120)
	_inventory_grid.size = Vector2(352, 230)
	_inventory_grid.columns = 4
	_inventory_grid.add_theme_constant_override("h_separation", 8)
	_inventory_grid.add_theme_constant_override("v_separation", 8)
	inv.add_child(_inventory_grid)

	# Estadísticas (sprite UI_stat) al lado
	_inv_stats_holder = Control.new()
	_inv_stats_holder.custom_minimum_size = Vector2(400, 400)
	row.add_child(_inv_stats_holder)

	ui.add_child(_inventory_panel)

# =============================================================================
# MENÚ DE OPCIONES (ESC) — sprite UI_ESC
# =============================================================================
func _build_options() -> void:
	_options_panel = Control.new()
	_options_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_options_panel.visible = false

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	_options_panel.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_panel.add_child(center)

	var panel := Control.new()
	panel.custom_minimum_size = Vector2(400, 400)
	center.add_child(panel)

	var esc_bg := TextureRect.new()
	esc_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	esc_bg.texture = UI_ESC_TEX
	esc_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	esc_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	esc_bg.stretch_mode = TextureRect.STRETCH_SCALE
	esc_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(esc_bg)

	# 7 botones en el orden pedido (huecos del sprite UI_ESC)
	var col_l := 78.0
	var col_r := 220.0
	var w := 104.0
	var h := 38.0
	_make_esc_button(panel, Vector2(148, 62), Vector2(w, h), "SpinShot", func(): _on_opt_placeholder("SpinShot"))
	_make_esc_button(panel, Vector2(col_l, 148), Vector2(w, h), "Controles", _on_opt_controls)
	_make_esc_button(panel, Vector2(col_r, 148), Vector2(w, h), "Idioma", func(): _on_opt_placeholder("Idioma"))
	_make_esc_button(panel, Vector2(col_l, 202), Vector2(w, h), "Resolución", func(): _on_opt_placeholder("Resolución"))
	_make_esc_button(panel, Vector2(col_r, 202), Vector2(w, h), "Sonido", func(): _on_opt_placeholder("Sonido"))
	_make_esc_button(panel, Vector2(col_l, 256), Vector2(w, h), "Créditos", func(): _on_opt_placeholder("Créditos"))
	_make_esc_button(panel, Vector2(col_r, 256), Vector2(w, h), "Salida", _on_opt_exit)

	_build_controls_box()
	ui.add_child(_options_panel)

func _make_esc_button(parent: Control, pos: Vector2, size: Vector2, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.position = pos
	b.size = size
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color(0.22, 0.14, 0.07))
	b.add_theme_color_override("font_hover_color", Color(0.05, 0.03, 0.02))
	b.pressed.connect(cb)
	parent.add_child(b)

func _build_controls_box() -> void:
	_controls_box = Control.new()
	_controls_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls_box.visible = false
	_options_panel.add_child(_controls_box)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	_controls_box.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls_box.add_child(center)

	# Caja del sprite UI_stat (400x400)
	var box := Control.new()
	box.custom_minimum_size = Vector2(400, 400)
	center.add_child(box)

	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = UI_STAT_TEX
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bg)

	var title := Label.new()
	title.position = Vector2(146, 54)
	title.size = Vector2(108, 46)
	title.text = "CONTROLES"
	title.clip_text = true
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.22, 0.13, 0.06))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	var body := Label.new()
	body.position = Vector2(84, 128)
	body.size = Vector2(232, 132)
	body.text = "WASD / Flechas: mover\nEspacio: esquivar\nClic der.: SpinShot azul\nClic izq.: SpinShot naranja\nE: inventario\nESC: opciones\nF11: pantalla completa"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.24, 0.15, 0.07))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(body)

	var back := _make_rect_button("Volver", Vector2(170, 60), 16, func(): _controls_box.visible = false)
	back.position = Vector2(115, 274)
	box.add_child(back)

func _on_opt_controls() -> void:
	_controls_box.visible = true

func _on_opt_exit() -> void:
	get_tree().quit()

func _on_opt_placeholder(_name: String) -> void:
	# Botón interactivo, pendiente de implementación futura.
	pass

# =============================================================================
# ESTADO DE LOS OVERLAYS (inventario / opciones)
# =============================================================================
func _set_inventory(open: bool) -> void:
	if _screen_active:
		return
	if open:
		_options_open = false
		_options_panel.visible = false
		_refresh_inventory()
	_inventory_open = open
	_inventory_panel.visible = open
	_apply_overlay_state()

func _set_options(open: bool) -> void:
	if _screen_active:
		return
	if open:
		_inventory_open = false
		_inventory_panel.visible = false
	else:
		_controls_box.visible = false
	_options_open = open
	_options_panel.visible = open
	_apply_overlay_state()

func _apply_overlay_state() -> void:
	var any := _options_open or _inventory_open
	_set_gameplay_ui_visible(not any and not shop.visible)
	get_tree().paused = any

func _set_gameplay_ui_visible(v: bool) -> void:
	"""Muestra/oculta el HUD de la partida (vida, esquive, monedas, oleada,
	tiempo, info) para que no estorbe al abrir el inventario o una pantalla."""
	coins_label.visible = v
	wave_label.visible = v
	timer_label.visible = v
	info_label.visible = v
	if not v:
		announce_label.visible = false
	if player != null and is_instance_valid(player) and player.has_method("set_hud_visible"):
		player.set_hud_visible(v)

func _refresh_inventory() -> void:
	for c in _inventory_grid.get_children():
		c.queue_free()

	if player == null or not is_instance_valid(player):
		player = _find_player()

	# Reconstruir el panel de estadísticas
	if _inv_stats_holder != null:
		for c in _inv_stats_holder.get_children():
			c.queue_free()
		_inv_stats_holder.add_child(StatsPanel.build(player))
	var inv: Dictionary = {}
	if player != null:
		var v = player.get("inventory")
		if v is Dictionary:
			inv = v

	if inv.is_empty():
		var empty := Label.new()
		empty.text = "(Aún no has comprado ningún ítem)"
		UiTheme.apply_label(empty)
		_inventory_grid.add_child(empty)
		return

	for id in inv.keys():
		_inventory_grid.add_child(_make_inventory_slot(inv[id]))

func _make_inventory_slot(data: Dictionary) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(80, 80)
	UiTheme.apply_slot(slot)
	slot.tooltip_text = "%s\n\n%s\n\nCantidad/Nivel: %d" % [
		String(data.get("name", "")),
		String(data.get("desc", "")),
		int(data.get("count", 1)),
	]

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6.0
	icon.offset_top = 6.0
	icon.offset_right = -6.0
	icon.offset_bottom = -6.0
	icon.texture = data.get("icon", null)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	var count := Label.new()
	count.text = "x%d" % int(data.get("count", 1))
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -30.0
	count.offset_top = -24.0
	count.offset_right = -4.0
	count.offset_bottom = -2.0
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_theme_color_override("font_color", UiTheme.GOLD)
	count.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	count.add_theme_constant_override("shadow_offset_x", 1)
	count.add_theme_constant_override("shadow_offset_y", 1)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count)

	return slot

# =============================================================================
# UI
# =============================================================================
func _on_coins_changed(total: int) -> void:
	coins_label.text = "Monedas: %d" % total

func _update_wave_label() -> void:
	if wave_number == 0:
		wave_label.text = "Oleada: -"
	else:
		wave_label.text = "Oleada %d / %d" % [wave_number, total_waves]

func _update_timer_label() -> void:
	timer_label.text = "Tiempo: %d s" % ceili(maxf(time_left, 0.0))
