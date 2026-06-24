class_name StatsPanel
extends RefCounted

# =============================================================================
# STATS PANEL — Cuadro de estadísticas usando el sprite UI_stat (400x400)
# =============================================================================
# Devuelve un Control de 400x400 con el fondo UI_stat, el título en su hueco
# superior y las estadísticas del jugador en el panel interior. El que lo use
# puede escalarlo/posicionarlo.

const UI_STAT_TEX := preload("res://UI assets/UI_stat.png")

static func build(player) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(400, 400)
	root.size = Vector2(400, 400)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = UI_STAT_TEX
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# Título en el hueco superior del sprite
	var title := Label.new()
	title.position = Vector2(140, 58)
	title.size = Vector2(120, 40)
	title.text = "STATS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.25, 0.16, 0.08))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)

	# Lista de estadísticas en el panel interior
	var vb := VBoxContainer.new()
	vb.position = Vector2(86, 124)
	vb.size = Vector2(228, 200)
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vb)

	if player == null or not is_instance_valid(player):
		_row(vb, "Player", "—")
		return root

	_row(vb, "Health", "%d / %d" % [player.vida, player.vida_max])
	_row(vb, "Speed", "%d" % roundi(player.speed))
	_row(vb, "Bullet dmg", "%d" % player.bullet_damage)
	_row(vb, "Fire rate", "%.2fs" % player.shoot_cooldown_time)
	_row(vb, "Dodge", "%.2fs" % player.dodge_cooldown_time)
	if player.coin_heal_level > 0:
		_row(vb, "Steal", TranslationServer.translate("Lv %d") % player.coin_heal_level)
	if player.bounce_level > 0:
		_row(vb, "Bounce", "+%d" % player.bounce_level)
	if player.has_split:
		_row(vb, "Split", TranslationServer.translate("Yes"))
	if player.lethal_level > 0:
		_row(vb, "Lethal", "%d%%" % player.lethal_level)
	if player.autododge_level > 0:
		_row(vb, "Evade", "%d%%" % (player.autododge_level * 25))

	return root

static func _row(vb: VBoxContainer, name: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var l := Label.new()
	l.text = name
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.22, 0.14, 0.07))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)

	var v := Label.new()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)

	vb.add_child(row)
