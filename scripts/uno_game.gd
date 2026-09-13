@tool
extends Control

const CardView := preload("res://scripts/card_view.gd")
const COLORS := ["red", "yellow", "green", "blue"]
const COLOR_HEX := {
	"red": Color("b93632"),
	"yellow": Color("d99d28"),
	"green": Color("258565"),
	"blue": Color("27699c")
}
const AVATAR_ATLASES := [
	preload("res://assets/art/avatars/heroes.png"),
	preload("res://assets/art/avatars/celestials.png"),
	preload("res://assets/art/avatars/beasts.png"),
	preload("res://assets/art/avatars/spirits.png"),
	preload("res://assets/art/avatars/guardians.png"),
]
const AVATAR_NAMES := [
	"Sun Wukong", "Chang'e", "Nezha", "Erlang Shen", "Mulan", "Hou Yi",
	"Guanyin", "Jade Emperor", "Xi Wangmu", "Dragon King", "Jiutian Xuannü", "Caishen",
	"Azure Dragon", "Vermilion Bird", "White Tiger", "Black Tortoise", "Nine-Tailed Fox", "Qilin",
	"Moon Rabbit", "Guardian Lion", "Lotus Fairy", "Mountain Sage", "Thunder Youth", "River Spirit",
	"Crane Immortal", "Panda Master", "Moon Wolf", "Golden Carp", "Jade General", "Opera Guardian",
]

var player_count := 4
var score_target := 500
var players: Array = []
var scores: Array[int] = []
var deck: Array[Dictionary] = []
var discard: Array[Dictionary] = []
var current_player := 0
var direction := 1
var current_color := "red"
var round_active := false
var input_locked := true
var drawn_card_index := -1
var pending_wild_card: Dictionary = {}
var pending_wild_illegal := false
var pending_wild_player := -1
var pending_previous_color := "red"
var uno_declared := false
var awaiting_uno := false
var game_speed := 0.65
var sound_enabled := true
var selected_avatar := 0
var player_avatar_indices: Array[int] = []
var direction_flash_active := false
var round_number := 0
var game_log_entries: Array[Dictionary] = []
var log_sequence := 0
var log_previous_locked := true
var log_ai_remaining := 0.0
var log_uno_remaining := 0.0

