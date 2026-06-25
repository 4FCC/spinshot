extends Enemy

# =============================================================================
# BIGMINION CAPITÁN — Variante de élite del Bigminión
# =============================================================================
# Comportamiento base de persecución, pero:
#   - Otorga un buff de daño y velocidad SOLO a los "bigminion" normales dentro
#     de su área de efecto (aura).
#   - Entra en FRENESÍ (buff de velocidad propio) si su vida baja del 25%.
#   - Opcionalmente (invocado por el minijefe) puede invocar UNA vez 4 Bigminión.

@export_group("Capitán")
@export var aura_radius: float = 280.0
@export var aura_buff_damage: int = 2
@export var aura_buff_speed: float = 1.4
@export var frenzy_threshold: float = 0.25
@export var frenzy_speed_mult: float = 1.6

@export_group("Invocación encadenada")
@export var can_summon_bigminions: bool = false   # solo los invocados por el minijefe
@export var bigminion_scene: PackedScene
@export var summon_count: int = 4
@export var summon_delay: float = 1.5

var _frenzy_mult: float = 1.0
var _frenzied: bool = false
var _summon_timer: float = -1.0
var _has_summoned: bool = false

func _ready() -> void:
	super._ready()
	add_to_group("bigminion_capitan")
	if can_summon_bigminions:
		_summon_timer = summon_delay

func get_speed() -> float:
	return move_speed * _buff_speed_mult * _frenzy_mult

func _update_ai(delta: float) -> void:
	super._update_ai(delta)   # persigue al jugador

	# Aura: potenciar a los Bigminión normales en rango (se refresca cada frame).
	for e in get_tree().get_nodes_in_group("bigminion"):
		if e == self or not is_instance_valid(e):
			continue
		if global_position.distance_to(e.global_position) <= aura_radius and e.has_method("apply_buff"):
			e.apply_buff(aura_buff_damage, aura_buff_speed, 0.3)

	# Frenesí propio al bajar del umbral de vida.
	if not _frenzied and float(health) / float(max_health) < frenzy_threshold:
		_frenzied = true
		_frenzy_mult = frenzy_speed_mult
		sprite.modulate = Color(1.0, 0.5, 0.4)

	# Invocación encadenada (una sola vez), si fue invocado por el minijefe.
	if _summon_timer > 0.0 and not _has_summoned:
		_summon_timer -= delta
		if _summon_timer <= 0.0:
			_summon_bigminions()

func _summon_bigminions() -> void:
	_has_summoned = true
	if bigminion_scene == null:
		return
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	for i in summon_count:
		var m = bigminion_scene.instantiate()
		host.add_child(m)
		m.global_position = global_position + Vector2.RIGHT.rotated(TAU * i / summon_count) * 90.0
