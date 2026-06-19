class_name Personaje
extends CharacterBody2D

# =============================================================================
# MÁQUINA DE ESTADOS DEL PERSONAJE
# =============================================================================
enum State { 
	MOVE,                    # Estado de movimiento normal (sin armas)
	MOVE_WITH_ONE_GUN,       # Estado de movimiento con arma de una mano
	MOVE_WITH_TWO_GUNS,      # Estado de movimiento con arma de dos manos
	MOVE_WITH_DUAL_WIELD,    # Estado de movimiento con dos armas (una en cada mano)
	DODGE,                   # Estado de esquiva/rodar
	TAKING_DAMAGE,           # Estado de recibir daño
	DEAD                     # Estado de muerte
}
var current_state: State = State.MOVE

# =============================================================================
# CONFIGURACIÓN DE PROPIEDADES Y NODOS
# =============================================================================
# Nodos de la escena
@onready var pickup_area = $PickupArea
@onready var control_animated = $CONTROLANIMATED

# Nodos del sistema de brazos separados
@onready var arm_pivot = $ArmPivot
@onready var weapon_holder = $ArmPivot/WeaponHolder
@onready var secondary_weapon = $ArmPivot/SecundaryWeapon

# Nodos para armas de dos manos
@onready var gun_two_hands = $GUNTWOHANDS
@onready var weapon_holder2 = $GUNTWOHANDS/WeaponHolder2
@onready var healthbar = $HUD/HealthBar

# Nodos del sistema modular de ropa
@onready var chest_layer = $CONTROLANIMATED/Chest_Layer
@onready var head_layer = $CONTROLANIMATED/Head_Layer
@onready var legs_layer = $CONTROLANIMATED/Legs_Layer

# Capa para el torso sin brazos cuando estamos armados
@onready var chest_no_arms_layer = $CONTROLANIMATED/Chest_NoArms_Layer

# Nodo del inventario (ahora es hijo de Billy)
var inventory_ui: Control = null

# Barras de munición (una por mano: principal y secundaria)
var ammo_bar: AmmoBar = null
var ammo_bar2: AmmoBar = null

# Panel de estadísticas para pruebas (se alterna con F3)
var stats_label: Label = null

# HUD del arma (estilo Enter the Gungeon): fichas con el sprite del arma,
# la activa grande al frente y la enfundada apilada detrás; la rueda del
# mouse las intercambia (cualquier dirección)
var active_weapon_card: Panel = null
var holstered_weapon_card: Panel = null

# Animación de cambio de ficha (deslizado de atrás hacia el frente)
var _weapon_card_front_pos: Vector2 = Vector2.INF
var _weapon_card_back_pos: Vector2 = Vector2.INF
var _weapon_switch_tween: Tween = null


# Variables de vida del personaje
@export var speed: float = 350.0
@export var vida: int = 20
@export var vida_max: int = 20

# Variables del sistema de daño
var is_invulnerable: bool = false
var invulnerability_duration: float = 0.9
var damage_timer: Timer

# Configuración del sistema de dodge roll
@export_group("Dodge Roll")
@export var dodge_speed: float = 600.0
@export var dodge_duration: float = 0.75

# =============================================================================
# VARIABLES DE CONTROL
# =============================================================================
# Variables de movimiento
var input_direction: Vector2
var last_direction: Vector2 = Vector2.DOWN  # Dirección por defecto (mirando hacia abajo)

# Sistema de pausa
var is_inventory_open: bool = false

# Timers para el sistema de dodge
var dodge_timer: Timer
var dodge_cooldown: Timer

# =============================================================================
# SISTEMA DE ARMAS
# =============================================================================
var current_weapon: Node2D = null  # Arma actualmente equipada
var current_weapon_data: ItemData = null  # Datos del arma actualmente equipada
var weapon_attachment_point: Node2D  # Punto donde se adjunta el arma

# Sistema de dos armas estilo Enter the Gungeon: cada mano lleva un arma,
# pero solo una está "en la mano" (activa); la otra queda enfundada y se
# cambia con la rueda del mouse / Q
var main_hand_data: ItemData = null  # Datos del arma en MAIN_HAND
var off_hand_data: ItemData = null   # Datos del arma en OFF_HAND
var active_hand: String = "MAIN_HAND"  # Mano cuya arma está en uso

# Variables para el sistema de apuntado
var mouse_position: Vector2
var arm_angle: float
var is_aiming: bool = false

# Variables para el sistema de ángulo del arma (estilo Enter the Gungeon)
var weapon_angle: float
var weapon_direction: Vector2

# Configuración del apuntado: el arma orbita la "mano" a radio fijo
@export_group("Apuntado")
@export var hand_offset: Vector2 = Vector2(0, 10)  # Posición de la mano respecto al centro del personaje
@export var weapon_orbit_radius: float = 14.0      # Distancia del arma a la mano

# Variables para el sistema de bounce del arma
var weapon_bounce_offset: float = 0.0
var bounce_amplitude: float = 3.0  # Altura del bounce
var bounce_speed: float = 8.0      # Velocidad del bounce

# Variables del sistema de ropa modular
var equipped_chest: ItemData = null
var equipped_head: ItemData = null
var equipped_legs: ItemData = null

# Variable para rastrear si estamos armados
var is_armed: bool = false

# =============================================================================
# INICIALIZACIÓN
# =============================================================================
func _ready():
	"""Inicializa el personaje y configura todos los sistemas necesarios"""
	add_to_group("player")
	_setup_dodge_timers()
	_setup_weapon_system()
	_setup_damage_system()
	connect_to_item_pickups()
	ensure_no_inventory_loaded()
	healthbar.init_health(vida)
	
	# Debug: Verificar nodos disponibles
	print("=== DEBUG NODOS EN BILLY ===")
	for child in get_children():
		print("Nodo hijo: ", child.name, " (", child.get_class(), ")")
	
	# Inicializar sistema de ropa modular
	_setup_clothing_system()
	
	# Debug: Verificar si InventoryUI existe
	if has_node("HUD/Inventory"):
		print("✅ Inventario encontrado en el HUD (CanvasLayer)")
		inventory_ui = $HUD/Inventory
	elif has_node("InventoryUI"):
		print("✅ InventoryUI encontrado como hijo directo")
		inventory_ui = $InventoryUI
	else:
		print("❌ InventoryUI NO encontrado como hijo directo")
		# Buscar en toda la jerarquía
		var found = find_child("InventoryUI", true, false)
		if found:
			print("✅ InventoryUI encontrado en jerarquía: ", found.get_path())
			inventory_ui = found
		else:
			print("❌ InventoryUI NO encontrado en toda la jerarquía")
			# Buscar por tipo Control
			var controls = find_children("*", "Control", true, false)
			for control in controls:
				if "Inventory" in control.name:
					print("✅ Control de inventario encontrado: ", control.name)
					inventory_ui = control
					break
	
	# Verificar que se encontró el inventario
	if inventory_ui != null:
		print("✅ Inventario configurado correctamente: ", inventory_ui.name)
		# Conectar las señales del equipamiento DESPUÉS de encontrar el inventario
		_connect_equipment_signals()
	else:
		print("❌ ERROR: No se pudo encontrar el inventario!")
	
	# Configurar barra de munición
	_setup_ammo_bar()

	# Panel de estadísticas de prueba (F3)
	_setup_stats_overlay()

	# HUD del arma activa/enfundada
	_setup_weapon_hud()

