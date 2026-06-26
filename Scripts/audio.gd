extends Node

# =============================================================================
# AUDIO — Gestor global de sonido (autoload)
# =============================================================================
# Centraliza TODOS los efectos de sonido (SFX) y los ajustes de volumen de
# música y SFX. Objetivos:
#   - Sonido limpio y satisfactorio sin saturar cuando pasan muchas cosas.
#   - No crear un AudioStreamPlayer por evento: se reutiliza un POOL fijo.
#   - Anti-saturación por clave (debounce) + variación de tono (pitch).
#   - Buses dedicados ("Music" y "SFX") controlables desde el menú Sonido.
#
# La música la reproducen los AudioStreamPlayer del GameMode en el bus "Music";
# aquí solo controlamos su volumen/silencio por bus. Los SFX salen del pool de
# este autoload, enrutado al bus "SFX".

# --- Catálogo de efectos (texto fuente = ruta del .wav/.mp3) ---
const SFX := {
	# UI / tienda
	"ui_click": preload("res://sound effect/Sonido de click de UI/UIClick_INTERFACE-Rattling Click_HY_PC-001.wav"),
	"buy": preload("res://sound effect/Sonido de compra/freesound_community-flipcard-91468.mp3"),
	"denied": preload("res://sound effect/Efecto de sonido de interfazbloqueada/UIMisc_INTERFACE-Denied_HY_PC-001.wav"),
	"reroll": preload("res://sound effect/Sonido de boton roll/ElevenLabs_Lanzar_dados_en_un_juego_de_mesa,_ambiente_inmersivo.mp3"),
	# Jugador / disparos / ítems
	"shoot": preload("res://sound effect/Disparo del jugador/DSGNTonl_SKILL IMPACT-Swoosh Grain_HY_PC-002.wav"),
	"hit": preload("res://sound effect/Sonido de golpe a enemigo/FGHTImpt_MELEE-Swish Hit_HY_PC-004.wav"),
	"coin": preload("res://sound effect/Sonidos de monedas/DSGNTonl_USABLE-Coin Toss_HY_PC-006.wav"),
	"dodge": preload("res://sound effect/Efecto de sonido de esquive/DSGNMisc_MELEE-Sword Reflect_HY_PC-001.wav"),
	"lethal": preload("res://sound effect/Efecto de muerte instantanea/DSGNSynth_BUFF-Invigoration_HY_PC-006.wav"),
	# Enemigos / jefes
	"teleport_enemy": preload("res://sound effect/Sonido de Teletransportación/MAGSpel_CAST-Casting Buff_HY_PC-002.wav"),
	"teleport_boss": preload("res://sound effect/Sonido de Teletransportación/MAGSpel_CAST-Casting Buff_HY_PC-001.wav"),
	"sad_eat": preload("res://sound effect/Sonido de slime Azul al desaparecer proyectiles/DSGNTonl_USABLE-Tonal Item_HY_PC-003.wav"),
	"charge_push": preload("res://sound effect/Sonido de golpe o empuje/DSGNImpt_MELEE-Hollow Punch_HY_PC-005.wav"),
	"support": preload("res://sound effect/Efecto de sonido de support/DSGNTonl_USABLE-Magic Item_HY_PC-001.wav"),
	"buff": preload("res://sound effect/Sonido De buff/DSGNSynth_BUFF-Bonus Crit Chance_HY_PC-001.wav"),
}

const SETTINGS_PATH := "user://spinshot_audio.cfg"
const POOL_SIZE := 16

# Desfase de inicio por clave (segundos): salta el silencio/intro de algunos
# clips para que el sonido se oiga DE INMEDIATO al dispararlo. El SFX de "reroll"
# es un clip de dados con un pequeño lead-in; si aún se nota tarde, sube este
# valor (o recorta el archivo en Audacity/ffmpeg).
const START_OFFSET := {
	"reroll": 0.2,
}

# --- Ajustes (persistentes) ---
var music_enabled: bool = true
var sfx_enabled: bool = true
var music_volume: float = 0.8   # lineal 0..1
var sfx_volume: float = 0.9     # lineal 0..1

const POOL2D_SIZE := 12
const DEFAULT_MAX_DISTANCE := 1300.0   # px: más allá, el sonido se desvanece

