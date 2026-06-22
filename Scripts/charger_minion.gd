extends Enemy

# =============================================================================
# CHARGER MINION — Enemigo Cargador
# =============================================================================
# Persigue al jugador y, periódicamente, hace una breve carga (telegrafiada)
# en línea recta a gran velocidad. Su amenaza viene de la velocidad + daño.

@export_group("Carga")
@export var charge_interval: float = 3.0   # Tiempo entre cargas
@export var windup_time: float = 0.5       # Aviso antes de cargar (telegrafía)
@export var charge_time: float = 0.4       # Duración de la carga
@export var charge_speed: float = 750.0    # Velocidad durante la carga
@export var charge_range: float = 420.0    # Distancia a la que decide cargar

enum ChargePhase { CHASE, WINDUP, CHARGE }
var _phase: int = ChargePhase.CHASE
var _phase_timer: float = 0.0
var _cooldown: float = 0.0
var _charge_dir: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	_cooldown = charge_interval

func _update_ai(delta: float) -> void:
	if player == null:
		velocity = Vector2.ZERO
		return

	var to_player := player.global_position - global_position

	match _phase:
		ChargePhase.CHASE:
			# Persecución normal
			if to_player.length() > stop_distance:
				velocity = to_player.normalized() * move_speed
			else:
				velocity = Vector2.ZERO
			_cooldown -= delta
			# Cuando toca y el jugador está en rango, empieza el aviso de carga
			# (los maniquíes de prueba nunca embisten)
			if not passive and _cooldown <= 0.0 and to_player.length() <= charge_range:
				_phase = ChargePhase.WINDUP
				_phase_timer = windup_time

		ChargePhase.WINDUP:
			# Telegrafía: se queda quieto y parpadea antes de embestir
			velocity = Vector2.ZERO
			sprite.modulate = Color(1.0, 0.7, 0.2)
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_charge_dir = to_player.normalized()
				_phase = ChargePhase.CHARGE
				_phase_timer = charge_time
				sprite.modulate = Color.WHITE

		ChargePhase.CHARGE:
			# Embestida recta a gran velocidad
			velocity = _charge_dir * charge_speed
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_phase = ChargePhase.CHASE
				_cooldown = charge_interval