func _setup_dodge_timers():
	"""Configura los timers necesarios para el sistema de dodge roll"""
	# Timer para la duración del dodge
	dodge_timer = Timer.new()
	dodge_timer.wait_time = dodge_duration
	dodge_timer.one_shot = true
	dodge_timer.timeout.connect(_on_dodge_timer_timeout)
	add_child(dodge_timer)
	print("✅ Dodge timer inicializado")
	
	# Timer para el cooldown del dodge
	dodge_cooldown = Timer.new()
	dodge_cooldown.wait_time = 0.5
	dodge_cooldown.one_shot = true
	add_child(dodge_cooldown)
	print("✅ Dodge cooldown timer inicializado")

func _setup_weapon_system():
	"""Configura el sistema de armas del personaje"""
	# Crear el punto de adjunción del arma
	weapon_attachment_point = Node2D.new()
	weapon_attachment_point.name = "WeaponAttachmentPoint"
	add_child(weapon_attachment_point)
	
	# Ocultar los brazos armados por defecto
	_hide_armed_arms()

func _connect_equipment_signals():
	"""Conecta las señales del inventario para detectar equipamiento"""
	if inventory_ui != null:
		inventory_ui.equipment_changed.connect(_on_equipment_changed)
		print("✅ Señales de equipamiento conectadas correctamente")
	else:
		print("❌ ERROR: No se puede conectar señales - inventory_ui es null!")

func _setup_ammo_bar():
	"""Configura las barras de munición (una por mano)"""
	ammo_bar = find_child("AmmoBar", true, false)
	ammo_bar2 = find_child("AmmoBar2", true, false)

	if ammo_bar:
		print("✅ AmmoBar encontrada: ", ammo_bar.name)
		# Ocultar inicialmente hasta que se equipe un arma
		ammo_bar.visible = false
	else:
		print("❌ ERROR: No se pudo encontrar AmmoBar!")
		# Crear una barra de munición temporal si no existe
		_create_temporary_ammo_bar()

	if ammo_bar2:
		ammo_bar2.visible = false
	else:
		print("⚠️ AmmoBar2 no encontrada: el arma secundaria no tendrá barra propia")

func _create_temporary_ammo_bar():
	"""Crea una barra de munición temporal si no se encuentra una en la escena"""
	print("⚠️ Creando AmmoBar temporal...")
	# Por ahora solo imprimir un mensaje, en el futuro se podría crear dinámicamente
	# ammo_bar = preload("res://Scenes/UI/AmmoBar.tscn").instantiate()
	# add_child(ammo_bar)

func _setup_damage_system():
	"""Configura el sistema de daño e invulnerabilidad"""
	# Timer para invulnerabilidad después de recibir daño
	damage_timer = Timer.new()
	damage_timer.wait_time = invulnerability_duration
	damage_timer.one_shot = true
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	add_child(damage_timer)

func _setup_clothing_system():
	"""Configura el sistema modular de ropa"""
	print("=== CONFIGURANDO SISTEMA DE ROPA MODULAR ===")
	
	# Las capas del cuerpo SIEMPRE están visibles: son el personaje base, no ropa.
	# El sistema de trajes cambiará texturas, no visibilidad.
	if chest_layer:
		print("✅ Chest_Layer encontrado")
		chest_layer.visible = true
	else:
		print("❌ Chest_Layer NO encontrado")

	if head_layer:
		print("✅ Head_Layer encontrado")
		head_layer.visible = true
	else:
		print("❌ Head_Layer NO encontrado")

	if legs_layer:
		print("✅ Legs_Layer encontrado")
		legs_layer.visible = true
	else:
		print("❌ Legs_Layer NO encontrado")

	# El torso sin manos solo se muestra con un arma equipada
	if chest_no_arms_layer:
		chest_no_arms_layer.visible = false

	# Configurar orden de capas (z_index)
	if legs_layer:
		legs_layer.z_index = 0      # Piernas atrás
	if control_animated:
		control_animated.z_index = 1  # Control de animaciones
	if chest_layer:
		chest_layer.z_index = 2     # Pecho
	if chest_no_arms_layer:
		chest_no_arms_layer.z_index = 2  # Torso sin manos, mismo nivel que el pecho
	if head_layer:
		head_layer.z_index = 3      # Cabeza adelante
	
	print("✅ Sistema de ropa modular configurado")

# =============================================================================
# SISTEMA DE RECOGIDA DE ITEMS
# =============================================================================
func connect_to_item_pickups():
	"""Conecta automáticamente a todos los ItemPickup del escenario"""
	# Buscar todos los nodos ItemPickup en el escenario
	var item_pickups = get_tree().get_nodes_in_group("item_pickup")
	for pickup in item_pickups:
		if pickup.has_signal("item_picked_up"):
			pickup.item_picked_up.connect(_on_ItemPickup_item_picked_up)
			print("Conectado a ItemPickup: ", pickup.name)
	
	# También buscar por nombre (por si no están en grupo)
	var all_nodes = get_tree().get_nodes_in_group("")
	for node in all_nodes:
		if "ItemPickup" in node.name and node.has_signal("item_picked_up"):
			if not node.item_picked_up.is_connected(_on_ItemPickup_item_picked_up):
				node.item_picked_up.connect(_on_ItemPickup_item_picked_up)
				print("Conectado a ItemPickup por nombre: ", node.name)

func ensure_no_inventory_loaded():
	"""Asegura que no hay inventarios cargados previamente"""
	# La lógica de visibilidad ahora se maneja en InventoryUI._set_initial_visibility()
	print("Inventario configurado con visibilidad inicial correcta")

# =============================================================================
# MÁQUINA DE ESTADOS PRINCIPAL
# =============================================================================
func _physics_process(delta):
	"""Procesa la física del personaje según el estado actual"""
	# Actualizar el panel de estadísticas (funciona también con el inventario abierto)
	_update_stats_overlay()

	# Si el inventario está abierto, pausar el juego
	if is_inventory_open:
		# Solo mantener la posición actual, no procesar inputs de movimiento/disparo
		velocity = Vector2.ZERO
		move_and_slide()
		
		# Detener animaciones y reproducir animación idle
		_play_idle_animation()
		return
	
	# Procesar estados normalmente cuando el inventario está cerrado
	match current_state:
		State.MOVE:
			move_state(delta)
		State.MOVE_WITH_ONE_GUN:
			move_with_one_gun_state(delta)
		State.MOVE_WITH_TWO_GUNS:
			move_with_two_guns_state(delta)
		State.MOVE_WITH_DUAL_WIELD:
			move_with_dual_wield_state(delta)
		State.DODGE:
			dodge_state(delta)
		State.TAKING_DAMAGE:
			taking_damage_state(delta)
		State.DEAD:
			dead_state(delta)


# =============================================================================
# ESTADO DE MOVIMIENTO
# =============================================================================
func move_state(delta):
	"""Maneja el estado de movimiento normal del personaje"""
	# Obtener input de movimiento (WASD)
	input_direction = Input.get_vector("Izquierda", "Derecha", "Arriba", "Abajo")
	
	# Aplicar movimiento
	velocity = input_direction.normalized() * get_move_speed()
	move_and_slide()
	
	# Actualizar animaciones
	update_move_animation()
	
	# Verificar si se puede hacer dodge roll
	# Solo se puede usar dodge roll si hay input de movimiento y el cooldown ha terminado
	if Input.is_action_just_pressed("dodge") and input_direction != Vector2.ZERO and dodge_cooldown != null and dodge_cooldown != null and dodge_cooldown.is_stopped():
		start_dodge()
	
	# Verificar input de disparo
	if Input.is_action_pressed("shoot") and current_weapon != null:
		_shoot_weapon()
	
	# Cambiar a estado armado si se tiene un arma equipada
	if current_weapon != null and current_state == State.MOVE:
		current_state = _get_armed_state()

