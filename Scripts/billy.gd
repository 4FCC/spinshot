class_name Personaje
extends CharacterBody2D

# =============================================================================
# MÁQUINA DE ESTADOS DEL PERSONAJE
# =============================================================================
# Versión simplificada para la JAM (tema: GIRAR).
# Solo conserva los estados esenciales: movimiento, esquive y recibir daño.
enum State {
	MOVE,            # Movimiento normal
	DODGE,           # Esquive (gira sobre sí mismo e invulnerable)
	TAKING_DAMAGE,   # Recibiendo daño (invulnerabilidad temporal)
	DEAD             # Muerto
}
var current_state: State = State.MOVE

# =============================================================================
# NODOS DE LA ESCENA
# =============================================================================
@onready var sprite: Sprite2D = $Sprite2D

# UI (HUD): barra de vida y barra/etiqueta del esquive
@onready var health_bar: ProgressBar = $HUD/Root/HealthBar
@onready var health_label: Label = $HUD/Root/HealthBar/HealthLabel
@onready var dodge_bar: ProgressBar = $HUD/Root/DodgeBar
@onready var dodge_label: Label = $HUD/Root/DodgeBar/DodgeLabel

# =============================================================================
# PROPIEDADES CONFIGURABLES
# =============================================================================
@export var speed: float = 350.0
@export var vida: int = 20
@export var vida_max: int = 20

@export_group("Esquive")
@export var dodge_speed: float = 600.0       # Velocidad durante el esquive
@export var dodge_duration: float = 0.4      # Cuánto dura el esquive
@export var dodge_cooldown_time: float = 1.0 # Tiempo hasta poder esquivar de nuevo
@export var dodge_spin_turns: float = 1.0    # Vueltas completas que gira el sprite

@export_group("Daño")
@export var invulnerability_duration: float = 0.9

# =============================================================================
# VARIABLES INTERNAS
# =============================================================================
var input_direction: Vector2
var last_direction: Vector2 = Vector2.DOWN
var is_invulnerable: bool = false

# Dirección y giro acumulado del esquive (para la animación de girar)
var dodge_direction: Vector2 = Vector2.ZERO
var dodge_elapsed: float = 0.0

# Timers
var dodge_timer: Timer        # Duración del esquive
var dodge_cooldown: Timer     # Enfriamiento del esquive
var damage_timer: Timer       # Invulnerabilidad tras recibir daño

# =============================================================================
# INICIALIZACIÓN
# =============================================================================
func _ready():
	add_to_group("player")
	_setup_timers()
	vida = clamp(vida, 0, vida_max)
	health_bar.max_value = vida_max
	_update_health_ui()
	_update_dodge_ui()

func _setup_timers():
	# Timer que controla la duración del esquive
	dodge_timer = Timer.new()
	dodge_timer.wait_time = dodge_duration
	dodge_timer.one_shot = true
	dodge_timer.timeout.connect(_on_dodge_timer_timeout)
	add_child(dodge_timer)

	# Timer del enfriamiento (cooldown) del esquive
	dodge_cooldown = Timer.new()
	dodge_cooldown.wait_time = dodge_cooldown_time
	dodge_cooldown.one_shot = true
	add_child(dodge_cooldown)

	# Timer de invulnerabilidad tras recibir daño
	damage_timer = Timer.new()
	damage_timer.wait_time = invulnerability_duration
	damage_timer.one_shot = true
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	add_child(damage_timer)

# =============================================================================
# MÁQUINA DE ESTADOS PRINCIPAL
# =============================================================================
func _physics_process(delta):
	match current_state:
		State.MOVE:
			move_state(delta)
		State.DODGE:
			dodge_state(delta)
		State.TAKING_DAMAGE:
			taking_damage_state(delta)
		State.DEAD:
			dead_state(delta)

	# El HUD del esquive se refresca siempre (para ver bajar el cooldown)
	_update_dodge_ui()

