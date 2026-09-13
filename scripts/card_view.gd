class_name UnoCardView
extends Button

const CARD_BACK := preload("res://assets/art/mythic_dragon_card_back.png")

var card_data: Dictionary = {}
var card_index := -1
var face_up := true
var playable := true
var compact := false


func configure(data: Dictionary, index: int = -1, is_face_up: bool = true, can_play: bool = true, is_compact: bool = false) -> void:
	card_data = data
	card_index = index
	face_up = is_face_up
	playable = can_play
	compact = is_compact
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_play and is_face_up else Control.CURSOR_ARROW
	custom_minimum_size = Vector2(70, 105) if compact else Vector2(104, 156)
	disabled = not can_play
	tooltip_text = _card_name() if face_up else "Chinese mythology card back"
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if not face_up:
		draw_texture_rect(CARD_BACK, rect.grow(-3.0), false)
		var back_border := StyleBoxFlat.new()
		back_border.bg_color = Color.TRANSPARENT
		back_border.border_color = Color("e8c46b")
		back_border.set_border_width_all(3)
		back_border.set_corner_radius_all(10)
		draw_style_box(back_border, rect)
		return

	var color := _display_color()
	var card_box := StyleBoxFlat.new()
	card_box.bg_color = Color("f6edda")
	card_box.border_color = Color("f4d27d") if playable else Color("766f68")
	card_box.set_border_width_all(4 if playable else 2)
	card_box.set_corner_radius_all(12)
	card_box.shadow_color = Color(0, 0, 0, 0.45)
	card_box.shadow_size = 7
	card_box.shadow_offset = Vector2(0, 4)
	draw_style_box(card_box, rect.grow(-4.0))

	var inset := rect.grow(-10.0)
	var field := StyleBoxFlat.new()
	field.bg_color = color
	field.set_corner_radius_all(9)
	draw_style_box(field, inset)

	# Pale central medallion keeps values legible while the corners retain color identity.
	var center := rect.get_center()
	draw_circle(center, min(size.x, size.y) * 0.32, Color(0.98, 0.91, 0.75, 0.96))
	draw_circle(center, min(size.x, size.y) * 0.285, Color(0.11, 0.08, 0.06, 0.92), false, 2.0)

	var font := ThemeDB.fallback_font
	var symbol := _symbol()
	var main_size := 42 if not compact else 30
	var symbol_width := font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, main_size).x
	draw_string(font, Vector2(center.x - symbol_width / 2.0, center.y + main_size * 0.35), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, main_size, Color("211713"))

	var corner_size := 18 if not compact else 14
	draw_string(font, Vector2(15, 28), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, corner_size, Color.WHITE)
	var color_name := str(card_data.get("color", "")).capitalize()
	if card_data.get("color", "") == "wild":
		color_name = "WILD"
	draw_string(font, Vector2(0, size.y - 12), color_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11 if not compact else 9, Color.WHITE)

	if not playable:
		draw_rect(rect.grow(-4.0), Color(0.08, 0.06, 0.05, 0.45), true)


func _display_color() -> Color:
	match card_data.get("color", "wild"):
		"red": return Color("b93632")
		"yellow": return Color("d99d28")
		"green": return Color("258565")
		"blue": return Color("27699c")
		_: return Color("282328")


func _symbol() -> String:
	match card_data.get("kind", ""):
		"skip": return "⊘"
		"reverse": return "↻"
		"draw_two": return "+2"
		"wild": return "✦"
		"wild_draw_four": return "+4"
		_: return str(card_data.get("value", 0))


func _card_name() -> String:
	var kind: String = card_data.get("kind", "number")
	if kind == "number":
		return "%s %s" % [str(card_data.get("color", "")).capitalize(), card_data.get("value", 0)]
	return "%s %s" % [str(card_data.get("color", "")).capitalize(), kind.replace("_", " ").capitalize()]
