extends Enemy

# =============================================================================
# BIGMINION CAPITÁN — Variante de élite del Bigminión
# =============================================================================
# Modo ENEMIGO (por defecto):
#   - Persigue al jugador y le hace daño por contacto.
#   - Aura: potencia (daño + velocidad) SOLO a los "bigminion" normales en rango.
#   - FRENESÍ (+velocidad propio) si su vida baja del 25%.
#   - Si lo invoca el minijefe, puede invocar UNA vez 4 Bigminión.
# Modo ALIADO (is_ally, invocado por el casco de gran capitán):
#   - Persigue y golpea a los ENEMIGOS, no al jugador. Tinte azul.
#   - Sin aura sobre enemigos y sin invocación.

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

var is_ally: bool = false   # invocado por el jugador (casco de gran capitán)

var _frenzy_mult: float = 1.0
var _frenzied: bool = false
var _summon_timer: float = -1.0
var _has_summoned: bool = false

func _ready() -> void:
	super._ready()
	if is_ally:
		# Aliado del jugador: no es enemigo, no recibe disparos del jugador.
		remove_from_group("enemy")
		add_to_group("ally")
		collision_layer = 0     # el jugador y los enemigos lo atraviesan
		can_summon_bigminions = false
		sprite.modulate = _base_modulate()
	else:
		add_to_group("bigminion_capitan")
		if can_summon_bigminions:
			_summon_timer = summon_delay

func get_speed() -> float:
	return move_speed * _buff_speed_mult * _frenzy_mult

func _base_modulate() -> Color:
	if is_ally:
		return Color(0.45, 0.7, 1.0)   # azul: aliado
	return super._base_modulate()

func _update_ai(delta: float) -> void:
	if is_ally:
		_ally_ai(delta)
		return

	super._update_ai(delta)   # persigue al jugador

	# Aura: potenciar a los Bigminión normales en rango (se refresca cada frame).
	var buffed_any := false
	for e in get_tree().get_nodes_in_group("bigminion"):
		if e == self or not is_instance_valid(e):
			continue
		if global_position.distance_to(e.global_position) <= aura_radius and e.has_method("apply_buff"):
			e.apply_buff(aura_buff_damage, aura_buff_speed, 0.3)
			buffed_any = true
	# Sonido de buff: UNA vez por instancia/grupo (debounce global), aunque se
	# potencien muchos a la vez, para no saturar. (El Apoyo tiene su propio sonido.)
	if buffed_any:
		Audio.play_at("buff", global_position, 0.05, 700)

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

# --- Modo aliado ---
func _ally_ai(_delta: float) -> void:
	var target := _nearest_enemy()
	if target == null:
		# Sin enemigos: quedarse cerca del jugador.
		if player != null and global_position.distance_to(player.global_position) > 120.0:
			velocity = (player.global_position - global_position).normalized() * get_speed()
		else:
			velocity = Vector2.ZERO
		return
	var to := target.global_position - global_position
	if to.length() > 40.0:
		velocity = to.normalized() * get_speed()
	else:
		velocity = Vector2.ZERO
	# Golpe por contacto a los enemigos cercanos.
	if _attack_timer <= 0.0 and to.length() <= 60.0 and target.has_method("take_damage"):
		target.take_damage(contact_damage)
		_attack_timer = attack_cooldown

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _try_melee() -> void:
	if is_ally:
		return   # el aliado ataca a enemigos en _ally_ai, no al jugador
	super._try_melee()

func _summon_bigminions() -> void:
	_has_summoned = true
	if bigminion_scene == null:
		return
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	for i in summon_count:
		var pos: Vector2 = global_position + Vector2.RIGHT.rotated(TAU * i / summon_count) * 90.0
		# Indicador rojo antes de la invocación.
		Game.telegraph_spawn(host, pos, Game.INDICATOR_ENEMY, 2.0, 0.7, func():
			var m = bigminion_scene.instantiate()
			host.add_child(m)
			m.global_position = pos)

func _die() -> void:
	# Matar a un capitán ENEMIGO desbloquea su casco (persistente).
	if not is_ally:
		Game.unlock("capitan_helmet")
	super._die()