var _pool: Array[AudioStreamPlayer] = []          # SFX no posicionales (UI, jugador…)
var _pool2d: Array[AudioStreamPlayer2D] = []      # SFX posicionales (enemigos)
var _next: int = 0
var _next2d: int = 0
var _last_ms: Dictionary = {}   # clave -> último Time.get_ticks_msec() (debounce)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # el sonido sigue con el árbol en pausa
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	# Pool POSICIONAL: el volumen/paneo depende de la distancia a la cámara del
	# jugador (que actúa como oyente). Para sonidos de enemigos/jefes.
	for i in POOL2D_SIZE:
		var p2 := AudioStreamPlayer2D.new()
		p2.bus = "SFX"
		p2.max_distance = DEFAULT_MAX_DISTANCE
		p2.attenuation = 1.5
		add_child(p2)
		_pool2d.append(p2)
	_load_settings()
	_apply_bus(_music_bus(), music_enabled, music_volume)
	_apply_bus(_sfx_bus(), sfx_enabled, sfx_volume)

# =============================================================================
# REPRODUCCIÓN DE SFX
# =============================================================================
func play(key: String, pitch_var: float = 0.0, min_interval_ms: int = 0, volume_db: float = 0.0) -> void:
	"""Reproduce el SFX 'key' del pool.
	- pitch_var: variación aleatoria de tono (±) para que no suene mecánico.
	- min_interval_ms: anti-saturación. Si el MISMO efecto sonó hace menos de ese
	  tiempo, se omite (evita 20 sonidos idénticos a la vez)."""
	if not sfx_enabled:
		return
	var stream: AudioStream = SFX.get(key, null)
	if stream == null:
		return
	if min_interval_ms > 0:
		var now := Time.get_ticks_msec()
		var last: int = _last_ms.get(key, -1000000)
		if now - last < min_interval_ms:
			return
		_last_ms[key] = now
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = 1.0 + (randf() * 2.0 - 1.0) * pitch_var if pitch_var > 0.0 else 1.0
	p.volume_db = volume_db
	p.play(START_OFFSET.get(key, 0.0))

func play_at(key: String, world_pos: Vector2, pitch_var: float = 0.0, min_interval_ms: int = 0, volume_db: float = 0.0, max_distance: float = DEFAULT_MAX_DISTANCE) -> void:
	"""Como play(), pero ESPACIAL: el sonido se atenúa/panea según la distancia de
	'world_pos' a la cámara del jugador (oyente). Para enemigos/jefes."""
	if not sfx_enabled:
		return
	var stream: AudioStream = SFX.get(key, null)
	if stream == null:
		return
	if min_interval_ms > 0:
		var now := Time.get_ticks_msec()
		var last: int = _last_ms.get(key, -1000000)
		if now - last < min_interval_ms:
			return
		_last_ms[key] = now
	var p := _pool2d[_next2d]
	_next2d = (_next2d + 1) % POOL2D_SIZE
	p.stream = stream
	p.pitch_scale = 1.0 + (randf() * 2.0 - 1.0) * pitch_var if pitch_var > 0.0 else 1.0
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.global_position = world_pos
	p.play(START_OFFSET.get(key, 0.0))

# =============================================================================
# AJUSTES DE VOLUMEN / SILENCIO (menú Sonido)
# =============================================================================
func set_music_enabled(on: bool) -> void:
	music_enabled = on
	_apply_bus(_music_bus(), music_enabled, music_volume)
	_save_settings()

func set_sfx_enabled(on: bool) -> void:
	sfx_enabled = on
	_apply_bus(_sfx_bus(), sfx_enabled, sfx_volume)
	_save_settings()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus(_music_bus(), music_enabled, music_volume)
	_save_settings()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus(_sfx_bus(), sfx_enabled, sfx_volume)
	_save_settings()

func _apply_bus(idx: int, enabled: bool, vol: float) -> void:
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, not enabled)
	# linear_to_db(0) = -inf; usamos un mínimo audible para evitar -inf.
	var db := linear_to_db(vol) if vol > 0.001 else -80.0
	AudioServer.set_bus_volume_db(idx, db)

func _music_bus() -> int:
	return AudioServer.get_bus_index("Music")

func _sfx_bus() -> int:
	return AudioServer.get_bus_index("SFX")

# =============================================================================
# PERSISTENCIA
# =============================================================================
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_enabled = bool(cfg.get_value("audio", "music_enabled", music_enabled))
	sfx_enabled = bool(cfg.get_value("audio", "sfx_enabled", sfx_enabled))
	music_volume = float(cfg.get_value("audio", "music_volume", music_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", sfx_volume))

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_enabled", music_enabled)
	cfg.set_value("audio", "sfx_enabled", sfx_enabled)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.save(SETTINGS_PATH)
