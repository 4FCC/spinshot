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

# Inventario
var _inventory_panel: Control = null
var _inventory_grid: GridContainer = null
var _inventory_open: bool = false
var _inv_stats_holder: Control = null

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
		_spawn_accum = _spawn_interval()
		_spawn_enemy()

func _unhandled_input(event: InputEvent) -> void:
	# F11 alterna pantalla completa (en cualquier momento, también en menús)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_toggle_fullscreen()
		return
	if _screen_active:
		return
	# Inventario (ESC): disponible en cualquier escena
	if event.is_action_pressed("ui_cancel"):
		_toggle_inventory()
		return
	if _inventory_open:
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

func _spawn_enemy() -> void:
	var scene := _pick_enemy_scene()
	if scene == null:
		return
	if player == null or not is_instance_valid(player):
		player = _find_player()
	if player == null:
		return
	var enemy = scene.instantiate()
	var angle := randf() * TAU
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	host.add_child(enemy)
	enemy.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * spawn_radius

func _clear_enemies() -> void:
	# Limpia los minions de la oleada, pero NO al jefe.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_in_group("boss"):
			continue
		enemy.queue_free()

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
	_start_screen = _make_screen("SPINSHOT",
		"WASD: mover   Espacio: esquivar\nClic izq./der.: disparar Spin-Bullet (dos giros)\nESC: inventario",
		"JUGAR", _on_start_pressed)
	_victory_screen = _make_screen("¡VICTORIA!",
		"Has superado todas las oleadas.", "Jugar de nuevo", _on_restart_pressed)
	_death_screen = _make_screen("HAS MUERTO",
		"Te han derrotado.", "Reintentar", _on_restart_pressed)

func _make_screen(title_text: String, subtitle_text: String, button_text: String, button_cb: Callable) -> Control:
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.05, 0.9)
	screen.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)

	# Panel de madera que envuelve el contenido de la pantalla
	var panel := PanelContainer.new()
	UiTheme.apply_panel(panel)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_title(title, 52)
	vbox.add_child(title)

	if subtitle_text != "":
		var sub := Label.new()
		sub.text = subtitle_text
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiTheme.apply_label(sub)
		vbox.add_child(sub)

	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(240, 54)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiTheme.apply_button(button)
	button.pressed.connect(button_cb)
	vbox.add_child(button)

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

	# Inventario (izquierda) + Estadísticas (derecha)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	center.add_child(row)

	var panel := PanelContainer.new()
	UiTheme.apply_panel(panel)
	panel.custom_minimum_size = Vector2(440, 0)
	row.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "INVENTARIO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_title(title, 30)
	vbox.add_child(title)

	_inventory_grid = GridContainer.new()
	_inventory_grid.columns = 5
	_inventory_grid.add_theme_constant_override("h_separation", 10)
	_inventory_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(_inventory_grid)

	var hint := Label.new()
	hint.text = "Pasa el cursor sobre un ítem para ver sus detalles.  ESC para cerrar."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_label(hint)
	vbox.add_child(hint)

	# Columna de estadísticas (se rellena en _refresh_inventory)
	_inv_stats_holder = VBoxContainer.new()
	_inv_stats_holder.custom_minimum_size = Vector2(280, 0)
	row.add_child(_inv_stats_holder)

	ui.add_child(_inventory_panel)

func _toggle_inventory() -> void:
	if _screen_active:
		return
	_inventory_open = not _inventory_open
	if _inventory_open:
		_refresh_inventory()
		# Ocultar el HUD y los textos para que la interfaz quede limpia
		_set_gameplay_ui_visible(false)
		_inventory_panel.visible = true
		get_tree().paused = true
	else:
		_inventory_panel.visible = false
		# No volver a mostrar el HUD si seguimos dentro de la tienda
		if not shop.visible:
			_set_gameplay_ui_visible(true)
		if not _screen_active:
			get_tree().paused = false

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
