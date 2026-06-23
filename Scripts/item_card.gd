extends Control

# =============================================================================
# ITEM CARD — Tarjeta de un ítem de la tienda (usa el sprite Card_UI_Items)
# =============================================================================
# Solo rellena los huecos del sprite con la info del ítem: imagen, nombre,
# descripción, costo y estadísticas (daño/vida). El clic en cualquier parte de
# la tarjeta intenta comprar (BuyButton transparente que cubre la tarjeta).

signal buy_pressed(index: int)

var index: int = 0

@onready var item_sprite: TextureRect = $ItemSprite
@onready var name_label: Label = $NameLabel
@onready var desc_label: Label = $DescLabel
@onready var cost_label: Label = $CostLabel
@onready var dmg_label: Label = $DmgLabel
@onready var life_label: Label = $LifeLabel
@onready var buy_button: Button = $BuyButton

func _ready() -> void:
	# Botón invisible que cubre la tarjeta (el dibujo lo pone el sprite)
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		buy_button.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	buy_button.pressed.connect(_on_pressed)

func _on_pressed() -> void:
	buy_pressed.emit(index)

func setup(item: Dictionary, idx: int, affordable: bool) -> void:
	index = idx
	name_label.text = String(item.get("name", ""))
	desc_label.text = String(item.get("desc", ""))
	cost_label.text = str(int(item.get("cost", 0)))
	item_sprite.texture = item.get("icon", null)

	var dmg := int(item.get("dmg", 0))
	var life := int(item.get("life", 0))
	dmg_label.text = ("+%d" % dmg) if dmg > 0 else ""
	life_label.text = ("+%d" % life) if life > 0 else ""

	buy_button.disabled = not affordable
	modulate = Color.WHITE if affordable else Color(0.6, 0.6, 0.6, 1.0)