# =============================================================================
# ESTADO DE DODGE ROLL
# =============================================================================
func dodge_state(delta):
	"""Maneja el estado de dodge roll del personaje"""
	# En el estado de dodge, el personaje mantiene la velocidad del dodge hasta que termine el timer
	move_and_slide()

# =============================================================================
# ESTADO ARMADO CON UNA MANO
# =============================================================================
func armed_onehand_state(delta):
	"""Maneja el estado armado con una mano"""
	# Obtener input de movimiento (WASD)
	input_direction = Input.get_vector("Izquierda", "Derecha", "Arriba", "Abajo")
	
	# Aplicar movimiento
	velocity = input_direction.normalized() * get_move_speed()
	move_and_slide()
	
	# Actualizar apuntado (esto incluye las animaciones basadas en mouse)
	_update_aiming()
	
	# Solo usar animaciones de movimiento si NO estamos armados o si no hay movimiento
	if not is_armed or velocity.length() == 0:
		update_move_animation()
	
	# Verificar si se puede hacer dodge roll
	if Input.is_action_just_pressed("dodge") and input_direction != Vector2.ZERO and dodge_cooldown != null and dodge_cooldown.is_stopped():
		start_dodge()
	
	# Verificar input de disparo
	if Input.is_action_pressed("shoot"):
		_shoot_weapon()
	
	# Cambiar a estado normal si no hay arma
	if current_weapon == null:
		current_state = State.MOVE

# =============================================================================
# ESTADO ARMADO CON DOS MANOS
# =============================================================================
func armed_twohand_state(delta):
	"""Maneja el estado armado con dos manos"""
	# Obtener input de movimiento (WASD)
	input_direction = Input.get_vector("Izquierda", "Derecha", "Arriba", "Abajo")
	
	# Aplicar movimiento
	velocity = input_direction.normalized() * get_move_speed()
	move_and_slide()
	
	# Actualizar apuntado (esto incluye las animaciones basadas en mouse)
	_update_aiming()
	
	# Solo usar animaciones de movimiento si NO estamos armados o si no hay movimiento
	if not is_armed or velocity.length() == 0:
		update_move_animation()
	
	# Verificar si se puede hacer dodge roll
	if Input.is_action_just_pressed("dodge") and input_direction != Vector2.ZERO and dodge_cooldown != null and dodge_cooldown.is_stopped():
		start_dodge()
	
	# Verificar input de disparo
	if Input.is_action_pressed("shoot"):
		_shoot_weapon()
	
	# Cambiar a estado normal si no hay arma
	if current_weapon == null:
		current_state = State.MOVE

# =============================================================================
# NUEVOS ESTADOS DE MOVIMIENTO CON ARMAS
# =============================================================================

func move_with_one_gun_state(delta):
	"""Maneja el estado de movimiento con arma de una mano"""
	# Obtener input de movimiento (WASD)
	input_direction = Input.get_vector("Izquierda", "Derecha", "Arriba", "Abajo")
	
	# Aplicar movimiento
	velocity = input_direction.normalized() * get_move_speed()
	move_and_slide()
	
	# Actualizar apuntado
	_update_aiming()
	
	# Usar animaciones de movimiento con arma
	if velocity.length() == 0:
		# Si no se está moviendo, usar animaciones basadas en mouse
		_play_mouse_based_animation()
	else:
		# Si se está moviendo, usar animaciones de movimiento normales
		update_move_animation()
	
	# Verificar si se puede hacer dodge roll
	if Input.is_action_just_pressed("dodge") and input_direction != Vector2.ZERO and dodge_cooldown != null and dodge_cooldown.is_stopped():
		start_dodge()
	
	# Verificar input de disparo
	if Input.is_action_pressed("shoot"):
		_shoot_weapon()
	
	# Cambiar a estado normal si no hay arma
	if current_weapon == null:
		current_state = State.MOVE

func move_with_two_guns_state(delta):
	"""Maneja el estado de movimiento con arma de dos manos"""
	# Obtener input de movimiento (WASD)
	input_direction = Input.get_vector("Izquierda", "Derecha", "Arriba", "Abajo")
	
	# Aplicar movimiento
	velocity = input_direction.normalized() * get_move_speed()
	move_and_slide()
	
	# Actualizar apuntado
	_update_aiming()
	
	# Usar animaciones de movimiento con arma
	if velocity.length() == 0:
		# Si no se está moviendo, usar animaciones basadas en mouse
		_play_mouse_based_animation()
	else:
		# Si se está moviendo, usar animaciones de movimiento normales
		update_move_animation()
	
	# Verificar si se puede hacer dodge roll
	if Input.is_action_just_pressed("dodge") and input_direction != Vector2.ZERO and dodge_cooldown != null and dodge_cooldown.is_stopped():
		start_dodge()
	
	# Verificar input de disparo
	if Input.is_action_pressed("shoot"):
		_shoot_weapon()
	
	# Cambiar a estado normal si no hay arma
	if current_weapon == null:
		current_state = State.MOVE

func move_with_dual_wield_state(delta):
	"""Maneja el estado de movimiento con dos armas (dual wield)"""
	# Obtener input de movimiento (WASD)
	input_direction = Input.get_vector("Izquierda", "Derecha", "Arriba", "Abajo")
	
	# Aplicar movimiento
	velocity = input_direction.normalized() * get_move_speed()
	move_and_slide()
	
	# Actualizar apuntado
	_update_aiming()
	
	# Usar animaciones de movimiento con arma
	if velocity.length() == 0:
		# Si no se está moviendo, usar animaciones basadas en mouse
		_play_mouse_based_animation()
	else:
		# Si se está moviendo, usar animaciones de movimiento normales
		update_move_animation()
	
	# Verificar si se puede hacer dodge roll
	if Input.is_action_just_pressed("dodge") and input_direction != Vector2.ZERO and dodge_cooldown != null and dodge_cooldown.is_stopped():
		start_dodge()
	
	# Verificar input de disparo
	if Input.is_action_pressed("shoot"):
		_shoot_weapon()
	
	# Cambiar a estado normal si no hay armas
	if current_weapon == null:
		current_state = State.MOVE

# =============================================================================
# SISTEMA DE ANIMACIONES
# =============================================================================
func update_move_animation():
	"""Actualiza las animaciones de movimiento del personaje"""
	if velocity.length() == 0:
		_play_idle_animation()
	else:
		_play_walk_animation()

func _play_idle_animation():
	"""Reproduce la animación idle según la última dirección"""
	# Animaciones idle según la última dirección guardada
	var animation_name = ""
	var should_flip = false
	
	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0:
			animation_name = "Default_Right"  # Mirando derecha
			should_flip = false
		else:
			animation_name = "Default_Right"  # Mirando izquierda - Usar Default_Right con flip
			should_flip = true
	else:
		if last_direction.y > 0:
			animation_name = "Default_Down"   # Mirando abajo
			should_flip = false
		else:
			animation_name = "Default_Up"     # Mirando arriba
			should_flip = false
	
	# Reproducir animación en todas las capas activas con flip
	_play_animation_on_all_layers(animation_name, should_flip)

