extends Node

# =============================================================================
# I18N — Sistema de localización (inglés por defecto + español)
# =============================================================================
# El texto FUENTE en el código está en inglés y actúa como clave de traducción.
# Aquí se registra la traducción al español y se expone el cambio de idioma.
#
# Uso:
#   - Textos estáticos: pon el texto en inglés en `text` del Control; Godot lo
#     auto-traduce al cambiar el idioma.
#   - Textos con formato: usa `tr("Coins: %d") % total` y refresca al recibir
#     la señal `language_changed`.

signal language_changed(locale: String)

const DEFAULT_LOCALE := "en"
const LOCALES := ["en", "es"]

# Mapa texto-en-inglés -> español. Las claves deben coincidir EXACTAMENTE con el
# texto fuente usado en el código.
const ES := {
	# --- HUD ---
	"Coins: %d": "Monedas: %d",
	"Wave: -": "Oleada: -",
	"Wave %d / %d": "Oleada %d / %d",
	"Time: %d s": "Tiempo: %d s",
	"Health: %d/%d": "Vida: %d/%d",
	"Dodge: READY": "Esquive: LISTO",
	"Dodge: %.1fs": "Esquive: %.1fs",
	# --- Info / avisos ---
	"Wave %d in progress": "Oleada %d en curso",
	"Wave %d in progress  —  N: end": "Oleada %d en curso  —  N: terminar",
	"DEV-ROOM:  M = next wave  ·  O = shop  ·  B = boss": "DEV-ROOM:  M = siguiente oleada  ·  O = tienda  ·  B = jefe",
	"DEV-ROOM:  M=wave N=end B=boss · 1-5 dummies · 6-9 variants/miniboss · O=shop C=+100 G=god": "DEV-ROOM:  M=oleada N=terminar B=jefe · 1-5 maniquíes · 6-9 variantes/minijefe · O=tienda C=+100 G=god",
	"Defeat the Gran Capitán!": "¡Derrota al Gran Capitán!",
	"Buy upgrades and get ready for the BOSS": "Compra mejoras y prepárate para el JEFE",
	"FINAL BOSS!": "¡JEFE FINAL!",
	"God mode: %s": "Modo dios: %s",
	"Press to start": "Pulsa para empezar",
	"Wave %d cleared!": "¡Oleada %d superada!",
	"\nThe boss approaches...": "\nEl jefe se aproxima...",
	# --- Pantallas ---
	"PLAY": "JUGAR",
	"VICTORY!": "¡VICTORIA!",
	"You cleared all the waves.": "Has superado todas las oleadas.",
	"Play again": "Jugar de nuevo",
	"YOU DIED": "HAS MUERTO",
	"You were defeated.": "Te han derrotado.",
	"Retry": "Reintentar",
	# --- Menú ESC ---
	"Controls": "Controles",
	"Language": "Idioma",
	"Resolution": "Resolución",
	"Sound": "Sonido",
	"Credits": "Créditos",
	"Exit": "Salida",
	"Back": "Volver",
	# --- Controles ---
	"CONTROLS": "CONTROLES",
	"WASD / Arrows: move\nSpace: dodge\nRight click: blue SpinShot\nLeft click: orange SpinShot\nE: inventory\nESC: options\nF11: fullscreen": "WASD / Flechas: mover\nEspacio: esquivar\nClic der.: SpinShot azul\nClic izq.: SpinShot naranja\nE: inventario\nESC: opciones\nF11: pantalla completa",
	# --- Resolución ---
	"RESOLUTION": "RESOLUCIÓN",
	"Fullscreen": "Pantalla completa",
	# --- Idioma ---
	"LANGUAGE": "IDIOMA",
	# --- Inventario ---
	"Inventory": "Inventario",
	"(You haven't bought any item yet)": "(Aún no has comprado ningún ítem)",
	"Qty/Level: %d": "Cantidad/Nivel: %d",
	# --- Tienda ---
	"SHOP": "TIENDA",
	"%d coins": "%d monedas",
	"ROLL": "ROLL",
	"ROLL (%d)": "ROLL (%d)",
	"CONTINUE": "CONTINUAR",
	# --- Estadísticas ---
	"Player": "Jugador",
	"Health": "Vida",
	"Speed": "Velocidad",
	"Bullet dmg": "Daño bala",
	"Fire rate": "Cadencia",
	"Dodge": "Esquive",
	"Steal": "Robo",
	"Bounce": "Rebote",
	"Split": "División",
	"Lethal": "Letal",
	"Evade": "Evasión",
	"Yes": "Sí",
	"Lv %d": "Nv %d",
	# --- Ítems de la tienda (nombre y descripción) ---
	"Wave": "Oleada",
	"Minor Health Potion": "Poción menor de vida",
	"Raises max health by 5 and heals that amount.": "Aumenta la vida máxima en 5 y cura esa cantidad.",
	"Greater Health Potion": "Poción mayor de vida",
	"Raises max health by 10 and heals that amount.": "Aumenta la vida máxima en 10 y cura esa cantidad.",
	"Apprentice Wand": "Varita de aprendiz",
	"+1 damage to each Spin-Bullet.": "+1 de daño a cada Spin-Bullet.",
	"Arcane Tome": "Tomo arcano",
	"+2 damage to each Spin-Bullet.": "+2 de daño a cada Spin-Bullet.",
	"Beach Sandals": "Chanclas de la paca",
	"+40 movement speed and reduces dodge cooldown.": "+40 de velocidad y reduce el enfriamiento del esquive.",
	"Quick Trigger": "Gatillo veloz",
	"Reduces time between shots by 15%; also +move speed and dodge distance.": "Reduce el tiempo entre disparos un 15%; además +velocidad y +distancia de esquive.",
	"Lifesteal": "Robo de vida",
	"Per level, 25% chance to heal 1-3 when collecting a coin. Max 3.": "25% por nivel de curar 1-3 al recoger una moneda. Máx 3.",
	"Offensive bounce": "Rebote ofensivo",
	"On hit, releases SpinShots that chain to OTHER enemies. Max 3.": "Al impactar, suelta SpinShots que rebotan en cadena hacia OTROS enemigos. Máx 3.",
	"Projectile split": "División de proyectil",
	"The SpinShot splits in two mid-path. Unique.": "La SpinShot se divide en dos a media trayectoria. Única.",
	"Lethal spin": "Giro letal",
	"+1% per purchase to kill the enemy by spinning. No limit.": "+1% por compra de matar al enemigo girando. Sin límite.",
	"Auto-dodge": "Esquiva automática",
	"Per level, 25% chance to dodge when hit. Max 3.": "25% por nivel de esquivar al recibir daño. Máx 3.",
	# --- Cascos ---
	"Minion Helmet": "Casco de minion",
	"-1 max health, +2 damage; longer dodge and shorter dodge cooldown.": "-1 vida máx., +2 daño; esquive más largo y menor enfriamiento de esquive.",
	"Knight Helmet": "Casco de caballero",
	"+5 max health, +3 damage; -20 speed and longer dodge cooldown.": "+5 vida máx., +3 daño; -20 velocidad y mayor enfriamiento de esquive.",
	"Viking Helmet": "Casco vikingo",
	"-3 health, +5 damage; +10% chance to knock back touching enemies (max 50%). Past the cap: +1 health, +3 damage.": "-3 vida, +5 daño; +10% de empujar a los enemigos que te tocan (máx 50%). Pasado el tope: +1 vida, +3 daño.",
	"Captain Helmet": "Casco de capitán",
	"+10 max health, +5 damage; frenzy (speed + damage) when below 50% health. Unlocked by defeating a Bigminion Capitán.": "+10 vida máx., +5 daño; frenesí (velocidad + daño) por debajo del 50% de vida. Se desbloquea al derrotar a un Bigminion Capitán.",
	"Grand Captain Helmet": "Casco de gran capitán",
	"+15 max health, +10 damage; summons 4 allied Capitanes. Unlocked by defeating the Gran Capitán.": "+15 vida máx., +10 daño; invoca 4 Capitanes aliados. Se desbloquea al derrotar al Gran Capitán.",
}

func _ready() -> void:
	var t := Translation.new()
	t.locale = "es"
	for k in ES:
		t.add_message(k, ES[k])
	TranslationServer.add_translation(t)
	# Idioma por defecto: inglés.
	TranslationServer.set_locale(DEFAULT_LOCALE)

func set_language(locale: String) -> void:
	if not LOCALES.has(locale):
		return
	TranslationServer.set_locale(locale)
	language_changed.emit(locale)

func current() -> String:
	return TranslationServer.get_locale()

# Traducción utilizable desde cualquier contexto (incluido RefCounted).
func t(key: String) -> String:
	return TranslationServer.translate(key)