var title_label: Label
var score_label: Label
var turn_label: Label
var status_label: Label
var color_chip: ColorRect
var turn_avatar: TextureRect
var action_label: Label
var turn_banner: PanelContainer
var direction_label: Label
var neighbors_label: Label
var route_label: Label
var order_panel: PanelContainer
var opponents_row: HBoxContainer
var hand_row: HBoxContainer
var draw_slot: VBoxContainer
var discard_slot: VBoxContainer
var uno_button: Button
var draw_button: Button
var pass_button: Button
var setup_overlay: Control
var setup_players: OptionButton
var setup_score: SpinBox
var avatar_grid: GridContainer
var avatar_name_label: Label
var modal_overlay: Control
var modal_title: Label
var modal_body: Label
var modal_actions: HBoxContainer
var log_overlay: Control
var log_text: RichTextLabel
var uno_timer: Timer
var ai_timer: Timer
var pace_select: OptionButton
var sound_button: Button
var sfx_player: AudioStreamPlayer
var sfx_cache: Dictionary = {}
var hand_caption: Label
var player_avatar_view: TextureRect


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	randomize()
	set_process_unhandled_input(true)
	_build_interface()
	_show_setup()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("111b1d"))
	var center := size * 0.5
	for i in range(8):
		var radius := 110.0 + i * 52.0
		draw_arc(center, radius, 0.0, TAU, 96, Color(0.20, 0.43, 0.35, 0.09), 2.0)
	for x in range(0, int(size.x) + 160, 160):
		draw_circle(Vector2(x, 74), 52, Color(0.71, 0.17, 0.13, 0.055))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _build_interface() -> void:
	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 28)
	root_margin.add_theme_constant_override("margin_right", 28)
	root_margin.add_theme_constant_override("margin_top", 22)
	root_margin.add_theme_constant_override("margin_bottom", 22)
	add_child(root_margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	root_margin.add_child(main)

	var header := HBoxContainer.new()
	main.add_child(header)
	title_label = _label("MYTHIC UNO", 30, Color("f1cd75"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	score_label = _label("", 16, Color("d9d4c5"))
	header.add_child(score_label)
	pace_select = OptionButton.new()
	pace_select.tooltip_text = "Adjust animation and AI turn speed"
	pace_select.add_item("Relaxed", 0)
	pace_select.add_item("Normal", 1)
	pace_select.add_item("Swift", 2)
	pace_select.select(0)
	pace_select.custom_minimum_size = Vector2(100, 40)
	pace_select.item_selected.connect(_on_pace_selected)
	header.add_child(pace_select)
	sound_button = _button("Sound: On", _toggle_sound)
	sound_button.custom_minimum_size.x = 100
	header.add_child(sound_button)
	var log_button := _button("Game Log", _show_game_log)
	log_button.custom_minimum_size.x = 92
	header.add_child(log_button)
	var rules_button := _button("Rules", _show_rules)
	header.add_child(rules_button)
	var menu_button := _button("New Match", _show_setup)
	header.add_child(menu_button)

	var gold_rule := ColorRect.new()
	gold_rule.color = Color("8f6b2d")
	gold_rule.custom_minimum_size.y = 2
	main.add_child(gold_rule)

	opponents_row = HBoxContainer.new()
	opponents_row.alignment = BoxContainer.ALIGNMENT_CENTER
	opponents_row.add_theme_constant_override("separation", 22)
	opponents_row.custom_minimum_size.y = 150
	main.add_child(opponents_row)

	var center_area := HBoxContainer.new()
	center_area.alignment = BoxContainer.ALIGNMENT_CENTER
	center_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_area.add_theme_constant_override("separation", 34)
	main.add_child(center_area)

	draw_slot = VBoxContainer.new()
	draw_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	center_area.add_child(draw_slot)

	var info := VBoxContainer.new()
	info.custom_minimum_size.x = 470
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	center_area.add_child(info)
	turn_label = _label("", 24, Color("f1cd75"))
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(turn_label)
	turn_banner = PanelContainer.new()
	turn_banner.custom_minimum_size = Vector2(300, 58)
	turn_banner.add_theme_stylebox_override("panel", _turn_banner_style(false))
	info.add_child(turn_banner)
	var banner_row := HBoxContainer.new()
	banner_row.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_row.add_theme_constant_override("separation", 10)
	turn_banner.add_child(banner_row)
	turn_avatar = _avatar_view(0, 44)
	banner_row.add_child(turn_avatar)
	action_label = _label("WAITING TO BEGIN", 16, Color("f1cd75"))
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_row.add_child(action_label)
	order_panel = PanelContainer.new()
	order_panel.add_theme_stylebox_override("panel", _order_panel_style(false))
	info.add_child(order_panel)
	var order_box := VBoxContainer.new()
	order_box.add_theme_constant_override("separation", 2)
	order_panel.add_child(order_box)
	direction_label = _label("", 15, Color("f1cd75"))
	direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	order_box.add_child(direction_label)
	neighbors_label = _label("", 13, Color("e4ddca"))
	neighbors_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	order_box.add_child(neighbors_label)
	route_label = _label("", 11, Color("9eaa9f"))
	route_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	route_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	order_box.add_child(route_label)
	var current_row := HBoxContainer.new()
	current_row.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(current_row)
	current_row.add_child(_label("Current color", 14, Color("b9b7ad")))
	color_chip = ColorRect.new()
	color_chip.custom_minimum_size = Vector2(42, 18)
	current_row.add_child(color_chip)
	status_label = _label("Choose New Match to begin", 16, Color("e8e2d1"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 48
	info.add_child(status_label)

	discard_slot = VBoxContainer.new()
	discard_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	center_area.add_child(discard_slot)

	var hand_identity := HBoxContainer.new()
	hand_identity.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_identity.add_theme_constant_override("separation", 8)
	main.add_child(hand_identity)
	player_avatar_view = _avatar_view(0, 34)
	player_avatar_view.visible = false
	hand_identity.add_child(player_avatar_view)
	hand_caption = _label("YOUR HAND", 13, Color("b8a270"))
	hand_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hand_identity.add_child(hand_caption)
	var hand_scroll := ScrollContainer.new()
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.custom_minimum_size.y = 176
	main.add_child(hand_scroll)
	hand_row = HBoxContainer.new()
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_row.add_theme_constant_override("separation", 8)
	hand_scroll.add_child(hand_row)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 12)
	main.add_child(controls)
	draw_button = _button("抓一张牌  DRAW", _on_draw_pressed, true)
	draw_button.custom_minimum_size = Vector2(190, 46)
	draw_button.tooltip_text = "从牌堆抓一张牌"
	controls.add_child(draw_button)
	uno_button = _button("CALL UNO!", _on_uno_pressed, true)
	uno_button.disabled = true
	controls.add_child(uno_button)
	pass_button = _button("Keep Card / Pass", _on_pass_pressed)
	pass_button.visible = false
	controls.add_child(pass_button)

	uno_timer = Timer.new()
	uno_timer.one_shot = true
	uno_timer.wait_time = 2.2
	uno_timer.timeout.connect(_on_uno_timeout)
	add_child(uno_timer)
	ai_timer = Timer.new()
	ai_timer.one_shot = true
	ai_timer.wait_time = 0.75
	ai_timer.timeout.connect(_take_ai_turn)
	add_child(ai_timer)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.volume_db = -7.0
	add_child(sfx_player)

	setup_overlay = _make_overlay()
	add_child(setup_overlay)
	_build_setup_panel()
	modal_overlay = _make_overlay()
	add_child(modal_overlay)
	_build_modal_panel()
	modal_overlay.visible = false
	log_overlay = _make_overlay()
	add_child(log_overlay)
	_build_log_panel()
	log_overlay.visible = false


func _build_setup_panel() -> void:
	var panel := _panel_container(Vector2(960, 720))
	setup_overlay.get_child(0).add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	var heading := _label("Enter the Dragon's Table", 30, Color("f1cd75"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var intro := _label("Choose your champion, then outplay the immortals in a classic 108-card match.", 15, Color("d9d4c5"))
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	var avatar_title := _label("Choose your avatar", 14, Color("b8a270"))
	avatar_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(avatar_title)
	avatar_name_label = _label(AVATAR_NAMES[selected_avatar], 16, Color("f1cd75"))
	avatar_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(avatar_name_label)
	avatar_grid = GridContainer.new()
	avatar_grid.columns = 10
	avatar_grid.add_theme_constant_override("h_separation", 7)
	avatar_grid.add_theme_constant_override("v_separation", 7)
	avatar_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(avatar_grid)
	_rebuild_avatar_grid()
	box.add_child(_label("Players", 14, Color("b8a270")))
	setup_players = OptionButton.new()
	for count in range(2, 5):
		setup_players.add_item("%d players (you + %d AI)" % [count, count - 1], count)
	setup_players.select(2)
	_style_input(setup_players)
	box.add_child(setup_players)
	box.add_child(_label("Winning score", 14, Color("b8a270")))
	setup_score = SpinBox.new()
	setup_score.min_value = 100
	setup_score.max_value = 1000
	setup_score.step = 50
	setup_score.value = 500
	_style_input(setup_score)
	box.add_child(setup_score)
	var start := _button("BEGIN MATCH", _start_match, true)
	start.custom_minimum_size.y = 54
	box.add_child(start)
	var note := _label("Classic rules • No stacking • Wild Draw Four challenges", 12, Color("918a7b"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)


func _build_modal_panel() -> void:
	var panel := _panel_container(Vector2(500, 300))
	modal_overlay.get_child(0).add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	modal_title = _label("", 26, Color("f1cd75"))
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(modal_title)
	modal_body = _label("", 16, Color("e1dccd"))
	modal_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(modal_body)
	modal_actions = HBoxContainer.new()
	modal_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_actions.add_theme_constant_override("separation", 12)
	box.add_child(modal_actions)


func _build_log_panel() -> void:
	var panel := _panel_container(Vector2(760, 610))
	log_overlay.get_child(0).add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var heading := _label("牌局日志", 28, Color("f1cd75"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var intro := _label("记录每次出牌的规则含义与实际结算结果", 14, Color("aeb9b2"))
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(intro)
	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = true
	log_text.fit_content = false
	log_text.scroll_active = true
	log_text.selection_enabled = true
	log_text.custom_minimum_size = Vector2(690, 440)
	log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_text.add_theme_font_size_override("normal_font_size", 15)
	log_text.add_theme_constant_override("line_separation", 5)
	box.add_child(log_text)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	actions.add_child(_button("清空日志", _clear_game_log))
	actions.add_child(_button("返回牌局", _hide_game_log, true))


func _make_overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.03, 0.03, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	return overlay


func _panel_container(minimum: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182426")
	style.border_color = Color("b68a3b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _turn_banner_style(emphasized: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("253638") if not emphasized else Color("58302a")
	style.border_color = Color("6f807c") if not emphasized else Color("f1cd75")
	style.set_border_width_all(2 if not emphasized else 3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	if emphasized:
		style.shadow_color = Color(0.95, 0.67, 0.20, 0.28)
		style.shadow_size = 10
	return style


func _seat_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.68, 0.22, 0.07) if active else Color.TRANSPARENT
	style.border_color = Color("f1cd75") if active else Color(0.3, 0.38, 0.37, 0.22)
	style.set_border_width_all(3 if active else 1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	if active:
		style.shadow_color = Color(0.95, 0.58, 0.15, 0.28)
		style.shadow_size = 9
	return style


func _order_panel_style(emphasized: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("19282a") if not emphasized else Color("71342d")
	style.border_color = Color("455b59") if not emphasized else Color("ffd66f")
	style.set_border_width_all(1 if not emphasized else 3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	if emphasized:
		style.shadow_color = Color(1.0, 0.60, 0.16, 0.45)
		style.shadow_size = 12
	return style


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text_value: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(110, 40)
	button.add_theme_font_size_override("font_size", 15)
	button.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("a93631") if primary else Color("26383a")
	normal.border_color = Color("dfb95f") if primary else Color("536769")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(9)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.12)
	button.add_theme_stylebox_override("pressed", pressed)
	button.pressed.connect(callback)
	return button


func _style_input(control: Control) -> void:
	control.custom_minimum_size.y = 44
	control.add_theme_font_size_override("font_size", 16)


func _avatar_texture(index: int) -> AtlasTexture:
	var atlas_index := index / 6
	var cell_index := index % 6
	var source: Texture2D = AVATAR_ATLASES[atlas_index]
	var cell_width := float(source.get_width()) / 3.0
	var cell_height := float(source.get_height()) / 2.0
	var texture := AtlasTexture.new()
	texture.atlas = source
	texture.region = Rect2((cell_index % 3) * cell_width, (cell_index / 3) * cell_height, cell_width, cell_height)
	return texture


func _avatar_view(index: int, avatar_size: int) -> TextureRect:
	var view := TextureRect.new()
	view.texture = _avatar_texture(index)
	view.custom_minimum_size = Vector2(avatar_size, avatar_size)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view


func _show_turn_identity(player: int, emphasized: bool, detail: String = "") -> void:
	if turn_banner == null:
		return
	var avatar_index := selected_avatar
	if player < player_avatar_indices.size():
		avatar_index = player_avatar_indices[player]
	turn_avatar.texture = _avatar_texture(avatar_index)
	var player_text := "YOU" if player == 0 else _player_name(player).to_upper()
	if detail.is_empty():
		detail = "YOUR TURN" if player == 0 else "THINKING…"
	action_label.text = "▶  %s\n%s" % [player_text, detail]
	turn_banner.add_theme_stylebox_override("panel", _turn_banner_style(emphasized))
	turn_banner.pivot_offset = turn_banner.size * 0.5
	turn_banner.scale = Vector2.ONE
	if emphasized:
		var pulse := create_tween()
		pulse.tween_property(turn_banner, "scale", Vector2(1.055, 1.055), _animation_duration(0.10))
		pulse.tween_property(turn_banner, "scale", Vector2.ONE, _animation_duration(0.18))


func _update_turn_order_display(emphasized: bool = false) -> void:
	if direction_label == null or players.is_empty() or player_count < 2:
		return
	var previous_player := posmod(current_player - direction, player_count)
	var next_player := _next_index(current_player)
	var direction_icon := "↻" if direction == 1 else "↺"
	var direction_name := "顺时针" if direction == 1 else "逆时针"
	direction_label.text = "%s  %s" % [direction_icon, direction_name]
	if emphasized:
		direction_label.text = "⚡ 方向已反转 · %s %s ⚡" % [direction_name, direction_icon]
	neighbors_label.text = "上一位：%s   │   当前：%s   │   下一位：%s" % [
		_order_player_name(previous_player),
		_order_player_name(current_player),
		_order_player_name(next_player),
	]
	var route: Array[String] = []
	var cursor := current_player
	for i in range(player_count):
		route.append(_order_player_name(cursor))
		cursor = posmod(cursor + direction, player_count)
	route.append(_order_player_name(current_player))
	route_label.text = "完整顺序：" + "  →  ".join(route)
	order_panel.add_theme_stylebox_override("panel", _order_panel_style(emphasized))
	direction_label.add_theme_color_override("font_color", Color("fff0a6") if emphasized else Color("f1cd75"))


func _flash_direction_change() -> void:
	direction_flash_active = true
	_update_turn_order_display(true)
	order_panel.pivot_offset = order_panel.size * 0.5
	var pulse := create_tween()
	pulse.tween_property(order_panel, "scale", Vector2(1.045, 1.045), _animation_duration(0.12))
	pulse.tween_property(order_panel, "scale", Vector2.ONE, _animation_duration(0.20))
	await get_tree().create_timer(_animation_duration(1.25)).timeout
	if is_instance_valid(order_panel):
		direction_flash_active = false
		_update_turn_order_display(false)


func _order_player_name(index: int) -> String:
	return "你" if index == 0 else _player_name(index)


func _show_game_log() -> void:
	if log_overlay.visible:
		return
	log_previous_locked = input_locked
	log_ai_remaining = ai_timer.time_left if not ai_timer.is_stopped() else 0.0
	log_uno_remaining = uno_timer.time_left if not uno_timer.is_stopped() else 0.0
	ai_timer.stop()
	uno_timer.stop()
	input_locked = true
	_refresh_game_log()
	log_overlay.visible = true


func _hide_game_log() -> void:
	log_overlay.visible = false
	input_locked = log_previous_locked
	if log_ai_remaining > 0.0 and round_active and current_player != 0:
		ai_timer.start(log_ai_remaining)
	if log_uno_remaining > 0.0 and awaiting_uno:
		uno_timer.start(log_uno_remaining)
	log_ai_remaining = 0.0
	log_uno_remaining = 0.0
	_update_ui()


func _clear_game_log() -> void:
	game_log_entries.clear()
	log_sequence = 0
	_refresh_game_log()


func _append_game_log(player: int, card: Dictionary, function_text: String, result_text: String) -> void:
	log_sequence += 1
	game_log_entries.append({
		"sequence": log_sequence,
		"round": round_number,
		"player": player,
		"player_name": _order_player_name(player),
		"card": _localized_card_name(card),
		"function": function_text,
		"result": result_text,
		"human": player == 0,
	})
	if game_log_entries.size() > 100:
		game_log_entries.pop_front()
	_refresh_game_log()


func _refresh_game_log() -> void:
	if log_text == null:
		return
	if game_log_entries.is_empty():
		log_text.text = "[center][color=#87938c]还没有出牌记录。开始游戏并打出一张牌后，说明会显示在这里。[/color][/center]"
		return
	var lines: Array[String] = []
	for entry in game_log_entries:
		var heading_color := "#f1cd75" if entry.human else "#b8d9c7"
		lines.append("[color=%s][b]%02d · 第%d局 · %s打出【%s】[/b][/color]" % [
			heading_color, entry.sequence, entry.round, _escape_bbcode(entry.player_name), _escape_bbcode(entry.card)
		])
		lines.append("[color=#b7b1a4]功能：[/color]%s" % _escape_bbcode(entry.function))
		lines.append("[color=#b7b1a4]结果：[/color]%s" % _escape_bbcode(entry.result))
		lines.append("[color=#465653]────────────────────────────────────────[/color]")
	log_text.text = "\n".join(lines)
	log_text.call_deferred("scroll_to_line", max(0, lines.size() - 1))


func _escape_bbcode(value: String) -> String:
	return value.replace("[", "［").replace("]", "］")


func _rebuild_avatar_grid() -> void:
	if avatar_grid == null:
		return
	_clear_children(avatar_grid)
	for index in range(AVATAR_NAMES.size()):
		var choice := Button.new()
		choice.custom_minimum_size = Vector2(70, 70)
		choice.icon = _avatar_texture(index)
		choice.expand_icon = true
		choice.tooltip_text = AVATAR_NAMES[index]
		choice.focus_mode = Control.FOCUS_NONE
		var style := StyleBoxFlat.new()
		style.bg_color = Color("26383a")
		style.border_color = Color("f1cd75") if index == selected_avatar else Color("435557")
		style.set_border_width_all(4 if index == selected_avatar else 1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 3
		style.content_margin_right = 3
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		choice.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = Color("385052")
		hover.border_color = Color("f1cd75")
		choice.add_theme_stylebox_override("hover", hover)
		choice.pressed.connect(_select_avatar.bind(index))
		avatar_grid.add_child(choice)


func _select_avatar(index: int) -> void:
	selected_avatar = index
	avatar_name_label.text = AVATAR_NAMES[index]
	_play_sfx("select")
	_rebuild_avatar_grid()


func _on_pace_selected(index: int) -> void:
	match index:
		0: game_speed = 0.65
		1: game_speed = 1.0
		_: game_speed = 1.5
	if ai_timer != null and not ai_timer.is_stopped():
		ai_timer.start(1.15 / game_speed)
	status_label.text = "Game pace: %s" % pace_select.get_item_text(index)
	_play_sfx("select")


func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	sound_button.text = "Sound: On" if sound_enabled else "Sound: Off"
	if sound_enabled:
		_play_sfx("select")


func _play_sfx(kind: String) -> void:
	if not sound_enabled or sfx_player == null:
		return
	if not sfx_cache.has(kind):
		var spec: Array = {
			"play": [520.0, 0.16],
			"action": [700.0, 0.22],
			"draw": [270.0, 0.18],
			"uno": [880.0, 0.34],
			"win": [1040.0, 0.55],
			"penalty": [155.0, 0.32],
			"select": [620.0, 0.10],
		}.get(kind, [440.0, 0.14])
		sfx_cache[kind] = _make_tone(float(spec[0]), float(spec[1]))
	sfx_player.stream = sfx_cache[kind]
	sfx_player.play()


func _make_tone(frequency: float, duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in range(sample_count):
		var time := float(i) / sample_rate
		var progress := float(i) / sample_count
		var envelope := sin(PI * progress) * (1.0 - progress * 0.35)
		var wave := sin(TAU * frequency * time) * 0.72 + sin(TAU * frequency * 1.5 * time) * 0.18
		var value := int(clampf(wave * envelope, -1.0, 1.0) * 15000.0)
		bytes.encode_s16(i * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream


func _animation_duration(base_seconds: float) -> float:
	return base_seconds / game_speed


func _animate_card(card: Dictionary, player: int, source_index: int, face_up: bool = true, drawing: bool = false) -> void:
	var ghost := CardView.new()
	ghost.configure(card, -1, face_up, false)
	ghost.size = Vector2(104, 156)
	ghost.pivot_offset = ghost.size * 0.5
	ghost.z_index = 40
	add_child(ghost)
	if not drawing:
		var badge_panel := PanelContainer.new()
		badge_panel.position = Vector2(-34, -38)
		badge_panel.size = Vector2(172, 30)
		badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color("8f2f2a")
		badge_style.border_color = Color("f1cd75")
		badge_style.set_border_width_all(2)
		badge_style.set_corner_radius_all(8)
		badge_panel.add_theme_stylebox_override("panel", badge_style)
		var badge := _label("%s  •  PLAYING" % ("YOU" if player == 0 else _player_name(player).to_upper()), 13, Color.WHITE)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_panel.add_child(badge)
		ghost.add_child(badge_panel)

	var start_position := Vector2(size.x * 0.5 - 52.0, size.y * 0.5 - 78.0)
	var end_position := start_position
	var highlight_rect := Rect2(start_position, Vector2(104, 156))
	if drawing:
		start_position = draw_slot.global_position + Vector2(maxf(0.0, draw_slot.size.x - 104.0) * 0.5, 28.0)
		if player == 0:
			end_position = Vector2(size.x * 0.5 - 52.0, size.y - 224.0)
		elif player - 1 < opponents_row.get_child_count():
			var opponent_panel: Control = opponents_row.get_child(player - 1)
			end_position = opponent_panel.global_position + Vector2(opponent_panel.size.x * 0.5 - 35.0, 38.0)
	else:
		end_position = discard_slot.global_position + Vector2(maxf(0.0, discard_slot.size.x - 104.0) * 0.5, 28.0)
		if player == 0 and source_index < hand_row.get_child_count():
			var source_card: Control = hand_row.get_child(source_index)
			start_position = source_card.global_position
			highlight_rect = Rect2(hand_row.global_position, hand_row.size)
			source_card.visible = false
		elif player > 0 and player - 1 < opponents_row.get_child_count():
			var opponent_panel: Control = opponents_row.get_child(player - 1)
			start_position = opponent_panel.global_position + Vector2(opponent_panel.size.x * 0.5 - 35.0, 38.0)
			highlight_rect = Rect2(opponent_panel.global_position, opponent_panel.size)

	if not drawing:
		_flash_player_area(highlight_rect)

	ghost.global_position = start_position
	ghost.scale = Vector2(0.78, 0.78) if drawing else Vector2.ONE
	ghost.rotation = deg_to_rad(-5.0 if player % 2 == 0 else 5.0)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ghost, "global_position", end_position, _animation_duration(0.48))
	tween.tween_property(ghost, "scale", Vector2.ONE, _animation_duration(0.48))
	tween.tween_property(ghost, "rotation", 0.0, _animation_duration(0.48))
	await tween.finished
	ghost.queue_free()


func _flash_player_area(area: Rect2) -> void:
	var highlight := Panel.new()
	highlight.global_position = area.position - Vector2(6, 6)
	highlight.size = area.size + Vector2(12, 12)
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.z_index = 39
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.68, 0.22, 0.06)
	style.border_color = Color("f1cd75")
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.95, 0.58, 0.15, 0.45)
	style.shadow_size = 14
	highlight.add_theme_stylebox_override("panel", style)
	add_child(highlight)
	var flash := create_tween()
	flash.tween_property(highlight, "modulate:a", 0.15, _animation_duration(0.58)).set_ease(Tween.EASE_OUT)
	flash.tween_callback(highlight.queue_free)


func _show_setup() -> void:
	ai_timer.stop()
	uno_timer.stop()
	input_locked = true
	setup_overlay.visible = true
	modal_overlay.visible = false


func _start_match() -> void:
	player_count = setup_players.get_selected_id()
	score_target = int(setup_score.value)
	round_number = 0
	game_log_entries.clear()
	log_sequence = 0
	player_avatar_indices.clear()
	player_avatar_indices.append(selected_avatar)
	var available_avatars: Array[int] = []
	for index in range(AVATAR_NAMES.size()):
		if index != selected_avatar:
			available_avatars.append(index)
	available_avatars.shuffle()
	for player in range(1, player_count):
		player_avatar_indices.append(available_avatars.pop_back())
	scores.clear()
	for i in range(player_count):
		scores.append(0)
	setup_overlay.visible = false
	_start_round()


func _start_round() -> void:
	round_number += 1
	players.clear()
	for i in range(player_count):
		players.append([])
	deck = _create_deck()
	deck.shuffle()
	discard.clear()
	direction = 1
	direction_flash_active = false
	current_player = 0
	round_active = true
	input_locked = true
	drawn_card_index = -1
	uno_declared = false
	awaiting_uno = false
	for card_number in range(7):
		for player in range(player_count):
			players[player].append(_draw_from_deck())

	var opener := _draw_from_deck()
	while opener.kind == "wild_draw_four":
		deck.append(opener)
		deck.shuffle()
		opener = _draw_from_deck()
	discard.append(opener)
	current_color = COLORS.pick_random() if opener.color == "wild" else opener.color
	status_label.text = "The cards are dealt."
	_apply_opening_card(opener)
	_update_ui()
	if opener.kind == "wild" and current_player == 0:
		_show_color_picker(true)
	else:
		_begin_turn()


func _create_deck() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for color in COLORS:
		result.append(_card(color, "number", 0))
		for value in range(1, 10):
			result.append(_card(color, "number", value))
			result.append(_card(color, "number", value))
		for kind in ["skip", "reverse", "draw_two"]:
			result.append(_card(color, kind))
			result.append(_card(color, kind))
	for i in range(4):
		result.append(_card("wild", "wild"))
		result.append(_card("wild", "wild_draw_four"))
	return result


func _card(color: String, kind: String, value: int = -1) -> Dictionary:
	return {"color": color, "kind": kind, "value": value}


func _apply_opening_card(card: Dictionary) -> void:
	match card.kind:
		"skip":
			current_player = _next_index(current_player)
			status_label.text = "%s is skipped by the opening card." % _player_name(0)
		"draw_two":
			_draw_cards(current_player, 2)
			current_player = _next_index(current_player)
			status_label.text = "Opening Draw Two: the first player draws 2 and is skipped."
		"reverse":
			direction = -1
			# The last seat is the dealer; an opening Reverse makes the dealer play first.
			current_player = player_count - 1
			status_label.text = "Opening Reverse: play begins with the dealer."


func _begin_turn() -> void:
	if not round_active:
		return
	input_locked = current_player != 0
	drawn_card_index = -1
	pass_button.visible = false
	uno_declared = false
	turn_label.text = "CURRENT TURN"
	_show_turn_identity(current_player, false)
	if current_player == 0:
		status_label.text = "没有可出的牌，请点击下方【抓一张牌】。" if not _has_playable_card(players[0]) else "出一张颜色、数字或符号匹配的牌；也可以选择抓牌。"
	else:
		status_label.text = "%s considers the hand…" % _player_name(current_player)
	_update_ui()
	if current_player != 0:
		ai_timer.start(1.15 / game_speed)


func _on_card_pressed(index: int) -> void:
	if input_locked or current_player != 0 or awaiting_uno:
		return
	if drawn_card_index >= 0 and index != drawn_card_index:
		status_label.text = "After drawing, only the drawn card may be played."
		return
	if not _is_playable(players[0][index]):
		status_label.text = "That card does not match the current color, number, or symbol."
		return
	_play_card(0, index)


func _on_draw_pressed() -> void:
	if input_locked or current_player != 0 or awaiting_uno or drawn_card_index >= 0:
		return
	input_locked = true
	var card := _draw_from_deck()
	_play_sfx("draw")
	await _animate_card(card, 0, players[0].size(), false, true)
	players[0].append(card)
	drawn_card_index = players[0].size() - 1
	if _is_playable(card):
		input_locked = false
		status_label.text = "The drawn card is playable. Play it, or keep it and pass."
		pass_button.visible = true
		_update_ui()
	else:
		status_label.text = "No match. The drawn card joins your hand."
		_update_ui()
		input_locked = true
		await get_tree().create_timer(0.65 / game_speed).timeout
		_advance_turn()


func _on_pass_pressed() -> void:
	if drawn_card_index < 0 or input_locked:
		return
	status_label.text = "You keep the drawn card."
	input_locked = true
	drawn_card_index = -1
	pass_button.visible = false
	_advance_turn()


func _play_card(player: int, index: int) -> void:
	input_locked = true
	pass_button.visible = false
	var old_color := current_color
	var card: Dictionary = players[player][index]
	var illegal_wild_four: bool = card.kind == "wild_draw_four" and _hand_has_color(players[player], old_color)
	_show_turn_identity(player, true, "PLAYS  %s" % _card_name(card).to_upper())
	status_label.text = "%s plays %s…" % [_player_name(player), _card_name(card)]
	_play_sfx("action" if card.kind != "number" else "play")
	await _animate_card(card, player, index, true, false)
	players[player].pop_at(index)
	discard.append(card)
	if card.color != "wild":
		current_color = card.color
	status_label.text = "%s plays %s." % [_player_name(player), _card_name(card)]
	_update_ui()

	if card.color == "wild":
		pending_wild_card = card
		pending_wild_illegal = illegal_wild_four
		pending_wild_player = player
		pending_previous_color = old_color
		if player == 0:
			_show_color_picker(false)
		else:
			current_color = _best_color(players[player])
			_after_wild_color_selected()
		return
	_resolve_card_effect(player, card)


func _resolve_card_effect(player: int, card: Dictionary) -> void:
	var steps := 1
	var result_text := "当前颜色变为%s；下一位是%s。" % [_localized_color(current_color), _order_player_name(_player_after_steps(player, 1))]
	match card.kind:
		"skip":
			var victim := _player_after_steps(player, 1)
			steps = 2
			status_label.text += " The next player is skipped."
			result_text = "%s被跳过；下一位是%s。" % [_order_player_name(victim), _order_player_name(_player_after_steps(player, steps))]
		"reverse":
			if player_count == 2:
				steps = 2
				status_label.text += " Reverse acts as Skip in a two-player game."
				result_text = "双人局中反转等同跳过对手；下一位仍是%s。" % _order_player_name(_player_after_steps(player, steps))
			else:
				direction *= -1
				status_label.text += " Direction reverses."
				result_text = "方向变为%s；下一位是%s。" % [_localized_direction(), _order_player_name(_player_after_steps(player, 1))]
				_flash_direction_change()
		"draw_two":
			var victim := _next_index(player)
			_draw_cards(victim, 2)
			steps = 2
			status_label.text += " %s draws 2 and is skipped." % _player_name(victim)
			result_text = "%s摸2张牌并被跳过；下一位是%s。" % [_order_player_name(victim), _order_player_name(_player_after_steps(player, steps))]
	result_text += _round_end_log_suffix(player)
	_append_game_log(player, card, _card_function_description(card), result_text)
	_finish_card_play(player, steps)


func _after_wild_color_selected() -> void:
	modal_overlay.visible = false
	color_chip.color = COLOR_HEX[current_color]
	status_label.text = "%s chooses %s." % [_player_name(pending_wild_player), current_color.capitalize()]
	if pending_wild_card.kind == "wild_draw_four":
		_resolve_wild_draw_four()
	else:
		var result_text := "当前颜色改为%s；下一位是%s。" % [_localized_color(current_color), _order_player_name(_player_after_steps(pending_wild_player, 1))]
		result_text += _round_end_log_suffix(pending_wild_player)
		_append_game_log(pending_wild_player, pending_wild_card, _card_function_description(pending_wild_card), result_text)
		_finish_card_play(pending_wild_player, 1)


func _resolve_wild_draw_four() -> void:
	var victim := _next_index(pending_wild_player)
	if victim == 0:
		_show_challenge_prompt()
		return
	# AI challengers are observant when the play is illegal and occasionally bluff otherwise.
	var challenges := pending_wild_illegal or randf() < 0.18
	if challenges:
		_resolve_challenge(true)
	else:
		_draw_cards(victim, 4)
		status_label.text += " %s accepts, draws 4, and is skipped." % _player_name(victim)
		var result_text := "颜色改为%s；%s接受牌效，摸4张并被跳过；下一位是%s。" % [
			_localized_color(current_color), _order_player_name(victim), _order_player_name(_player_after_steps(pending_wild_player, 2))
		]
		result_text += _round_end_log_suffix(pending_wild_player)
		_append_game_log(pending_wild_player, pending_wild_card, _card_function_description(pending_wild_card), result_text)
		_finish_card_play(pending_wild_player, 2)


func _show_challenge_prompt() -> void:
	input_locked = true
	modal_title.text = "Wild Draw Four"
	modal_body.text = "%s played +4. Challenge if you believe they held a %s card when it was played." % [_player_name(pending_wild_player), _previous_color_name()]
	_clear_children(modal_actions)
	modal_actions.add_child(_button("Accept +4", func(): _resolve_challenge(false)))
	modal_actions.add_child(_button("Challenge", func(): _resolve_challenge(true), true))
	modal_overlay.visible = true


func _resolve_challenge(challenged: bool) -> void:
	modal_overlay.visible = false
	var victim := _next_index(pending_wild_player)
	var result_text := ""
	if not challenged:
		_draw_cards(victim, 4)
		status_label.text += " %s draws 4 and is skipped." % _player_name(victim)
		result_text = "颜色改为%s；%s不挑战，摸4张并被跳过；下一位是%s。" % [
			_localized_color(current_color), _order_player_name(victim), _order_player_name(_player_after_steps(pending_wild_player, 2))
		]
		result_text += _round_end_log_suffix(pending_wild_player)
		_append_game_log(pending_wild_player, pending_wild_card, _card_function_description(pending_wild_card), result_text)
		_finish_card_play(pending_wild_player, 2)
	elif pending_wild_illegal:
		_draw_cards(pending_wild_player, 4)
		status_label.text = "Challenge succeeds! %s illegally held the matching color and draws 4." % _player_name(pending_wild_player)
		result_text = "挑战成功：出牌时仍持有%s牌，%s摸4张；%s继续出牌。" % [
			_localized_color(pending_previous_color), _order_player_name(pending_wild_player), _order_player_name(victim)
		]
		_append_game_log(pending_wild_player, pending_wild_card, _card_function_description(pending_wild_card), result_text)
		_finish_card_play(pending_wild_player, 1)
	else:
		_draw_cards(victim, 6)
		status_label.text = "Challenge fails. The play was legal; %s draws 6 and is skipped." % _player_name(victim)
		result_text = "挑战失败：出牌合法，颜色改为%s；%s摸6张并被跳过；下一位是%s。" % [
			_localized_color(current_color), _order_player_name(victim), _order_player_name(_player_after_steps(pending_wild_player, 2))
		]
		result_text += _round_end_log_suffix(pending_wild_player)
		_append_game_log(pending_wild_player, pending_wild_card, _card_function_description(pending_wild_card), result_text)
		_finish_card_play(pending_wild_player, 2)


func _finish_card_play(player: int, steps: int) -> void:
	_update_ui()
	if players[player].is_empty():
		_end_round(player)
		return
	if players[player].size() == 1:
		if player == 0 and not uno_declared:
			awaiting_uno = true
			uno_button.disabled = false
			status_label.text = "One card remains — call UNO before you are caught!"
			set_meta("pending_steps", steps)
			uno_timer.start(2.8 / game_speed)
			return
		else:
			status_label.text += " %s calls UNO!" % _player_name(player)
	_advance_turn(steps)


func _on_uno_pressed() -> void:
	if current_player != 0:
		return
	uno_declared = true
	_play_sfx("uno")
	if awaiting_uno:
		uno_timer.stop()
		awaiting_uno = false
		uno_button.disabled = true
		status_label.text = "UNO! The dragon hears your call."
		_advance_turn(int(get_meta("pending_steps", 1)))
	else:
		status_label.text = "UNO declared. Now play down to one card."


func _on_uno_timeout() -> void:
	if not awaiting_uno:
		return
	awaiting_uno = false
	_draw_cards(0, 2)
	_play_sfx("penalty")
	uno_button.disabled = true
	status_label.text = "Caught without calling UNO — draw 2 cards."
	_update_ui()
	_advance_turn(int(get_meta("pending_steps", 1)))


func _advance_turn(steps: int = 1) -> void:
	for i in range(steps):
		current_player = _next_index(current_player)
	_begin_turn()


func _take_ai_turn() -> void:
	if not round_active or current_player == 0:
		return
	var hand: Array = players[current_player]
	var choices: Array[int] = []
	for i in range(hand.size()):
		# The interface permits a bluff so it can be challenged, but AI players
		# deliberately obey the active-color restriction.
		var illegal_plus_four: bool = hand[i].kind == "wild_draw_four" and _hand_has_color(hand, current_color)
		if _is_playable(hand[i]) and not illegal_plus_four:
			choices.append(i)
	if choices.is_empty():
		var drawn := _draw_from_deck()
		status_label.text = "%s draws a card." % _player_name(current_player)
		_play_sfx("draw")
		await _animate_card(drawn, current_player, hand.size(), false, true)
		hand.append(drawn)
		_update_ui()
		if _is_playable(drawn):
			await get_tree().create_timer(0.55 / game_speed).timeout
			_play_card(current_player, hand.size() - 1)
		else:
			await get_tree().create_timer(0.55 / game_speed).timeout
			_advance_turn()
		return
	# Prefer action cards and cards in the AI's most common color.
	choices.sort_custom(func(a: int, b: int): return _ai_card_weight(hand[a], hand) > _ai_card_weight(hand[b], hand))
	_play_card(current_player, choices[0])


func _ai_card_weight(card: Dictionary, hand: Array) -> int:
	var weight := 0
	if card.kind != "number": weight += 8
	if card.color == _best_color(hand): weight += 5
	if card.kind == "wild_draw_four": weight -= 2
	return weight


func _is_playable(card: Dictionary) -> bool:
	if card.color == "wild":
		# Wild Draw Four may be placed as a bluff; legality is resolved through
		# the challenge flow, matching the physical game.
		return true
	var top: Dictionary = discard.back()
	return card.color == current_color or (card.kind == "number" and top.kind == "number" and card.value == top.value) or (card.kind != "number" and card.kind == top.kind)


func _has_playable_card(hand: Array) -> bool:
	for card in hand:
		if _is_playable(card):
			return true
	return false


func _draw_from_deck() -> Dictionary:
	if deck.is_empty():
		var top: Dictionary = discard.pop_back()
		deck.assign(discard)
		deck.shuffle()
		discard.clear()
		discard.append(top)
	return deck.pop_back()


func _draw_cards(player: int, count: int) -> void:
	for i in range(count):
		players[player].append(_draw_from_deck())


func _hand_has_color(hand: Array, color: String) -> bool:
	for card in hand:
		if card.color == color:
			return true
	return false


func _best_color(hand: Array) -> String:
	var counts := {"red": 0, "yellow": 0, "green": 0, "blue": 0}
	for card in hand:
		if card.color in counts:
			counts[card.color] += 1
	var best := COLORS[0]
	for color in COLORS:
		if counts[color] > counts[best]:
			best = color
	return best


func _next_index(from: int) -> int:
	return posmod(from + direction, player_count)


func _end_round(winner: int) -> void:
	round_active = false
	input_locked = true
	ai_timer.stop()
	uno_timer.stop()
	var points := 0
	for player in range(player_count):
		if player == winner:
			continue
		for card in players[player]:
			points += _card_points(card)
	scores[winner] += points
	_play_sfx("win")
	_update_ui()
	modal_overlay.visible = true
	_clear_children(modal_actions)
	if scores[winner] >= score_target:
		modal_title.text = "%s Wins the Match!" % _player_name(winner)
		modal_body.text = "The celestial court awards %d points this round.\nFinal score: %d — the target of %d has been reached." % [points, scores[winner], score_target]
		modal_actions.add_child(_button("New Match", _show_setup, true))
	else:
		modal_title.text = "%s Wins the Round" % _player_name(winner)
		modal_body.text = "%d points were gathered from the remaining hands.\n%s now has %d / %d points." % [points, _player_name(winner), scores[winner], score_target]
		modal_actions.add_child(_button("Next Round", func():
			modal_overlay.visible = false
			_start_round(), true))


func _card_points(card: Dictionary) -> int:
	match card.kind:
		"number": return card.value
		"skip", "reverse", "draw_two": return 20
		_: return 50


func _show_color_picker(opening: bool) -> void:
	input_locked = true
	modal_title.text = "Choose the Active Color"
	modal_body.text = "The Wild card bends to your will." if not opening else "The opening Wild card lets the first player choose the starting color."
	_clear_children(modal_actions)
	for color in COLORS:
		var choice := _button(color.capitalize(), func(chosen = color):
			_play_sfx("select")
			current_color = chosen
			if opening:
				modal_overlay.visible = false
				_begin_turn()
			else:
				_after_wild_color_selected())
		var style := choice.get_theme_stylebox("normal").duplicate()
		style.bg_color = COLOR_HEX[color]
		choice.add_theme_stylebox_override("normal", style)
		modal_actions.add_child(choice)
	modal_overlay.visible = true


func _show_rules() -> void:
	var was_locked := input_locked
	input_locked = true
	modal_title.text = "Classic Rules"
	modal_body.text = "Play one card matching the discard by color, number, or action symbol. If you do not play, draw one; a playable drawn card may be used immediately.\n\nSkip passes a turn, Reverse changes direction, and Draw Two adds two cards and skips. Wild chooses the active color. Wild Draw Four is legal only when you hold no card of the active color and may be challenged.\n\nCall UNO whenever you reach one card. A missed call costs two cards. No stacking. The first player to the score target wins."
	_clear_children(modal_actions)
	modal_actions.add_child(_button("Return", func():
		modal_overlay.visible = false
		input_locked = was_locked, true))
	modal_overlay.visible = true


func _update_ui() -> void:
	if scores.size() == player_count:
		var score_parts: Array[String] = []
		for i in range(player_count):
			score_parts.append("%s %d" % [_player_name(i), scores[i]])
		score_label.text = "  •  ".join(score_parts) + "   |   Target %d" % score_target
	color_chip.color = COLOR_HEX.get(current_color, Color.WHITE)
	_clear_children(opponents_row)
	for player in range(1, player_count):
		var seat := PanelContainer.new()
		seat.custom_minimum_size.x = 210
		seat.add_theme_stylebox_override("panel", _seat_style(current_player == player))
		var panel := VBoxContainer.new()
		seat.add_child(panel)
		if player < player_avatar_indices.size():
			var portrait := _avatar_view(player_avatar_indices[player], 48)
			portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			panel.add_child(portrait)
		var caption := _label("%s  •  %d cards" % [_player_name(player), players[player].size()], 15, Color("f1cd75") if current_player == player else Color("c9c3b3"))
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(caption)
		var backs := HBoxContainer.new()
		backs.alignment = BoxContainer.ALIGNMENT_CENTER
		backs.add_theme_constant_override("separation", -42)
		panel.add_child(backs)
		var shown: int = min(players[player].size(), 6)
		for i in range(shown):
			var back := CardView.new()
			back.configure({}, -1, false, false, true)
			backs.add_child(back)
		opponents_row.add_child(seat)

	_clear_children(draw_slot)
	draw_slot.add_child(_label("DRAW  •  %d" % deck.size(), 13, Color("b8a270")))
	var draw_card := CardView.new()
	draw_card.configure({}, -1, false, current_player == 0 and not input_locked and drawn_card_index < 0)
	draw_card.pressed.connect(_on_draw_pressed)
	draw_slot.add_child(draw_card)

	_clear_children(discard_slot)
	discard_slot.add_child(_label("DISCARD", 13, Color("b8a270")))
	if not discard.is_empty():
		var top_card := CardView.new()
		top_card.configure(discard.back(), -1, true, false)
		discard_slot.add_child(top_card)

	_clear_children(hand_row)
	if not players.is_empty():
		if not player_avatar_indices.is_empty():
			player_avatar_view.texture = _avatar_texture(player_avatar_indices[0])
			player_avatar_view.visible = true
			hand_caption.text = "%sYOUR HAND  •  %s" % ["▶  " if current_player == 0 else "", AVATAR_NAMES[player_avatar_indices[0]]]
		for i in range(players[0].size()):
			var card_view := CardView.new()
			var can_play := round_active and current_player == 0 and not input_locked and _is_playable(players[0][i]) and (drawn_card_index < 0 or drawn_card_index == i)
			card_view.configure(players[0][i], i, true, can_play)
			card_view.pressed.connect(_on_card_pressed.bind(i))
			hand_row.add_child(card_view)
	uno_button.disabled = current_player != 0 or input_locked or (not awaiting_uno and (players.is_empty() or players[0].size() != 2))
	var can_draw := round_active and current_player == 0 and not input_locked and not awaiting_uno and drawn_card_index < 0
	draw_button.disabled = not can_draw
	if can_draw and not players.is_empty() and not _has_playable_card(players[0]):
		draw_button.text = "无牌可出  →  抓一张牌"
		draw_button.tooltip_text = "当前手牌没有可出的牌，请点击这里抓牌"
	else:
		draw_button.text = "抓一张牌  DRAW"
		draw_button.tooltip_text = "从牌堆抓一张牌"
	pass_button.visible = drawn_card_index >= 0 and current_player == 0 and not input_locked
	_update_turn_order_display(direction_flash_active)


func _player_name(index: int) -> String:
	if index == 0:
		return "You"
	if index < player_avatar_indices.size():
		return AVATAR_NAMES[player_avatar_indices[index]]
	return "Immortal %d" % index


func _card_name(card: Dictionary) -> String:
	if card.kind == "number":
		return "%s %d" % [card.color.capitalize(), card.value]
	return (card.color + " " + str(card.kind).replace("_", " ")).capitalize()


func _localized_card_name(card: Dictionary) -> String:
	var color_name := _localized_color(str(card.color))
	match str(card.kind):
		"number":
			return "%s %d" % [color_name, int(card.value)]
		"skip":
			return "%s 跳过" % color_name
		"reverse":
			return "%s 反转" % color_name
		"draw_two":
			return "%s +2" % color_name
		"wild":
			return "万能变色"
		"wild_draw_four":
			return "万能变色 +4"
	return _card_name(card)


func _card_function_description(card: Dictionary) -> String:
	match str(card.kind):
		"number":
			return "数字牌：匹配颜色或数字，本身没有额外牌效。"
		"skip":
			return "跳过牌：轮到的下一位玩家失去本回合。"
		"reverse":
			return "反转牌：改变出牌方向；双人局中等同于跳过。"
		"draw_two":
			return "+2牌：下一位玩家摸2张牌，并失去本回合。"
		"wild":
			return "万能变色牌：出牌者选择新的当前颜色。"
		"wild_draw_four":
			return "万能变色+4：选择新颜色，下一位摸4张并被跳过；对方可以质疑本次出牌是否合法。"
	return "普通出牌。"


func _localized_color(color: String) -> String:
	match color:
		"red":
			return "红色"
		"yellow":
			return "黄色"
		"green":
			return "绿色"
		"blue":
			return "蓝色"
		"wild":
			return "万能色"
	return color


func _localized_direction() -> String:
	return "顺时针" if direction == 1 else "逆时针"


func _player_after_steps(from_player: int, steps: int) -> int:
	var player := from_player
	for i in range(steps):
		player = posmod(player + direction, player_count)
	return player


func _round_end_log_suffix(player: int) -> String:
	if player >= 0 and player < players.size() and players[player].is_empty():
		return "%s已打完全部手牌，赢得本局。" % _order_player_name(player)
	return ""


func _previous_color_name() -> String:
	return pending_previous_color.capitalize()


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