func _play_walk_animation():
	"""Reproduce la animación de caminar según la dirección actual"""
	# Guardar la dirección actual para futuras animaciones idle
	last_direction = input_direction
	
	# Animaciones de caminar según la dirección del input
	var animation_name = ""
	var should_flip = false
	
	if abs(input_direction.x) > abs(input_direction.y):
		# Movimiento horizontal dominante
		if input_direction.x > 0:
			animation_name = "Walk_Right"  # D
			should_flip = false
		else:
			animation_name = "Walk_Right"  # A - Usar Walk_Right con flip
			should_flip = true
	else:
		# Movimiento vertical dominante
		if input_direction.y > 0:
			animation_name = "Walk_Down"   # S
			should_flip = false
		else:
			animation_name = "Walk_Up"     # W
			should_flip = false
	
	# Reproducir animación en todas las capas activas con flip
	_play_animation_on_all_layers(animation_name, should_flip)

func _play_animation_on_all_layers(animation_name: String, should_flip: bool = false):
	"""Reproduce la misma animación en todas las capas activas del sistema modular"""
	# Determinar el sufijo de animación según el tipo de arma
	var animation_suffix = _get_animation_suffix()
	
	# Convertir nombre de animación base a nombres específicos de cada capa
	var head_animation = animation_name + "_HEAD"
	var chest_animation = animation_name + "_CHEST" + animation_suffix
	var legs_animation = animation_name + "_LEGS"
	
	# Reproducir en capa de pecho según si estamos armados o no
	if is_armed and chest_no_arms_layer and chest_no_arms_layer.visible:
		# Si estamos armados, usar la capa sin brazos
		if chest_no_arms_layer.sprite_frames and chest_no_arms_layer.sprite_frames.has_animation(chest_animation):
			chest_no_arms_layer.play(chest_animation)
			chest_no_arms_layer.flip_h = should_flip
		else:
			# Fallback a animación sin sufijo si no existe la específica
			var fallback_animation = animation_name + "_CHEST"
			if chest_no_arms_layer.sprite_frames and chest_no_arms_layer.sprite_frames.has_animation(fallback_animation):
				chest_no_arms_layer.play(fallback_animation)
				chest_no_arms_layer.flip_h = should_flip
	elif chest_layer and chest_layer.visible:
		# Si no estamos armados, usar la capa normal
		if chest_layer.sprite_frames and chest_layer.sprite_frames.has_animation(chest_animation):
			chest_layer.play(chest_animation)
			chest_layer.flip_h = should_flip
		else:
			# Fallback a animación sin sufijo si no existe la específica
			var fallback_animation = animation_name + "_CHEST"
			if chest_layer.sprite_frames and chest_layer.sprite_frames.has_animation(fallback_animation):
				chest_layer.play(fallback_animation)
				chest_layer.flip_h = should_flip
	
	# Reproducir en capa de cabeza (si está equipada)
	if head_layer and head_layer.visible:
		if head_layer.sprite_frames and head_layer.sprite_frames.has_animation(head_animation):
			head_layer.play(head_animation)
			head_layer.flip_h = should_flip
	
	# Reproducir en capa de piernas (si está equipada)
	if legs_layer and legs_layer.visible:
		if legs_layer.sprite_frames and legs_layer.sprite_frames.has_animation(legs_animation):
			legs_layer.play(legs_animation)
			legs_layer.flip_h = should_flip

	# Sincronizar los frames de todas las capas
	_sync_layer_frames()

func _sync_layer_frames():
	"""Mantiene cabeza/torso/piernas en el mismo frame del ciclo de animación.
	Cada capa es un AnimatedSprite2D independiente: si una empieza su ciclo más
	tarde (p. ej. al equipar un arma mientras corres), las piernas y el torso
	quedan desfasados y el personaje se ve 'despedazado'."""
	var reference: AnimatedSprite2D = legs_layer
	if reference == null or not reference.visible or reference.sprite_frames == null:
		return
	if not reference.sprite_frames.has_animation(reference.animation):
		return

	var ref_count = reference.sprite_frames.get_frame_count(reference.animation)
	for layer in [head_layer, chest_layer, chest_no_arms_layer]:
		if layer == null or not layer.visible or layer.sprite_frames == null:
			continue
		if not layer.sprite_frames.has_animation(layer.animation):
			continue
		# Solo sincronizar ciclos con la misma cantidad de frames
		if layer.sprite_frames.get_frame_count(layer.animation) == ref_count:
			layer.frame = reference.frame
			layer.frame_progress = reference.frame_progress

func _get_animation_suffix() -> String:
	"""Determina el sufijo de animación del torso según el arma equipada"""
	# Con cualquier arma equipada se usa el torso sin manos ("_Two_Hands"):
	# las manos dejan de flotar junto al cuerpo porque van sobre el arma
	if current_weapon != null:
		return "_Two_Hands"

	# Sin arma, sin sufijo (torso normal con manos)
	return ""

# =============================================================================
# SISTEMA DE DODGE ROLL
# =============================================================================
func start_dodge():
	"""Inicia el dodge roll del personaje"""
	current_state = State.DODGE
	
	# La dirección del dodge roll es la misma que la del input de movimiento actual
	var dodge_direction = input_direction.normalized()
	
	# Establecer velocidad del dodge
	velocity = dodge_direction * dodge_speed
	
	# Reproducir la animación de dodge
	play_dodge_animation(dodge_direction)
	
	# Ocultar el ArmPivot durante el roll
	if arm_pivot != null:
		arm_pivot.visible = false
	if gun_two_hands != null:
		gun_two_hands.visible = false
	print("✅ Armas ocultas durante el roll")
	
	# Activar invulnerabilidad durante el dodge
	_activate_dodge_invulnerability()
	
	# Iniciar el timer para terminar el dodge
	if dodge_timer != null:
		dodge_timer.start()
	else:
		print("❌ ERROR: dodge_timer es null!")
	
	# Iniciar el cooldown
	if dodge_cooldown != null:
		dodge_cooldown.start()
	else:
		print("❌ ERROR: dodge_cooldown es null!")

func play_dodge_animation(direction: Vector2):
	"""Reproduce la animación de dodge roll según la dirección"""
	var animation_name = ""
	var should_flip = false
	
	if abs(direction.x) > abs(direction.y):
		# Movimiento horizontal dominante
		if direction.x > 0:
			animation_name = "Roll_Right"  # D
			should_flip = false
		else:
			animation_name = "Roll_Right"  # A - Usar Roll_Right con flip
			should_flip = true
	else:
		# Movimiento vertical dominante
		if direction.y > 0:
			animation_name = "Roll_Down"   # S
			should_flip = false
		else:
			animation_name = "Roll_Up"     # W
			should_flip = false
	
	# Reproducir animación en todas las capas activas con flip
	_play_animation_on_all_layers(animation_name, should_flip)

func _activate_dodge_invulnerability():
	"""Activa la invulnerabilidad durante el dodge roll"""
	is_invulnerable = true
	print("Invulnerabilidad de dodge activada")
	# No usar damage_timer aquí, el dodge_timer manejará la duración

func _on_dodge_timer_timeout():
	"""Callback cuando termina el timer del dodge"""
	# Desactivar invulnerabilidad del dodge
	is_invulnerable = false
	print("Invulnerabilidad de dodge desactivada")
	
	# Restaurar la visibilidad del arma si hay una equipada
	if current_weapon != null:
		if current_weapon_data != null and current_weapon_data.is_two_handed:
			if gun_two_hands != null:
				gun_two_hands.visible = true
				print("✅ Arma de dos manos restaurada después del roll")
		else:
			if arm_pivot != null:
				arm_pivot.visible = true
				print("✅ Arma de una mano restaurada después del roll")
	
	# Volver al estado apropiado según el arma equipada
	if current_weapon != null:
		current_state = _get_armed_state()
	else:
		current_state = State.MOVE
	velocity = Vector2.ZERO  # Detener el movimiento del dodge
	
	# Volver a la animación idle apropiada
	update_move_animation()