# =============================================================================
# ESTADO: MOVIMIENTO
# =============================================================================
func move_state(_delta):
	input_direction = Input.get_vector("Izquierda", "Derecha", "Arriba", "Abajo")
	velocity = input_direction.normalized() * speed
	move_and_slide()

	if input_direction != Vector2.ZERO:
		last_direction = input_direction.normalized()

	# Iniciar esquive: requiere dirección y que el cooldown haya terminado
	if Input.is_action_just_pressed("dodge") and dodge_cooldown.is_stopped():
		start_dodge()

	# Prueba rápida del estado de daño (tecla K)
	if Input.is_action_just_pressed("test_damage"):
		take_damage(3)

# =============================================================================
# ESTADO: ESQUIVE (GIRAR)
# =============================================================================
func start_dodge():
	current_state = State.DODGE
	dodge_elapsed = 0.0

	# La dirección del esquive es la del input o, si está quieto, la última
	dodge_direction = input_direction.normalized()
	if dodge_direction == Vector2.ZERO:
		dodge_direction = last_direction

	velocity = dodge_direction * dodge_speed
	is_invulnerable = true

	dodge_timer.start()
	dodge_cooldown.start()

func dodge_state(delta):
	# Mantener el impulso del esquive
	velocity = dodge_direction * dodge_speed
	move_and_slide()

	# GIRAR: el sprite rota proporcionalmente a lo que dura el esquive
	dodge_elapsed += delta
	var t = clampf(dodge_elapsed / dodge_duration, 0.0, 1.0)
	sprite.rotation = t * TAU * dodge_spin_turns

func _on_dodge_timer_timeout():
	is_invulnerable = false
	sprite.rotation = 0.0
	velocity = Vector2.ZERO
	if current_state == State.DODGE:
		current_state = State.MOVE

# =============================================================================
# ESTADO: RECIBIR DAÑO
# =============================================================================
func take_damage(amount: int):
	# No recibir daño si está muerto, invulnerable o esquivando
	if current_state == State.DEAD or is_invulnerable or current_state == State.DODGE:
		return

	current_state = State.TAKING_DAMAGE
	vida = clamp(vida - amount, 0, vida_max)
	_update_health_ui()

	# Tinte rojo para indicar el golpe
	sprite.modulate = Color(1, 0.4, 0.4)

	if vida <= 0:
		_die()
		return

	is_invulnerable = true
	damage_timer.start()

func taking_damage_state(_delta):
	# Se puede seguir moviendo mientras dura la invulnerabilidad
	input_direction = Input.get_vector("Izquierda", "Derecha", "Arriba", "Abajo")
	velocity = input_direction.normalized() * speed
	move_and_slide()

	if input_direction != Vector2.ZERO:
		last_direction = input_direction.normalized()

	# También se puede esquivar para escapar
	if Input.is_action_just_pressed("dodge") and dodge_cooldown.is_stopped():
		start_dodge()

func _on_damage_timer_timeout():
	is_invulnerable = false
	sprite.modulate = Color.WHITE
	if current_state == State.TAKING_DAMAGE:
		current_state = State.MOVE

# =============================================================================
# ESTADO: MUERTE
# =============================================================================
func _die():
	current_state = State.DEAD
	velocity = Vector2.ZERO
	sprite.modulate = Color(0.5, 0.5, 0.5)

func dead_state(_delta):
	velocity = Vector2.ZERO
	move_and_slide()

# =============================================================================
# ACTUALIZACIÓN DEL HUD
# =============================================================================
func _update_health_ui():
	health_bar.value = vida
	health_label.text = "Vida: %d/%d" % [vida, vida_max]

func _update_dodge_ui():
	if dodge_cooldown == null:
		return

	if dodge_cooldown.is_stopped():
		# Esquive listo
		dodge_bar.value = dodge_bar.max_value
		dodge_label.text = "Esquive: LISTO"
		dodge_bar.modulate = Color(0.4, 1.0, 0.5)
	else:
		# Mostrar el progreso de recarga del esquive
		var ratio = 1.0 - (dodge_cooldown.time_left / dodge_cooldown.wait_time)
		dodge_bar.value = ratio * dodge_bar.max_value
		dodge_label.text = "Esquive: %.1fs" % dodge_cooldown.time_left
		dodge_bar.modulate = Color(1.0, 0.7, 0.3)
