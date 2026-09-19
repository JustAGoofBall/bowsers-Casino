extends Node2D

# Single-zero (European) wheel. The pocket order below is the one painted on
# assets/roulette/roulette-wheel.png, read clockwise starting at the green 0,
# so the number the spin picks is the number the ball is sitting on.
const POCKET_COUNT := 37
const WHEEL_ORDER := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11,
	30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35,
	3, 26]
const POCKET_ARC := TAU / POCKET_COUNT

# In the unrotated texture the green 0 sits 93.93 degrees clockwise from the
# marker at the top of the wheel, fitted across all 37 pocket boundaries in
# the source image (worst-case error 1.9 degrees, against a 9.7 degree pocket).
const ZERO_POCKET_OFFSET := 1.63930

const RED_NUMBERS := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30,
	32, 34, 36]

# Ball radii in Wheel-local pixels (the wheel texture is drawn at 0.8, so its
# outer rim is at 184 and the numbered ring spans 110-176): the outer rail the
# ball rides while it is still travelling, and where it settles in the pocket,
# far enough out to leave the printed number readable.
const BALL_TRACK_RADIUS := 176.0
const BALL_POCKET_RADIUS := 156.0

# Chip rack. The artwork carries no numerals, so the values live here and the
# denomination is drawn as a Label on top of the chip.
const CHIPS := [
	{"value": 5, "texture": "res://assets/roulette/chips/ChipIvory.svg"},
	{"value": 25, "texture": "res://assets/roulette/chips/ChipRed.svg"},
	{"value": 100, "texture": "res://assets/roulette/chips/ChipGreen.svg"},
	{"value": 500, "texture": "res://assets/roulette/chips/ChipPurple.svg"},
]

const HISTORY_LENGTH := 12

# BallRoll.wav is a steady loop of the ball ticking over the pocket frets;
# dropping its pitch as the wheel slows stretches those ticks out with it.
const ROLL_PITCH_FAST := 1.7
const ROLL_PITCH_SLOW := 0.55

var global_manager: Node
var current_bets: Dictionary = {}
var last_bets: Dictionary = {}
var history: Array[int] = []

var is_spinning: bool = false
var target_number: int = -1
var target_rotation: float = 0.0
var spin_start_rotation: float = 0.0
var ball_total_angle: float = 0.0
var spin_duration: float = 0.0
var spin_elapsed: float = 0.0

var bet_amount: int = 25
var bet_targets: Dictionary = {}
var chip_textures: Array = []
var pip_texture: Texture2D

@onready var wheel: Node2D = $WheelArea/Wheel
@onready var ball: Sprite2D = $WheelArea/Wheel/Ball
@onready var result_label: Label = $ResultLabel
@onready var total_bet_label: Label = $TotalBetLabel
@onready var money_label: Label = $MoneyLabel
@onready var spin_button: Button = $SpinButton
@onready var clear_bets_button: Button = $ClearBetsButton
@onready var rebet_button: Button = $RebetButton
@onready var back_button: Button = $BackButton
@onready var chip_rack: HBoxContainer = $ChipRack
@onready var bet_markers: Node2D = $BetMarkers
@onready var history_box: HBoxContainer = $HistoryStrip/HistoryBox
@onready var bowser_sprite: Sprite2D = $BowserSprite
@onready var bwahaha: AudioStreamPlayer = $Bwahaha
@onready var ball_roll_sound: AudioStreamPlayer = $BallRoll
@onready var ball_drop_sound: AudioStreamPlayer = $BallDrop
@onready var chip_sound: AudioStreamPlayer = $ChipPlace
@onready var win_sound: AudioStreamPlayer = $WinChime

var bowser_default: Texture2D
var bowser_win: Texture2D
var bowser_lost: Texture2D


func _ready() -> void:
	global_manager = get_node("/root/GlobalManager")
	global_manager.money_changed.connect(_on_money_changed)

	bowser_default = load("res://assets/bowser/BowserDefault.png")
	bowser_win = load("res://assets/bowser/bowserWin.png")
	bowser_lost = load("res://assets/bowser/BowserLost.png")
	pip_texture = load("res://assets/roulette/HistoryPip.svg")
	for chip in CHIPS:
		chip_textures.append(load(chip["texture"]))

	_build_bet_targets()
	_build_chip_rack()
	_on_money_changed(global_manager.get_money())
	_update_total_bet()
	_update_buttons()

	# Control rectangles are not final until the first layout pass, so the
	# bet markers can only be positioned after one frame has been processed.
	await get_tree().process_frame
	_refresh_bet_markers()