# =============================================================================
# SISTEMA DE vida, Daño y muerte
# =============================================================================

func _set_health(value: int):
	"""Establece la vida del personaje y actualiza la barra de vida"""
	vida = clamp(value, 0, vida_max)
	healthbar.health = vida
	
	# Verificar si el personaje muere
	if vida <= 0:
		_die()
	else:
		print("Vida actualizada: ", vida, "/", vida_max)

func take_damage(damage_amount: int):
	"""Recibe daño del enemigo"""
	# Si está muerto, es invulnerable, o está haciendo dodge roll, no recibir daño
	if current_state == State.DEAD or is_invulnerable or current_state == State.DODGE:
		if current_state == State.DODGE:
			print("Dodge roll bloqueó el daño!")
		return
	
	# Aplicar la defensa de armaduras/items/sinergias (siempre entra al menos 1 de daño)
	var defense = int(Inventory.get_stat("defense"))
	var final_damage = max(1, damage_amount - defense)
	if defense > 0:
		print("🛡️ Defensa ", defense, ": daño ", damage_amount, " -> ", final_damage)
	print("Recibiendo daño: ", final_damage)

	# Cambiar a estado de recibir daño
	current_state = State.TAKING_DAMAGE
	
	# Ocultar el arma durante la animación de daño
	if arm_pivot != null:
		arm_pivot.visible = false
	if gun_two_hands != null:
		gun_two_hands.visible = false
	print("✅ Armas ocultas durante animación de daño")
	
	# Reducir vida
	_set_health(vida - final_damage)
	
	# Activar invulnerabilidad temporal
	_activate_invulnerability()
	
	# Reproducir animación de recibir daño
	_play_hurt_animation()

func _activate_invulnerability():
	"""Activa la invulnerabilidad temporal"""
	is_invulnerable = true
	damage_timer.start()
	print("Invulnerabilidad activada por ", invulnerability_duration, " segundos")

func _play_hurt_animation():
	"""Reproduce la animación de recibir daño en todas las capas activas"""
	print("💥 Reproduciendo animación de daño")

	# Convertir nombre de animación base a nombres específicos de cada capa
	var head_animation = "Hurt_HEAD"
	var chest_animation = "Hurt_CHEST"
	var legs_animation = "Hurt_LEGS"

	# Elegir la capa de pecho ACTIVA: con arma equipada el torso visible es
	# chest_no_arms_layer, no chest_layer (que está oculto)
	var active_chest: AnimatedSprite2D = chest_layer
	if is_armed and chest_no_arms_layer and chest_no_arms_layer.visible:
		active_chest = chest_no_arms_layer

	if active_chest and active_chest.visible:
		if active_chest.sprite_frames and active_chest.sprite_frames.has_animation(chest_animation):
			active_chest.play(chest_animation)
		else:
			print("⚠️ Animación '", chest_animation, "' no encontrada en ", active_chest.name)

	# Reproducir en capa de cabeza
	if head_layer and head_layer.visible:
		if head_layer.sprite_frames and head_layer.sprite_frames.has_animation(head_animation):
			head_layer.play(head_animation)

	# Reproducir en capa de piernas
	if legs_layer and legs_layer.visible:
		if legs_layer.sprite_frames and legs_layer.sprite_frames.has_animation(legs_animation):
			legs_layer.play(legs_animation)

	# Mantener las capas en el mismo frame del ciclo
	_sync_layer_frames()

func _on_damage_timer_timeout():
	"""Callback cuando termina el timer de invulnerabilidad"""
	is_invulnerable = false
	print("Invulnerabilidad desactivada")
	
	# Volver al estado normal si no está muerto
	if current_state == State.TAKING_DAMAGE:
		# Restaurar la visibilidad del arma si hay una equipada
		if current_weapon != null:
			if current_weapon_data != null and current_weapon_data.is_two_handed:
				if gun_two_hands != null:
					gun_two_hands.visible = true
					print("✅ Arma de dos manos restaurada después de animación de daño")
			else:
				if arm_pivot != null:
					arm_pivot.visible = true
					print("✅ Arma de una mano restaurada después de animación de daño")
		
		if current_weapon != null:
			current_state = _get_armed_state()
		else:
			current_state = State.MOVE

func _die():
	"""Maneja la muerte del personaje: reproduce la animación de esqueleto,
	espera un momento y reinicia el nivel"""
	if current_state == State.DEAD:
		return
	print("¡El personaje ha muerto! GAME OVER")
	current_state = State.DEAD
	velocity = Vector2.ZERO

	# Ocultar las armas
	if arm_pivot != null:
		arm_pivot.visible = false
	if gun_two_hands != null:
		gun_two_hands.visible = false

	# Reutilizar la animación de daño (esqueleto parpadeante) como muerte
	_play_hurt_animation()

	# TODO: reemplazar por una pantalla de game over cuando exista
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

func _on_enemy_damage_received(damage_amount: int):
	"""Función para ser llamada por enemigos cuando causan daño"""
	take_damage(damage_amount)

# =============================================================================
# ESTADOS DE DAÑO Y MUERTE
# =============================================================================

func taking_damage_state(delta):
	"""Maneja el estado de recibir daño"""
	# En este estado, el personaje puede moverse y hacer dodge roll pero no disparar
	# Solo espera a que termine la invulnerabilidad
	
	# Permitir movimiento normal durante el estado de daño
	input_direction = Input.get_vector("Izquierda", "Derecha", "Arriba", "Abajo")
	velocity = input_direction.normalized() * get_move_speed()
	move_and_slide()
	
	# Permitir dodge roll para escapar
	if Input.is_action_just_pressed("dodge") and input_direction != Vector2.ZERO and dodge_cooldown != null and dodge_cooldown.is_stopped():
		start_dodge()
	
	# NO actualizar animaciones de movimiento durante el estado de daño
	# La animación de daño se reproduce una sola vez al entrar al estado
	# y se mantiene hasta que termine la invulnerabilidad

func dead_state(delta):
	"""Maneja el estado de muerte"""
	# En este estado, el personaje no puede hacer nada
	# Solo espera a que se reinicie el juego
	
	# Detener todo movimiento
	velocity = Vector2.ZERO
	move_and_slide()
	
	# TODO: Reproducir animación de muerte
	# control_animated no reproduce animaciones directamente, usa las capas hijas
	
	# TODO: Mostrar pantalla de game over después de un tiempo
	# if death_timer.is_stopped():
	#     get_tree().change_scene_to_file("res://Scenes/UI/GameOver.tscn")



# =============================================================================
# SISTEMA DE INVENTARIO
# =============================================================================
func _on_ItemPickup_item_picked_up(item_id: String):
	"""Maneja la recogida de items"""
	# Usa la instancia local del inventario
	if inventory_ui != null:
		inventory_ui.pickup_item(item_id)
		print("Ítem recogido: ", item_id)
	else:
		print("ERROR: inventory_ui es null!")

func _unhandled_input(event):
	"""Maneja inputs no procesados por otros sistemas"""
	if Input.is_action_just_pressed("Inventario"):
		toggle_inventory()
	elif Input.is_action_just_pressed("toggle_stats"):
		if stats_label != null:
			stats_label.visible = not stats_label.visible
	elif Input.is_action_just_pressed("weapon_switch"):
		_switch_weapon()
	elif Input.is_action_just_pressed("reload"):
		# Recargar el arma activa (el cargador del arma enfundada se queda como está)
		if current_weapon != null and current_weapon.has_method("start_reload"):
			current_weapon.start_reload()

