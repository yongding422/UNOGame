@tool
## Runtime, rules, animation pacing, and audio regression tests.
extends McpTestSuite

func suite_name() -> String:
	return "rules"


func _new_game() -> Control:
	var packed: PackedScene = ResourceLoader.load("res://node_2d.tscn", "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	return packed.instantiate()


func test_classic_deck_composition() -> void:
	var game = _new_game()
	var cards: Array[Dictionary] = game._create_deck()
	assert_eq(cards.size(), 108, "Classic deck must contain 108 cards")
	var wilds := 0
	var wild_fours := 0
	var color_totals := {"red": 0, "yellow": 0, "green": 0, "blue": 0}
	for card in cards:
		if card.kind == "wild":
			wilds += 1
		elif card.kind == "wild_draw_four":
			wild_fours += 1
		else:
			color_totals[card.color] += 1
	assert_eq(wilds, 4, "Deck must contain four Wild cards")
	assert_eq(wild_fours, 4, "Deck must contain four Wild Draw Four cards")
	for color in color_totals:
		assert_eq(color_totals[color], 25, "%s suit must contain 25 cards" % color)
	game.free()


func test_card_matching_and_wild_challenge_detection() -> void:
	var game = _new_game()
	game.player_count = 2
	game.current_player = 0
	game.current_color = "red"
	var discard_cards: Array[Dictionary] = [game._card("red", "number", 7)]
	game.discard = discard_cards
	game.players = [[game._card("blue", "number", 7), game._card("red", "skip"), game._card("wild", "wild_draw_four")], []]
	assert_true(game._is_playable(game.players[0][0]), "A matching number must be playable")
	assert_true(game._is_playable(game.players[0][1]), "A matching color must be playable")
	assert_true(game._is_playable(game.players[0][2]), "Wild Draw Four must be allowed into the challenge flow")
	assert_true(game._has_playable_card(game.players[0]), "Draw prompt must detect that a playable card exists")
	assert_false(game._has_playable_card([game._card("blue", "number", 3)]), "Draw prompt must detect a hand with no legal play")
	assert_true(game._hand_has_color(game.players[0], "red"), "An illegal Wild Draw Four bluff must be detectable")
	game.free()


func test_scoring_values() -> void:
	var game = _new_game()
	assert_eq(game._card_points(game._card("yellow", "number", 9)), 9)
	assert_eq(game._card_points(game._card("green", "reverse")), 20)
	assert_eq(game._card_points(game._card("wild", "wild")), 50)
	game.free()


func test_two_player_direction_wraps_to_opponent() -> void:
	var game = _new_game()
	game.player_count = 2
	game.direction = 1
	assert_eq(game._next_index(0), 1)
	game.direction = -1
	assert_eq(game._next_index(0), 1)
	game.player_count = 4
	game.current_player = 1
	game.direction = 1
	assert_eq(posmod(game.current_player - game.direction, game.player_count), 0, "Clockwise previous seat")
	assert_eq(game._next_index(game.current_player), 2, "Clockwise next seat")
	game.direction = -1
	assert_eq(posmod(game.current_player - game.direction, game.player_count), 2, "Reverse swaps the previous seat")
	assert_eq(game._next_index(game.current_player), 0, "Reverse swaps the next seat")
	game.free()


func test_pace_scales_animation_duration() -> void:
	var game = _new_game()
	game.game_speed = 0.65
	var relaxed: float = game._animation_duration(0.48)
	game.game_speed = 1.5
	var swift: float = game._animation_duration(0.48)
	assert_gt(relaxed, swift, "Relaxed pace must keep animations on screen longer")
	assert_gt(relaxed, 0.7, "Relaxed card movement should remain readable")
	game.free()


func test_procedural_sound_has_expected_length() -> void:
	var game = _new_game()
	var sound: AudioStreamWAV = game._make_tone(440.0, 0.2)
	assert_true(sound.get_length() > 0.19, "Generated sound should have audible duration")
	assert_eq(sound.mix_rate, 22050)
	game.free()


func test_avatar_catalog_contains_thirty_cropped_portraits() -> void:
	var game = _new_game()
	assert_eq(game.AVATAR_NAMES.size(), 30, "Avatar catalog must expose 30 choices")
	assert_eq(game.AVATAR_ATLASES.size(), 5, "Five six-portrait atlases are expected")
	var first: AtlasTexture = game._avatar_texture(0)
	var last: AtlasTexture = game._avatar_texture(29)
	assert_true(first.region.size.x > 0.0)
	assert_true(last.region.size.y > 0.0)
	assert_ne(first.region.position, last.region.position, "First and last choices must use different atlas cells")
	game.free()


func test_game_log_explains_cards_and_turn_results() -> void:
	var game = _new_game()
	assert_eq(game._localized_card_name(game._card("red", "draw_two")), "红色 +2")
	assert_true("摸2张" in game._card_function_description(game._card("red", "draw_two")))
	assert_true("双人局" in game._card_function_description(game._card("green", "reverse")))
	assert_true("质疑" in game._card_function_description(game._card("wild", "wild_draw_four")))
	game.player_count = 4
	game.direction = -1
	assert_eq(game._player_after_steps(0, 2), 2, "Log result must follow the active direction")
	game.free()
