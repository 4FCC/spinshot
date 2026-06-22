class_name StatsPanel
extends RefCounted

# =============================================================================
# STATS PANEL — Cuadro reutilizable con las estadísticas actuales del jugador
# =============================================================================
# Se usa en la tienda y en el menú de ESC (junto al inventario). Lee los
# valores directamente del jugador (billy.gd).

static func build(player) -> Control:
	var panel := PanelContainer.new()
	UiTheme.apply_panel(panel)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(pad)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pad.add_child(vb)

	var title := Label.new()
	title.text = "ESTADÍSTICAS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_title(title, 22)
	vb.add_child(title)

	if player == null or not is_instance_valid(player):
		_row(vb, "Jugador", "—")
		return panel

	_row(vb, "Vida", "%d / %d" % [player.vida, player.vida_max])
	_row(vb, "Velocidad", "%d" % roundi(player.speed))
	_row(vb, "Daño de bala", "%d" % player.bullet_damage)
	_row(vb, "Cadencia", "%.2f s" % player.shoot_cooldown_time)
	_row(vb, "Esquive (CD)", "%.2f s" % player.dodge_cooldown_time)

	# Ítems con habilidad (solo si el jugador los tiene)
	var has_special := false
	if player.coin_heal_level > 0:
		_row(vb, "Robo de vida", "Nv %d (%d%%)" % [player.coin_heal_level, player.coin_heal_level * 25])
		has_special = true
	if player.bounce_level > 0:
		_row(vb, "Rebote ofensivo", "+%d SpinShot" % player.bounce_level)
		has_special = true
	if player.has_split:
		_row(vb, "División de proyectil", "Sí")
		has_special = true
	if player.lethal_level > 0:
		_row(vb, "Giro letal", "%d%%" % player.lethal_level)
		has_special = true
	if player.autododge_level > 0:
		_row(vb, "Esquiva automática", "%d%%" % (player.autododge_level * 25))
		has_special = true
	if not has_special:
		var none := Label.new()
		none.text = "(Sin habilidades especiales)"
		UiTheme.apply_label(none)
		vb.add_child(none)

	return panel

static func _row(vb: VBoxContainer, name: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var l := Label.new()
	l.text = name
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.apply_label(l)
	row.add_child(l)

	var v := Label.new()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiTheme.apply_label(v)
	v.add_theme_color_override("font_color", UiTheme.GOLD)
	row.add_child(v)

	vb.add_child(row)