func toggle_inventory():
	"""Alterna la visibilidad del inventario, manteniendo EquipmentSlots2 y EquipmentSlots3 siempre visibles"""
	# Usar la instancia local del inventario
	if inventory_ui != null:
		inventory_ui.toggle_inventory_visibility()
		
		# Actualizar estado de pausa
		is_inventory_open = not is_inventory_open

		# El HUD del arma se oculta mientras el inventario está abierto
		# (ahí están los slots GUNS) y vuelve al cerrarlo
		_update_weapon_hud()

		if is_inventory_open:
			# Detener cualquier animación en curso y reproducir idle
			_play_idle_animation()
			print("🎮 Juego pausado - Inventario abierto - Animaciones detenidas")
		else:
			print("🎮 Juego reanudado - Inventario cerrado - Animaciones reanudadas")
	else:
		print("ERROR: inventory_ui es null!")

# =============================================================================
# SISTEMA DE ARMAS
# =============================================================================
func _on_equipment_changed(slot_name: String, item_data: ItemData):
	"""Maneja los cambios en el equipamiento"""
	if slot_name == "MAIN_HAND" or slot_name == "OFF_HAND":
		# Registrar qué hay en cada mano y reconstruir el arma activa.
		# Si cambió el item de la mano, su barra se reconfigura (cargador nuevo)
		if slot_name == "MAIN_HAND":
			if item_data != main_hand_data and ammo_bar:
				ammo_bar.configured = false
			main_hand_data = item_data
		else:
			if item_data != off_hand_data and ammo_bar2:
				ammo_bar2.configured = false
			off_hand_data = item_data
		_refresh_weapons()
	elif slot_name == "CHEST":
		_equip_clothing("chest", item_data)
	elif slot_name == "HEAD":
		_equip_clothing("head", item_data)
	elif slot_name == "LEGS":
		_equip_clothing("legs", item_data)
	else:
		print("DEBUG - Slot no reconocido, ignorando: ", slot_name)

func _refresh_weapons():
	"""Instancia el arma de la mano activa (estilo Enter the Gungeon: solo un
	arma en la mano a la vez; la otra queda enfundada y se cambia con la rueda
	del mouse). Siempre se monta en el holder central para que el apuntado se
	sienta igual sin importar en qué slot esté el arma."""
	# Liberar el arma instanciada
	if current_weapon != null:
		current_weapon.queue_free()
	current_weapon = null
	current_weapon_data = null

	# Si la mano activa quedó vacía, pasar a la otra
	if _get_hand_data(active_hand) == null:
		active_hand = "OFF_HAND" if active_hand == "MAIN_HAND" else "MAIN_HAND"

	var data = _get_hand_data(active_hand)
	if data != null and data.weapon_scene != null:
		current_weapon = data.weapon_scene.instantiate()
		current_weapon_data = data
		var holder = weapon_holder
		if data.is_two_handed and weapon_holder2 != null:
			holder = weapon_holder2
		holder.add_child(current_weapon)

		# Conectar el arma a la barra de munición de SU mano (el cargador de
		# cada mano se conserva al cambiar de arma, no se rellena)
		var bar = ammo_bar if active_hand == "MAIN_HAND" else ammo_bar2
		if bar != null and current_weapon.has_method("set_ammo_bar"):
			current_weapon.set_ammo_bar(bar)

	# Actualizar estado armado/desarmado
	is_armed = current_weapon != null
	if is_armed:
		_show_armed_arms()
		current_state = _get_armed_state()
		print("🔫 Arma activa (", active_hand, "): ", current_weapon_data.item_name)
	else:
		_hide_armed_arms()
		if current_state in [State.MOVE_WITH_ONE_GUN, State.MOVE_WITH_TWO_GUNS, State.MOVE_WITH_DUAL_WIELD]:
			current_state = State.MOVE
		print("🔫 Sin armas equipadas")

	_update_weapon_hud()

	# Sincronizar el loadout de items con el arma activa (cada arma tiene
	# sus propios slots ITEM)
	if inventory_ui != null and inventory_ui.has_method("set_active_weapon_hand"):
		inventory_ui.set_active_weapon_hand(active_hand)

func _get_hand_data(hand: String) -> ItemData:
	return main_hand_data if hand == "MAIN_HAND" else off_hand_data

func _switch_weapon():
	"""Cambia el arma activa entre las dos manos (rueda del mouse / Q).
	La rueda funciona en cualquier dirección: con dos armas siempre alterna."""
	if main_hand_data == null or off_hand_data == null:
		return  # no hay segunda arma a la que cambiar
	active_hand = "OFF_HAND" if active_hand == "MAIN_HAND" else "MAIN_HAND"
	_refresh_weapons()

	# Animación estilo Gungeon: la ficha nueva desliza desde atrás al frente
	# y la anterior se repliega hacia atrás
	_animate_weapon_switch()

func _animate_weapon_switch():
	"""Desliza las fichas al cambiar de arma: la nueva activa entra desde la
	posición de atrás creciendo, la anterior se encoge hacia atrás"""
	if active_weapon_card == null or holstered_weapon_card == null:
		return
	if not active_weapon_card.visible or not holstered_weapon_card.visible:
		return

	# Guardar las posiciones base la primera vez (con las fichas en reposo)
	if _weapon_card_front_pos == Vector2.INF:
		_weapon_card_front_pos = active_weapon_card.position
		_weapon_card_back_pos = holstered_weapon_card.position

	# Si había una animación en curso, cortarla y partir desde las bases
	if _weapon_switch_tween != null and _weapon_switch_tween.is_valid():
		_weapon_switch_tween.kill()

	# Relación de tamaños entre la ficha trasera (72) y la frontal (120)
	var back_scale = holstered_weapon_card.size.x / active_weapon_card.size.x

	active_weapon_card.pivot_offset = Vector2.ZERO
	holstered_weapon_card.pivot_offset = Vector2.ZERO

	# La nueva activa parte desde atrás, pequeña...
	active_weapon_card.position = _weapon_card_back_pos
	active_weapon_card.scale = Vector2(back_scale, back_scale)
	# ...y la anterior parte desde el frente, grande
	holstered_weapon_card.position = _weapon_card_front_pos
	holstered_weapon_card.scale = Vector2(1.0 / back_scale, 1.0 / back_scale)

	_weapon_switch_tween = create_tween().set_parallel(true)
	_weapon_switch_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_weapon_switch_tween.tween_property(active_weapon_card, "position", _weapon_card_front_pos, 0.18)
	_weapon_switch_tween.tween_property(active_weapon_card, "scale", Vector2.ONE, 0.18)
	_weapon_switch_tween.tween_property(holstered_weapon_card, "position", _weapon_card_back_pos, 0.18)
	_weapon_switch_tween.tween_property(holstered_weapon_card, "scale", Vector2.ONE, 0.18)

