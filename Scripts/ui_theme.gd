class_name UiTheme
extends RefCounted

# =============================================================================
# UI THEME — Estilo común "madera/dorado" para toda la interfaz
# =============================================================================
# Funciones estáticas que aplican StyleBoxes y colores coherentes con el kit de
# UI medieval del proyecto. Centralizar aquí permite cambiar el look de toda la
# interfaz desde un único sitio.

const GOLD := Color(0.80, 0.64, 0.42)
const GOLD_DIM := Color(0.46, 0.37, 0.26)
const WOOD_DARK := Color(0.13, 0.09, 0.06, 0.97)
const WOOD := Color(0.30, 0.20, 0.12)
const WOOD_HOVER := Color(0.41, 0.28, 0.16)
const WOOD_PRESSED := Color(0.22, 0.15, 0.09)
const TEXT := Color(0.96, 0.91, 0.82)

static func _flat(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	return s

static func apply_panel(p: Control) -> void:
	var s := _flat(WOOD_DARK, GOLD, 3, 12)
	s.set_content_margin_all(10)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 8
	p.add_theme_stylebox_override("panel", s)

static func apply_button(b: Button) -> void:
	var n := _flat(WOOD, GOLD_DIM, 2, 7)
	n.set_content_margin_all(8)
	var h := _flat(WOOD_HOVER, GOLD, 2, 7)
	h.set_content_margin_all(8)
	var pr := _flat(WOOD_PRESSED, GOLD, 2, 7)
	pr.set_content_margin_all(8)
	var d := _flat(Color(0.15, 0.11, 0.08, 0.7), GOLD_DIM, 2, 7)
	d.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0), GOLD, 2, 7))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.55, 0.5))

static func apply_title(l: Label, size: int = 28) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)

static func apply_label(l: Label) -> void:
	l.add_theme_color_override("font_color", TEXT)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)

static func apply_slot(p: Control) -> void:
	var s := _flat(Color(0.10, 0.07, 0.05, 0.95), GOLD_DIM, 2, 8)
	p.add_theme_stylebox_override("panel", s)

static func apply_progress(pb: ProgressBar, fill: Color) -> void:
	pb.add_theme_stylebox_override("background", _flat(Color(0.07, 0.05, 0.04, 0.92), GOLD_DIM, 2, 6))
	pb.add_theme_stylebox_override("fill", _flat(fill, Color(0, 0, 0, 0), 0, 5))