func _process(delta: float) -> void:
	if not is_spinning:
		return

	spin_elapsed += delta
	var progress: float = clampf(spin_elapsed / spin_duration, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - progress, 3.0)

	wheel.rotation = lerpf(spin_start_rotation, target_rotation, eased)

	# The ball runs against the wheel, wobbles while it is fast and spirals
	# down into the numbered ring over the last part of the spin. At
	# progress 1.0 every term collapses to zero, so the ball comes to rest
	# under the marker at the top without needing to be snapped into place.
	var ball_angle: float = -ball_total_angle * (1.0 - eased)
	var wobble: float = sin(progress * TAU * 4.0) * 0.06 * (1.0 - progress)
	var drop: float = clampf((progress - 0.55) / 0.45, 0.0, 1.0)
	var radius: float = lerpf(BALL_TRACK_RADIUS, BALL_POCKET_RADIUS, drop)
	var local_angle: float = ball_angle + wobble - wheel.rotation
	ball.position = Vector2(sin(local_angle) * radius, -cos(local_angle) * radius)

	if ball_roll_sound.playing:
		ball_roll_sound.pitch_scale = lerpf(ROLL_PITCH_FAST, ROLL_PITCH_SLOW, eased)


# --- Betting -----------------------------------------------------------------

func _place_bet(bet_type: String, bet_value) -> void:
	if is_spinning:
		return

	if global_manager.get_money() < bet_amount:
		result_label.text = "Not enough coins for a %d chip!" % bet_amount
		return

	var bet_key := bet_type + "_" + str(bet_value)

	if bet_key in current_bets:
		current_bets[bet_key]["amount"] += bet_amount
	else:
		current_bets[bet_key] = {
			"type": bet_type,
			"value": bet_value,
			"amount": bet_amount,
		}

	global_manager.remove_money(bet_amount)
	_play(chip_sound)
	_update_total_bet()
	_refresh_bet_markers()
	_update_buttons()
	result_label.text = "%d on %s" % [bet_amount, _get_bet_description(bet_type, bet_value)]


func _get_bet_description(bet_type: String, bet_value) -> String:
	match bet_type:
		"number":
			return "Number " + str(bet_value)
		"color", "odd_even", "high_low":
			return str(bet_value).to_upper()
		"dozen":
			return "Dozen " + str(bet_value)
		"column":
			return "Column " + str(bet_value)
	return ""


func _total_staked() -> int:
	var total := 0
	for bet_key in current_bets:
		total += current_bets[bet_key]["amount"]
	return total


# --- Spin --------------------------------------------------------------------

func _on_spin_button_pressed() -> void:
	if is_spinning:
		return

	if current_bets.is_empty():
		result_label.text = "Place a bet first!"
		return

	is_spinning = true
	result_label.text = "No more bets..."
	_update_buttons()
	_set_bowser(bowser_default)

	global_manager.increment_games_played()

	var pocket_index := randi() % POCKET_COUNT
	target_number = WHEEL_ORDER[pocket_index]

	# Where that pocket sits in the wheel's own frame, and the rotation that
	# brings it under the marker at the top.
	var pocket_angle: float = ZERO_POCKET_OFFSET + pocket_index * POCKET_ARC
	var resting_rotation: float = fposmod(-pocket_angle, TAU)
	var base: float = wheel.rotation + float(randi_range(4, 6)) * TAU

	spin_start_rotation = wheel.rotation
	target_rotation = base + fposmod(resting_rotation - base, TAU)
	ball_total_angle = float(randi_range(7, 10)) * TAU
	spin_duration = randf_range(3.5, 4.5)
	spin_elapsed = 0.0

	ball_roll_sound.pitch_scale = ROLL_PITCH_FAST
	_play(ball_roll_sound)

	# The ball reaches its pocket at spin_duration; the clatter belongs there,
	# not after the pause that follows it.
	await get_tree().create_timer(spin_duration).timeout
	if not is_inside_tree():
		return
	ball_roll_sound.stop()
	_play(ball_drop_sound)

	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return

	_process_results()

	is_spinning = false
	_update_buttons()


