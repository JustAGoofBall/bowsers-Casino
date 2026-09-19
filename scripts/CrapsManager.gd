extends Node2D

# Craps: pass line, don't pass, free odds behind the line, and the common
# one-roll proposition bets.
#
# Payouts are written as a TOTAL return per coin staked, matching the other
# games here: the stake leaves your balance when the bet is placed, so an
# even-money winner returns 2.

const BET_STEPS := [10, 20, 50, 100]

# True odds behind the pass line, as numerator/denominator of the win.
# Every stake step is a multiple of ten, so these divide exactly.
const ODDS_RATIO := {
	4: [2, 1], 10: [2, 1],
	5: [3, 2], 9: [3, 2],
	6: [6, 5], 8: [6, 5],
}

const MAX_ODDS_MULTIPLE := 2  # double odds

const CHIPS := [
	{"value": 10, "texture": "res://assets/roulette/chips/ChipIvory.svg"},
	{"value": 20, "texture": "res://assets/roulette/chips/ChipRed.svg"},
	{"value": 50, "texture": "res://assets/roulette/chips/ChipGreen.svg"},
	{"value": 100, "texture": "res://assets/roulette/chips/ChipPurple.svg"},
]

var global_manager: Node
var point: int = 0
var is_rolling: bool = false
var chip_value: int = 10
var chip_textures: Array = []
var die_textures: Array = []

var bets := {
	"pass": 0,
	"dont_pass": 0,
	"odds": 0,
	"field": 0,
	"any_seven": 0,
	"any_craps": 0,
}

@onready var die_one: Sprite2D = $Dice/DieOne
@onready var die_two: Sprite2D = $Dice/DieTwo
@onready var point_label: Label = $PointLabel
@onready var result_label: Label = $ResultLabel
@onready var money_label: Label = $MoneyLabel
@onready var roll_button: Button = $RollButton
@onready var clear_button: Button = $ClearButton
@onready var back_button: Button = $BackButton
@onready var chip_rack: HBoxContainer = $ChipRack
@onready var bowser_sprite: Sprite2D = $BowserSprite
@onready var reference_label: Label = $ReferencePanel/ReferenceLabel
@onready var dice_sound: AudioStreamPlayer = $DiceRoll
@onready var chip_sound: AudioStreamPlayer = $ChipPlace
@onready var win_sound: AudioStreamPlayer = $WinChime
@onready var bwahaha: AudioStreamPlayer = $Bwahaha

@onready var bet_buttons := {
	"pass": $BetButtons/PassLine,
	"dont_pass": $BetButtons/DontPass,
	"field": $BetButtons/Field,
	"odds": $BetButtons/Odds,
	"any_seven": $BetButtons/AnySeven,
	"any_craps": $BetButtons/AnyCraps,
}

var bowser_default: Texture2D
var bowser_win: Texture2D
var bowser_lost: Texture2D


func _ready() -> void:
	global_manager = get_node("/root/GlobalManager")
	global_manager.money_changed.connect(_on_money_changed)

	bowser_default = load("res://assets/bowser/BowserDefault.png")
	bowser_win = load("res://assets/bowser/bowserWin.png")
	bowser_lost = load("res://assets/bowser/BowserLost.png")
	for value in range(1, 7):
		die_textures.append(load("res://assets/craps/Die%d.svg" % value))
	for chip in CHIPS:
		chip_textures.append(load(chip["texture"]))

	_show_dice(1, 1)
	_build_chip_rack()
	reference_label.text = _build_reference_text()
	_on_money_changed(global_manager.get_money())
	_refresh()
	result_label.text = "Come-out roll. 7 or 11 wins the pass line, 2/3/12 craps out."


# --- betting -------------------------------------------------------------------

func _place(bet_key: String) -> void:
	if is_rolling:
		return

	if bet_key in ["pass", "dont_pass"] and point != 0:
		result_label.text = "Line bets can only go up on a come-out roll."
		return

	if bet_key == "odds":
		if point == 0:
			result_label.text = "Odds can only be taken once a point is set."
			return
		if bets["pass"] <= 0:
			result_label.text = "Odds go behind a pass line bet - you have none."
			return
		var cap: int = bets["pass"] * MAX_ODDS_MULTIPLE
		if bets["odds"] + chip_value > cap:
			result_label.text = "Odds are capped at %dx your line bet (%d)." % [
				MAX_ODDS_MULTIPLE, cap]
			return

	if global_manager.get_money() < chip_value:
		result_label.text = "Not enough coins for a %d chip!" % chip_value
		return

	bets[bet_key] += chip_value
	global_manager.remove_money(chip_value)
	_play(chip_sound)
	_refresh()