func _setup_weapon_hud():
	"""Crea las fichas de armas (abajo a la izquierda): la activa al frente y
	la enfundada apilada detrás, con la munición al lado"""
	if not has_node("HUD"):
		return

	# Ficha del arma enfundada (detrás, más pequeña y atenuada)
	holstered_weapon_card = _make_weapon_card(72.0, 8.0)
	holstered_weapon_card.name = "HolsteredWeaponCard"
	holstered_weapon_card.offset_left = 104.0
	holstered_weapon_card.offset_top = -184.0
	holstered_weapon_card.offset_right = 176.0
	holstered_weapon_card.offset_bottom = -112.0
	holstered_weapon_card.modulate = Color(1, 1, 1, 0.55)
	$HUD.add_child(holstered_weapon_card)
	$HUD.move_child(holstered_weapon_card, 1)

	# Ficha del arma activa (al frente, grande)
	active_weapon_card = _make_weapon_card(120.0, 10.0)
	active_weapon_card.name = "ActiveWeaponCard"
	active_weapon_card.offset_left = 16.0
	active_weapon_card.offset_top = -136.0
	active_weapon_card.offset_right = 136.0
	active_weapon_card.offset_bottom = -16.0
	$HUD.add_child(active_weapon_card)
	$HUD.move_child(active_weapon_card, 2)

func _make_weapon_card(card_size: float, icon_margin: float) -> Panel:
	"""Crea una ficha de arma: panel con el estilo de la interfaz y un
	TextureRect 'Icon' adentro para el sprite del arma"""
	var card = Panel.new()
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.094, 0.078, 0.13, 0.92)
	style.border_color = Color(0.76, 0.6, 0.42)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", style)

	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.offset_left = icon_margin
	icon.offset_top = icon_margin
	icon.offset_right = card_size - icon_margin
	icon.offset_bottom = card_size - icon_margin
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)

	return card

func _update_weapon_hud():
	"""Actualiza las fichas y la munición. Todo el HUD del arma se oculta
	mientras el inventario está abierto (ahí se ve el panel GUNS)"""
	var hud_visible = not is_inventory_open

	# Munición: solo se ve la barra del arma activa (cada barra conserva
	# el cargador de su mano)
	var active_bar = ammo_bar if active_hand == "MAIN_HAND" else ammo_bar2
	var inactive_bar = ammo_bar2 if active_hand == "MAIN_HAND" else ammo_bar
	if inactive_bar:
		inactive_bar.visible = false
	if active_bar:
		active_bar.visible = hud_visible and current_weapon != null

	# Ficha grande: arma activa
	if active_weapon_card:
		active_weapon_card.visible = hud_visible and current_weapon_data != null
		active_weapon_card.get_node("Icon").texture = current_weapon_data.icon if current_weapon_data else null

	# Ficha pequeña apilada detrás: arma enfundada
	var other_hand = "OFF_HAND" if active_hand == "MAIN_HAND" else "MAIN_HAND"
	var holstered_data = _get_hand_data(other_hand)
	if holstered_weapon_card:
		holstered_weapon_card.visible = hud_visible and holstered_data != null
		holstered_weapon_card.get_node("Icon").texture = holstered_data.icon if holstered_data else null

func _get_armed_state() -> State:
	"""Estado de movimiento que corresponde al arma activa"""
	if current_weapon_data != null and current_weapon_data.is_two_handed:
		return State.MOVE_WITH_TWO_GUNS
	return State.MOVE_WITH_ONE_GUN

func _shoot_weapon():
	"""Dispara el arma activa"""
	if current_weapon != null and current_weapon.has_method("shoot"):
		current_weapon.shoot()

func get_move_speed() -> float:
	"""Velocidad base más los modificadores de items/armaduras/sinergias"""
	return maxf(50.0, speed + Inventory.get_stat("speed"))

# =============================================================================
# PANEL DE ESTADÍSTICAS DE PRUEBA (F3)
# =============================================================================
func _setup_stats_overlay():
	"""Crea el panel de estadísticas en el HUD, oculto hasta pulsar F3"""
	if not has_node("HUD"):
		print("⚠️ No hay HUD: panel de estadísticas no disponible")
		return

	stats_label = Label.new()
	stats_label.name = "StatsDebug"
	stats_label.position = Vector2(24, 64)  # bajo la barra de vida
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	stats_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	stats_label.add_theme_constant_override("shadow_offset_x", 1)
	stats_label.add_theme_constant_override("shadow_offset_y", 1)
	stats_label.visible = false
	$HUD.add_child(stats_label)
	print("✅ Panel de estadísticas listo (F3 para mostrar/ocultar)")

func _update_stats_overlay():
	"""Refresca el texto del panel de estadísticas si está visible"""
	if stats_label == null or not stats_label.visible:
		return

	var lines = []
	lines.append("=== STATS (F3) ===")
	lines.append("Vida: %d/%d" % [vida, vida_max])
	lines.append("Velocidad: %.0f" % get_move_speed())
	lines.append("Defensa: %d" % int(Inventory.get_stat("defense")))
	lines.append("Daño: x%.2f" % (1.0 + Inventory.get_stat("damage")))
	lines.append("Disparos: %d" % (1 + int(Inventory.get_stat("extra_shots"))))
	lines.append("Cadencia: %+.0f%%" % (Inventory.get_stat("fire_rate") * 100))
	lines.append("Vel. bala: %+.0f%%" % (Inventory.get_stat("bullet_speed") * 100))
	lines.append("Dispersión: %+.1f°" % Inventory.get_stat("bullet_spread"))
	lines.append("Homing: %.1f" % Inventory.get_stat("homing_strength"))
	lines.append("")
	lines.append("Tags: %s" % (", ".join(Inventory.active_tags) if Inventory.active_tags.size() > 0 else "—"))

	# Sinergias activas (sin usar get_active_synergies para no spamear la consola)
	var active_names = []
	for synergy in Synergy.synergies:
		var ok = true
		for r in synergy.get("requires", []):
			if not Inventory.active_tags.has(r):
				ok = false
				break
		if ok:
			active_names.append(synergy.get("name", "?"))
	lines.append("Sinergias: %s" % (", ".join(active_names) if active_names.size() > 0 else "—"))

	stats_label.text = "\n".join(lines)

# =============================================================================
# SISTEMA DE ROPA MODULAR
# =============================================================================
func _equip_clothing(clothing_type: String, item_data: ItemData):
	"""Equipa una pieza de ropa en el sistema modular"""
	print("DEBUG - Equipando ropa: ", clothing_type, " - ", item_data.item_name if item_data else "null")
	
	# Actualizar variables de ropa equipada
	match clothing_type:
		"chest":
			equipped_chest = item_data
			_update_clothing_layer(chest_layer, item_data)
		"head":
			equipped_head = item_data
			_update_clothing_layer(head_layer, item_data)
		"legs":
			equipped_legs = item_data
			_update_clothing_layer(legs_layer, item_data)
		_:
			print("ERROR - Tipo de ropa no reconocido: ", clothing_type)

func _update_clothing_layer(layer: AnimatedSprite2D, item_data: ItemData):
	"""Actualiza una capa de ropa específica"""
	if layer == null:
		print("ERROR - Capa de ropa es null")
		return
	
	# Las capas del cuerpo siempre quedan visibles: equipar/desequipar ropa
	# cambiará la textura de la capa cuando el sistema de trajes esté implementado
	if item_data == null:
		print("✅ Ropa desequipada de capa: ", layer.name)
	else:
		# TODO: cambiar el sprite de la capa según el item equipado
		# layer.sprite_frames = item_data.suit_frames  (sistema de trajes futuro)
		print("✅ Ropa equipada en capa: ", layer.name, " - ", item_data.item_name)

# =============================================================================
# SISTEMA DE BRAZOS SEPARADOS
# =============================================================================
func _update_aiming():
	"""Actualiza el apuntado de los brazos hacia el mouse"""
	if arm_pivot == null:
		return
	
	# Actualizar posición del mouse
	mouse_position = get_global_mouse_position()
	
	# Calcular sector y ángulo del arma
	var sector = _get_weapon_sector()
	
	# Actualizar posición del arma
	_update_weapon_position()
	
	# Actualizar qué mano mostrar basado en el sector
	_update_hand_by_sector(sector)
	
	# Las animaciones basadas en mouse ahora se manejan en cada estado específico
	# No se llaman aquí para evitar conflictos con las animaciones de movimiento