func _process_results() -> void:
	var staked := _total_staked()
	var returned := 0
	var winning_color := _get_number_color(target_number)
	var is_odd := target_number > 0 and target_number % 2 == 1
	var is_even := target_number > 0 and target_number % 2 == 0
	var is_high := target_number >= 19 and target_number <= 36
	var is_low := target_number >= 1 and target_number <= 18

	for bet_key in current_bets:
		var bet: Dictionary = current_bets[bet_key]
		var payout := 0

		match bet["type"]:
			"number":
				if bet["value"] == target_number:
					payout = bet["amount"] * 36  # 35:1 plus the stake back
			"color":
				if bet["value"] == winning_color:
					payout = bet["amount"] * 2
			"odd_even":
				if (bet["value"] == "odd" and is_odd) or (bet["value"] == "even" and is_even):
					payout = bet["amount"] * 2
			"high_low":
				if (bet["value"] == "high" and is_high) or (bet["value"] == "low" and is_low):
					payout = bet["amount"] * 2
			"dozen":
				if target_number >= 1 and target_number <= 36:
					var dozen := ((target_number - 1) / 12) + 1
					if bet["value"] == dozen:
						payout = bet["amount"] * 3  # 2:1 plus the stake back
			"column":
				if target_number >= 1 and target_number <= 36:
					# Columns run 1/4/7..., 2/5/8..., 3/6/9... down the board,
					# so the column is the number's position modulo three.
					var column := ((target_number - 1) % 3) + 1
					if bet["value"] == column:
						payout = bet["amount"] * 3

		returned += payout

	if returned > 0:
		global_manager.add_money(returned)

	var net := returned - staked
	var headline := "%d %s" % [target_number, winning_color.to_upper()]

	if net > 0:
		result_label.text = "%s - you win %d coins!" % [headline, net]
		_set_bowser(bowser_lost)
		_play(win_sound)
	elif net == 0:
		result_label.text = "%s - you break even." % headline
		_set_bowser(bowser_default)
	else:
		result_label.text = "%s - you lose %d coins." % [headline, -net]
		_set_bowser(bowser_win)
		_play(bwahaha)

	last_bets = _copy_bets(current_bets)
	_add_history(target_number)
	current_bets.clear()
	_update_total_bet()
	_refresh_bet_markers()


func _get_number_color(number: int) -> String:
	if number == 0:
		return "green"
	elif number in RED_NUMBERS:
		return "red"
	return "black"


# --- Board controls ----------------------------------------------------------

func _on_clear_bets_pressed() -> void:
	if is_spinning or current_bets.is_empty():
		return

	for bet_key in current_bets:
		global_manager.add_money(current_bets[bet_key]["amount"])

	current_bets.clear()
	_update_total_bet()
	_refresh_bet_markers()
	_update_buttons()
	result_label.text = "All bets cleared"


func _on_rebet_pressed() -> void:
	if is_spinning or last_bets.is_empty():
		return

	var needed := 0
	for bet_key in last_bets:
		needed += last_bets[bet_key]["amount"]

	if global_manager.get_money() < needed:
		result_label.text = "Not enough coins to repeat that bet (%d)." % needed
		return

	for bet_key in last_bets:
		var bet: Dictionary = last_bets[bet_key]
		if bet_key in current_bets:
			current_bets[bet_key]["amount"] += bet["amount"]
		else:
			current_bets[bet_key] = bet.duplicate(true)

	global_manager.remove_money(needed)
	_update_total_bet()
	_refresh_bet_markers()
	_update_buttons()
	result_label.text = "Repeated last bet (%d coins)" % needed


func _copy_bets(bets: Dictionary) -> Dictionary:
	var out := {}
	for bet_key in bets:
		out[bet_key] = bets[bet_key].duplicate(true)
	return out


# --- Chips -------------------------------------------------------------------

func _build_chip_rack() -> void:
	for child in chip_rack.get_children():
		child.queue_free()

	for i in range(CHIPS.size()):
		var chip: Dictionary = CHIPS[i]
		var button := TextureButton.new()
		button.texture_normal = chip_textures[i]
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = Vector2(56, 56)
		button.tooltip_text = "Bet %d per click" % chip["value"]
		button.pressed.connect(_on_chip_pressed.bind(int(chip["value"])))

		var label := Label.new()
		label.text = str(chip["value"])
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", 5)
		button.add_child(label)

		chip_rack.add_child(button)

	_update_chip_rack()


func _on_chip_pressed(value: int) -> void:
	if is_spinning:
		return
	bet_amount = value
	_update_chip_rack()


func _update_chip_rack() -> void:
	for i in range(chip_rack.get_child_count()):
		var button := chip_rack.get_child(i) as TextureButton
		if button == null:
			continue
		var selected: bool = int(CHIPS[i]["value"]) == bet_amount
		button.modulate = Color(1, 1, 1) if selected else Color(0.62, 0.62, 0.62)
		button.scale = Vector2(1.12, 1.12) if selected else Vector2.ONE


func _chip_texture_for(amount: int) -> Texture2D:
	var texture: Texture2D = chip_textures[0]
	for i in range(CHIPS.size()):
		if amount >= int(CHIPS[i]["value"]):
			texture = chip_textures[i]
	return texture