func _total_staked() -> int:
	var total := 0
	for key in bets:
		total += bets[key]
	return total


func _on_clear_pressed() -> void:
	if is_rolling or point != 0:
		return
	var refund := _total_staked()
	if refund <= 0:
		return
	global_manager.add_money(refund)
	for key in bets:
		bets[key] = 0
	result_label.text = "Bets cleared (%d coins back)." % refund
	_refresh()


# --- rolling --------------------------------------------------------------------

func _on_roll_pressed() -> void:
	if is_rolling:
		return
	if _total_staked() <= 0 and point == 0:
		result_label.text = "Put something on the table first!"
		return

	is_rolling = true
	_set_controls_enabled(false)
	result_label.text = "Rolling..."
	_set_bowser(bowser_default)
	global_manager.increment_games_played()
	_play(dice_sound)

	var first := 1
	var second := 1
	for _tumble in range(14):
		first = randi_range(1, 6)
		second = randi_range(1, 6)
		_show_dice(first, second)
		await get_tree().create_timer(0.07).timeout
		if not is_inside_tree():
			return

	_resolve(first + second)

	is_rolling = false
	_set_controls_enabled(true)
	_refresh()


func _show_dice(first: int, second: int) -> void:
	die_one.texture = die_textures[first - 1]
	die_two.texture = die_textures[second - 1]


func _resolve(total: int) -> void:
	var notes: Array[String] = []
	var net := 0

	# --- one-roll propositions, settled on every roll --------------------
	if bets["field"] > 0:
		var field_stake: int = bets["field"]
		var field_mult := 0
		if total == 2:
			field_mult = 3        # 2:1
		elif total == 12:
			field_mult = 4        # 3:1
		elif total in [3, 4, 9, 10, 11]:
			field_mult = 2        # 1:1
		bets["field"] = 0
		net += _settle("Field", field_stake, field_stake * field_mult, notes)

	if bets["any_seven"] > 0:
		var seven_stake: int = bets["any_seven"]
		bets["any_seven"] = 0
		net += _settle("Any 7", seven_stake, (seven_stake * 5) if total == 7 else 0, notes)

	if bets["any_craps"] > 0:
		var craps_stake: int = bets["any_craps"]
		var craps_won: bool = total in [2, 3, 12]
		bets["any_craps"] = 0
		net += _settle("Any Craps", craps_stake, (craps_stake * 8) if craps_won else 0, notes)

	# --- the line --------------------------------------------------------
	if point == 0:
		if total == 7 or total == 11:
			net += _settle_line(total, true, notes)
		elif total == 2 or total == 3:
			net += _settle_line(total, false, notes)
		elif total == 12:
			# A 12 craps out the pass line but only pushes don't pass, which
			# is exactly where the don't-pass edge comes from.
			if bets["pass"] > 0:
				var twelve_stake: int = bets["pass"]
				bets["pass"] = 0
				net += _settle("Pass line", twelve_stake, 0, notes)
			if bets["dont_pass"] > 0:
				notes.append("Don't pass pushes on 12 - bet stays up")
		else:
			point = total
			notes.append("Point is %d. Roll it again before a 7." % point)
	else:
		if total == point:
			net += _settle_line(total, true, notes)
			point = 0
		elif total == 7:
			net += _settle_line(total, false, notes)
			point = 0
		else:
			notes.append("No decision. Point is still %d." % point)

	var headline := "Rolled %d" % total
	result_label.text = headline + " - " + ("; ".join(notes) if not notes.is_empty()
		else "nothing riding on it.")

	if net > 0:
		_set_bowser(bowser_lost)
		_play(win_sound)
	elif net < 0:
		_set_bowser(bowser_win)
		_play(bwahaha)
	else:
		_set_bowser(bowser_default)


func _settle_line(total: int, pass_wins: bool, notes: Array[String]) -> int:
	var net := 0

	if bets["pass"] > 0:
		var pass_stake: int = bets["pass"]
		bets["pass"] = 0
		net += _settle("Pass line", pass_stake, (pass_stake * 2) if pass_wins else 0, notes)

	if bets["odds"] > 0:
		var odds_stake: int = bets["odds"]
		var odds_return := 0
		if pass_wins and total in ODDS_RATIO:
			var ratio: Array = ODDS_RATIO[total]
			odds_return = odds_stake + odds_stake * int(ratio[0]) / int(ratio[1])
		bets["odds"] = 0
		net += _settle("Odds", odds_stake, odds_return, notes)

	if bets["dont_pass"] > 0:
		var dont_stake: int = bets["dont_pass"]
		bets["dont_pass"] = 0
		net += _settle("Don't pass", dont_stake, 0 if pass_wins else (dont_stake * 2), notes)

	return net