# =============================================================================
# SISTEMA DE ÁNGULO DEL ARMA (TOP-DOWN-MOVEMENT)
# =============================================================================
func _get_weapon_sector() -> int:
	"""Calcula el sector del arma basado en la posición del mouse (4 sectores)"""
	var mouse_pos = get_global_mouse_position()
	weapon_angle = global_position.angle_to_point(mouse_pos)
	weapon_direction = global_position.direction_to(mouse_pos)

	var degrees = rad_to_deg(weapon_angle)
	if degrees < 0:
		degrees += 360
	
	# 4 sectores de 90° cada uno
	if degrees >= 315 or degrees < 45:
		return 0  # Este
	elif degrees >= 45 and degrees < 135:
		return 1  # Sur
	elif degrees >= 135 and degrees < 225:
		return 2  # Oeste
	else:
		return 3  # Norte

func _update_hand_by_sector(sector: int):
	"""Actualiza qué mano mostrar basado en el sector del mouse"""
	if not is_armed:
		return
	
	# Sectores 0-1 (Este-Sur): brazo izquierdo
	# Sectores 2-3 (Oeste-Norte): brazo derecho
	# La lógica de cambio de mano se maneja en las animaciones
	# Los brazos físicos ya no existen, solo se usa para lógica de animaciones

func _play_mouse_based_animation():
	"""Reproduce animaciones basadas en la posición del mouse"""
	if not is_armed:
		return
	
	var sector = _get_weapon_sector()
	var animation_name = ""
	var should_flip = false
	
	# Determinar si el personaje se está moviendo
	var is_moving = velocity.length() > 0
	
	# Determinar animación basada en sector del mouse y estado de movimiento
	match sector:
		0:  # Este
			animation_name = "Walk_Right" if is_moving else "Default_Right"
			should_flip = false
		1:  # Sur
			animation_name = "Walk_Down" if is_moving else "Default_Down"
			should_flip = false
		2:  # Oeste
			animation_name = "Walk_Right" if is_moving else "Default_Right"
			should_flip = true
		3:  # Norte
			animation_name = "Walk_Up" if is_moving else "Default_Up"
			should_flip = false
	
	# Reproducir animación en todas las capas activas
	_play_animation_on_all_layers(animation_name, should_flip)

func _update_weapon_position():
	"""Apuntado estilo Enter the Gungeon: el arma orbita la mano a un radio fijo,
	rota apuntando exactamente al mouse y se voltea verticalmente al apuntar a la izquierda"""
	if not is_armed:
		return

	# Elegir el pivote según el tipo de arma
	var pivot: Node2D
	if current_weapon_data != null and current_weapon_data.is_two_handed:
		pivot = gun_two_hands
	else:
		pivot = arm_pivot
	if pivot == null:
		return

	# Posición de la mano (ancla del arma) y dirección de apuntado
	var hand_pos = global_position + hand_offset
	var aim_vector = get_global_mouse_position() - hand_pos
	if aim_vector.length_squared() < 1.0:
		return  # Mouse encima de la mano: conservar el apuntado anterior

	var aim_dir = aim_vector.normalized()
	weapon_angle = aim_dir.angle()
	weapon_direction = aim_dir

	# El arma orbita alrededor de la mano a radio fijo, sin importar
	# qué tan cerca esté el mouse (así nunca se solapa con el cuerpo)
	pivot.global_position = hand_pos + aim_dir * weapon_orbit_radius
	pivot.rotation = weapon_angle

	# Voltear verticalmente al apuntar a la izquierda para que el arma nunca se vea invertida
	pivot.scale.y = -1.0 if absf(weapon_angle) > PI / 2.0 else 1.0

	# El arma queda detrás del personaje cuando apunta hacia arriba.
	# z=0 la deja sobre el suelo pero detrás de las capas del cuerpo (z>=1);
	# con z=-1 quedaba oculta debajo del suelo.
	var degrees = fposmod(rad_to_deg(weapon_angle), 360.0)
	pivot.z_index = 0 if (degrees > 225.0 and degrees < 315.0) else 10


func _show_armed_arms():
	"""Muestra los brazos armados y oculta los brazos normales"""
	# Manejar lógica de cambio de mano según el tipo de arma y sector del mouse
	if current_weapon_data != null and current_weapon_data.is_two_handed:
		# Arma de dos manos: usar GUN_TWO_HANDS
		if gun_two_hands != null:
			gun_two_hands.visible = true
		if arm_pivot != null:
			arm_pivot.visible = false
		print("✅ Mostrando GUN_TWO_HANDS (arma de dos manos)")
	else:
		# Arma de una mano: usar ArmPivot
		if arm_pivot != null:
			arm_pivot.visible = true
		if gun_two_hands != null:
			gun_two_hands.visible = false
		# Usar sistema de sectores para cambiar de mano
		var sector = _get_weapon_sector()
		_update_hand_by_sector(sector)
		print("✅ Mostrando ArmPivot (arma de una mano)")
	
	# IMPORTANTE: Ocultar el Chest_Layer normal y mostrar el torso sin brazos
	if chest_layer != null:
		chest_layer.visible = false
		print("✅ Chest_Layer oculto - usando brazos separados (arma equipada)")
	
	# Mostrar la capa de torso sin brazos si existe
	if chest_no_arms_layer != null:
		chest_no_arms_layer.visible = true
		print("✅ Chest_NoArms_Layer mostrado")
	
	# Forzar actualización de animación en chest_no_arms_layer
	if chest_no_arms_layer != null and is_armed:
		# Reproducir la animación actual en la capa sin brazos
		var current_animation = ""
		if velocity.length() == 0:
			# Animación idle
			if abs(last_direction.x) > abs(last_direction.y):
				current_animation = "Default_Right" if last_direction.x > 0 else "Default_Right"
			else:
				current_animation = "Default_Down" if last_direction.y > 0 else "Default_Up"
		else:
			# Animación de movimiento
			if abs(input_direction.x) > abs(input_direction.y):
				current_animation = "Walk_Right"
			else:
				current_animation = "Walk_Down" if input_direction.y > 0 else "Walk_Up"
		
		# Aplicar sufijo de arma
		var animation_suffix = _get_animation_suffix()
		var chest_animation = current_animation + "_CHEST" + animation_suffix
		
		if chest_no_arms_layer.sprite_frames and chest_no_arms_layer.sprite_frames.has_animation(chest_animation):
			chest_no_arms_layer.play(chest_animation)
			print("✅ Reproduciendo animación de chest: ", chest_animation)

func _hide_armed_arms():
	"""Oculta los brazos armados y muestra los brazos normales"""
	if arm_pivot != null:
		arm_pivot.visible = false
	if gun_two_hands != null:
		gun_two_hands.visible = false
	print("✅ Ocultando todos los pivotes de armas")
	
	# IMPORTANTE: Restaurar el torso normal (con manos) cuando no hay arma.
	# El cuerpo siempre es visible, tenga o no ropa equipada.
	if chest_layer != null:
		chest_layer.visible = true
		print("✅ Chest_Layer restaurado (arma desequipada)")
	
	# Ocultar la capa de torso sin brazos
	if chest_no_arms_layer != null:
		chest_no_arms_layer.visible = false
		print("✅ Chest_NoArms_Layer oculto")