# --- Bet markers -------------------------------------------------------------

func _build_bet_targets() -> void:
	var grid := $BettingBoard/NumberGrid
	for n in range(1, 37):
		var button := grid.get_node_or_null("Num%d" % n)
		if button:
			bet_targets["number_%d" % n] = button

	var zero := $BettingBoard/ZeroBox.get_node_or_null("ZeroButton")
	if zero:
		bet_targets["number_0"] = zero

	var outside := $BettingBoard/OutsideBets
	var names := {
		"Row1/Low": "high_low_low",
		"Row1/High": "high_low_high",
		"Row1/Even": "odd_even_even",
		"Row1/Odd": "odd_even_odd",
		"Row1/RedBet": "color_red",
		"Row1/BlackBet": "color_black",
		"Row2/Dozen1": "dozen_1",
		"Row2/Dozen2": "dozen_2",
		"Row2/Dozen3": "dozen_3",
		"Row3/Col1": "column_1",
		"Row3/Col2": "column_2",
		"Row3/Col3": "column_3",
	}
	for path in names:
		var button := outside.get_node_or_null(path)
		if button:
			bet_targets[names[path]] = button


func _refresh_bet_markers() -> void:
	for child in bet_markers.get_children():
		child.queue_free()

	for bet_key in current_bets:
		var target: Control = bet_targets.get(bet_key)
		if target == null:
			continue

		var amount: int = current_bets[bet_key]["amount"]
		var marker := Sprite2D.new()
		marker.texture = _chip_texture_for(amount)
		marker.scale = Vector2(0.19, 0.19)
		marker.position = target.get_global_rect().get_center()
		marker.z_index = 10

		var label := Label.new()
		label.text = str(amount)
		label.size = Vector2(80, 26)
		label.position = Vector2(-40, -13)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.scale = Vector2(1.0 / marker.scale.x, 1.0 / marker.scale.y)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", 5)
		marker.add_child(label)

		bet_markers.add_child(marker)


# --- History -----------------------------------------------------------------

func _add_history(number: int) -> void:
	history.push_front(number)
	while history.size() > HISTORY_LENGTH:
		history.pop_back()

	for child in history_box.get_children():
		child.queue_free()

	for n in history:
		var pip := TextureRect.new()
		pip.texture = pip_texture
		pip.custom_minimum_size = Vector2(30, 30)
		pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# self_modulate tints the pip without also tinting the number on top.
		match _get_number_color(n):
			"red":
				pip.self_modulate = Color(0.85, 0.16, 0.16)
			"black":
				pip.self_modulate = Color(0.13, 0.13, 0.15)
			_:
				pip.self_modulate = Color(0.1, 0.65, 0.3)

		var label := Label.new()
		label.text = str(n)
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", 4)
		pip.add_child(label)

		history_box.add_child(pip)


# --- UI ----------------------------------------------------------------------

func _on_money_changed(new_amount: int) -> void:
	money_label.text = "Coins: %d" % new_amount


func _update_total_bet() -> void:
	total_bet_label.text = "Total Bet: %d coins" % _total_staked()


func _update_buttons() -> void:
	spin_button.disabled = is_spinning or current_bets.is_empty()
	clear_bets_button.disabled = is_spinning or current_bets.is_empty()
	rebet_button.disabled = is_spinning or last_bets.is_empty()
	back_button.disabled = is_spinning


func _play(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()


func _set_bowser(texture: Texture2D) -> void:
	if bowser_sprite and texture:
		bowser_sprite.texture = texture


# --- Signal handlers wired up in Roulette.tscn --------------------------------

func _on_number_button_pressed(number: int) -> void:
	_place_bet("number", number)

func _on_red_button_pressed() -> void:
	_place_bet("color", "red")

func _on_black_button_pressed() -> void:
	_place_bet("color", "black")

func _on_odd_button_pressed() -> void:
	_place_bet("odd_even", "odd")

func _on_even_button_pressed() -> void:
	_place_bet("odd_even", "even")

func _on_high_button_pressed() -> void:
	_place_bet("high_low", "high")

func _on_low_button_pressed() -> void:
	_place_bet("high_low", "low")

func _on_dozen1_button_pressed() -> void:
	_place_bet("dozen", 1)

func _on_dozen2_button_pressed() -> void:
	_place_bet("dozen", 2)

func _on_dozen3_button_pressed() -> void:
	_place_bet("dozen", 3)

func _on_column_button_pressed(column: int) -> void:
	_place_bet("column", column)

func _on_back_button_pressed() -> void:
	if is_spinning:
		return
	ball_roll_sound.stop()
	get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