func _settle(label: String, stake: int, returned: int, notes: Array[String]) -> int:
	if returned > 0:
		global_manager.add_money(returned)
	var net := returned - stake
	if net > 0:
		notes.append("%s wins %d" % [label, net])
	elif net == 0 and returned > 0:
		notes.append("%s pushes" % label)
	else:
		notes.append("%s loses %d" % [label, stake])
	return net


# --- chips -----------------------------------------------------------------------

func _build_chip_rack() -> void:
	for child in chip_rack.get_children():
		child.queue_free()

	for i in range(CHIPS.size()):
		var chip: Dictionary = CHIPS[i]
		var button := TextureButton.new()
		button.texture_normal = chip_textures[i]
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = Vector2(52, 52)
		button.tooltip_text = "Bet %d per click" % chip["value"]
		button.pressed.connect(_on_chip_pressed.bind(int(chip["value"])))

		var label := Label.new()
		label.text = str(chip["value"])
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", 5)
		button.add_child(label)

		chip_rack.add_child(button)

	_update_chip_rack()


func _on_chip_pressed(value: int) -> void:
	if is_rolling:
		return
	chip_value = value
	_update_chip_rack()


func _update_chip_rack() -> void:
	for i in range(chip_rack.get_child_count()):
		var button := chip_rack.get_child(i) as TextureButton
		if button == null:
			continue
		var selected: bool = int(CHIPS[i]["value"]) == chip_value
		button.modulate = Color(1, 1, 1) if selected else Color(0.62, 0.62, 0.62)
		button.scale = Vector2(1.12, 1.12) if selected else Vector2.ONE


# --- UI ---------------------------------------------------------------------------

func _build_reference_text() -> String:
	return "\n".join([
		"PAYS (per coin)",
		"",
		"Pass line  2",
		"Don't pass  2",
		"  (12 pushes)",
		"",
		"Odds behind",
		"  4/10  pay 2:1",
		"  5/9   pay 3:2",
		"  6/8   pay 6:5",
		"  max %dx line" % MAX_ODDS_MULTIPLE,
		"",
		"Field  2",
		"  2 pays 2:1",
		"  12 pays 3:1",
		"  5/6/7/8 lose",
		"",
		"Any 7  5",
		"Any Craps  8",
	])


func _refresh() -> void:
	point_label.text = "COME OUT ROLL" if point == 0 else "POINT: %d" % point

	var labels := {
		"pass": "PASS LINE", "dont_pass": "DON'T PASS", "field": "FIELD",
		"odds": "ODDS", "any_seven": "ANY 7", "any_craps": "ANY CRAPS",
	}
	for key in bet_buttons:
		var button: Button = bet_buttons[key]
		var staked: int = bets[key]
		button.text = labels[key] if staked == 0 else "%s\n%d" % [labels[key], staked]
		var allowed := true
		if key in ["pass", "dont_pass"]:
			allowed = point == 0
		elif key == "odds":
			allowed = point != 0 and bets["pass"] > 0
		button.disabled = is_rolling or not allowed

	clear_button.disabled = is_rolling or point != 0 or _total_staked() <= 0
	roll_button.disabled = is_rolling
	_update_chip_rack()


func _set_controls_enabled(enabled: bool) -> void:
	back_button.disabled = not enabled
	for key in bet_buttons:
		bet_buttons[key].disabled = not enabled
	roll_button.disabled = not enabled
	clear_button.disabled = not enabled


func _on_money_changed(new_amount: int) -> void:
	money_label.text = "Coins: %d" % new_amount


func _play(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()


func _set_bowser(texture: Texture2D) -> void:
	if bowser_sprite and texture:
		bowser_sprite.texture = texture


# --- signal handlers wired up in Craps.tscn -----------------------------------------

func _on_pass_pressed() -> void:
	_place("pass")

func _on_dont_pass_pressed() -> void:
	_place("dont_pass")

func _on_field_pressed() -> void:
	_place("field")

func _on_odds_pressed() -> void:
	_place("odds")

func _on_any_seven_pressed() -> void:
	_place("any_seven")

func _on_any_craps_pressed() -> void:
	_place("any_craps")

func _on_back_button_pressed() -> void:
	if is_rolling:
		return
	get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
