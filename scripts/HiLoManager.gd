extends Node2D

# Higher-or-lower on the next card, with a pot that multiplies on every
# correct call until you cash out or get one wrong.
#
# Odds are read off the live deck rather than hard-coded, so the payout is
# always the true price of the call minus a fixed house edge. That keeps the
# game honest as the deck depletes and means the numbers on the buttons are
# the real ones.

const SUITS := ["H", "D", "C", "S"]
const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const BET_STEPS := [10, 25, 50, 100, 250]
const HOUSE_EDGE := 0.03
const RESHUFFLE_BELOW := 6
const CARD_SCALE := 4.0

var global_manager: Node
var deck: Array = []
var current_card: Dictionary = {}
var pot: float = 0.0
var streak: int = 0
var in_run: bool = false
var is_busy: bool = false
var stake_index: int = 0

var card_textures: Dictionary = {}
var card_back: Texture2D
var bowser_default: Texture2D
var bowser_win: Texture2D
var bowser_lost: Texture2D

@onready var current_sprite: Sprite2D = $Cards/CurrentCard
@onready var next_sprite: Sprite2D = $Cards/NextCard
@onready var higher_button: Button = $CallButtons/HigherButton
@onready var lower_button: Button = $CallButtons/LowerButton
@onready var start_button: Button = $StartButton
@onready var cash_out_button: Button = $CashOutButton
@onready var stake_label: Label = $StakeControls/StakeAmount
@onready var increase_stake: Button = $StakeControls/IncreaseStake
@onready var decrease_stake: Button = $StakeControls/DecreaseStake
@onready var money_label: Label = $MoneyLabel
@onready var pot_label: Label = $PotLabel
@onready var streak_label: Label = $StreakLabel
@onready var deck_label: Label = $DeckLabel
@onready var result_label: Label = $ResultLabel
@onready var bowser_sprite: Sprite2D = $BowserSprite
@onready var back_button: Button = $BackButton
@onready var flip_sound: AudioStreamPlayer = $CardFlip
@onready var win_sound: AudioStreamPlayer = $WinChime
@onready var bwahaha: AudioStreamPlayer = $Bwahaha


func _ready() -> void:
	global_manager = get_node("/root/GlobalManager")
	global_manager.money_changed.connect(_on_money_changed)

	card_back = load("res://assets/pixel/cards/CardBack.png")
	bowser_default = load("res://assets/pixel/boss/BossDefault.png")
	bowser_win = load("res://assets/pixel/boss/BossWin.png")
	bowser_lost = load("res://assets/pixel/boss/BossLost.png")

	next_sprite.texture = card_back
	_shuffle_deck()
	current_card = deck.pop_front()
	current_sprite.texture = _card_texture(current_card)

	_on_money_changed(global_manager.get_money())
	_update_stake_display()
	_refresh()
	result_label.text = "Set your stake and press START."


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if is_busy or key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_UP:
			if not higher_button.disabled:
				_on_higher_pressed()
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			if not lower_button.disabled:
				_on_lower_pressed()
			get_viewport().set_input_as_handled()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if in_run:
				_on_cash_out_pressed()
			else:
				_on_start_pressed()
			get_viewport().set_input_as_handled()


# --- deck ---------------------------------------------------------------------

func _shuffle_deck() -> void:
	deck.clear()
	for suit in SUITS:
		for rank in RANKS:
			deck.append({"suit": suit, "rank": rank})
	deck.shuffle()


func _value(card: Dictionary) -> int:
	match card["rank"]:
		"J": return 11
		"Q": return 12
		"K": return 13
		"A": return 14
	return int(card["rank"])


func _card_texture(card: Dictionary) -> Texture2D:
	var card_name: String = str(card["suit"]) + str(card["rank"])
	if not card_name in card_textures:
		card_textures[card_name] = load("res://assets/pixel/cards/" + card_name + ".png")
	return card_textures[card_name]


func _counts() -> Dictionary:
	var v := _value(current_card)
	var higher := 0
	var lower := 0
	var tied := 0
	for card in deck:
		var cv := _value(card)
		if cv > v:
			higher += 1
		elif cv < v:
			lower += 1
		else:
			tied += 1
	return {"higher": higher, "lower": lower, "tied": tied}


func _multiplier(win_count: int, lose_count: int) -> float:
	# A tie pushes, so the call only resolves against cards that are strictly
	# higher or strictly lower. Fair price is resolving/winning; the edge is
	# what the house keeps.
	var resolving := win_count + lose_count
	if win_count <= 0 or resolving <= 0:
		return 0.0
	return (1.0 - HOUSE_EDGE) * float(resolving) / float(win_count)


# --- round flow ----------------------------------------------------------------

func _on_start_pressed() -> void:
	if is_busy or in_run:
		return

	var stake := current_stake()
	if global_manager.get_money() < stake:
		result_label.text = "Not enough coins for a %d stake!" % stake
		return

	global_manager.remove_money(stake)
	global_manager.increment_games_played()

	pot = float(stake)
	streak = 0
	in_run = true
	_set_bowser(bowser_default)
	result_label.text = "Higher or lower than %s?" % _rank_name(current_card)
	_refresh()


func _on_higher_pressed() -> void:
	await _call_it(true)


func _on_lower_pressed() -> void:
	await _call_it(false)


func _call_it(called_higher: bool) -> void:
	if is_busy or not in_run or deck.is_empty():
		return

	var counts := _counts()
	var win_count: int = counts["higher"] if called_higher else counts["lower"]
	var lose_count: int = counts["lower"] if called_higher else counts["higher"]
	var mult := _multiplier(win_count, lose_count)
	if mult <= 0.0:
		return  # the call cannot win; the button should already be disabled

	is_busy = true
	_set_controls_enabled(false)

	var drawn: Dictionary = deck.pop_front()
	await _flip_next(drawn)

	var old_value := _value(current_card)
	var new_value := _value(drawn)
	current_card = drawn
	current_sprite.texture = _card_texture(current_card)
	next_sprite.texture = card_back

	if new_value == old_value:
		result_label.text = "%s - a tie pushes. Carry on." % _rank_name(drawn)
		_set_bowser(bowser_default)
	elif (new_value > old_value) == called_higher:
		pot *= mult
		streak += 1
		result_label.text = "%s - correct! Pot x%.2f." % [_rank_name(drawn), mult]
		_set_bowser(bowser_lost)
		_play(win_sound)
	else:
		result_label.text = "%s - wrong. You lose the pot." % _rank_name(drawn)
		pot = 0.0
		streak = 0
		in_run = false
		_set_bowser(bowser_win)
		_play(bwahaha)

	# Reshuffle only after the call has resolved, so the odds shown on the
	# buttons always describe the deck the next card is actually drawn from.
	if deck.size() < RESHUFFLE_BELOW:
		_shuffle_deck()

	is_busy = false
	_set_controls_enabled(true)
	_refresh()


func _on_cash_out_pressed() -> void:
	if is_busy or not in_run:
		return

	var winnings := roundi(pot)
	global_manager.add_money(winnings)
	result_label.text = "Cashed out %d coins after %d correct." % [winnings, streak]
	_set_bowser(bowser_lost)
	_play(win_sound)

	pot = 0.0
	streak = 0
	in_run = false
	_refresh()


func _flip_next(card: Dictionary) -> void:
	flip_sound.pitch_scale = randf_range(0.92, 1.12)
	_play(flip_sound)
	var closing := create_tween()
	closing.tween_property(next_sprite, "scale:x", 0.0, 0.08)
	await closing.finished
	next_sprite.texture = _card_texture(card)
	var opening := create_tween()
	opening.tween_property(next_sprite, "scale:x", CARD_SCALE, 0.08)
	await opening.finished
	await get_tree().create_timer(0.35).timeout


# --- UI --------------------------------------------------------------------------

func current_stake() -> int:
	return int(BET_STEPS[stake_index])


func _rank_name(card: Dictionary) -> String:
	return str(card["rank"])


func _refresh() -> void:
	var counts := _counts()
	var hi_mult := _multiplier(counts["higher"], counts["lower"])
	var lo_mult := _multiplier(counts["lower"], counts["higher"])

	higher_button.text = ("HIGHER  x%.2f" % hi_mult) if hi_mult > 0.0 else "HIGHER  --"
	lower_button.text = ("LOWER  x%.2f" % lo_mult) if lo_mult > 0.0 else "LOWER  --"
	higher_button.disabled = not in_run or is_busy or hi_mult <= 0.0
	lower_button.disabled = not in_run or is_busy or lo_mult <= 0.0

	start_button.visible = not in_run
	cash_out_button.visible = in_run
	start_button.disabled = is_busy
	cash_out_button.disabled = is_busy or pot <= 0.0

	pot_label.text = "Pot: %d" % roundi(pot)
	streak_label.text = "Streak: %d" % streak
	deck_label.text = "Cards left: %d   (%d higher / %d lower / %d tie)" % [
		deck.size(), counts["higher"], counts["lower"], counts["tied"]
	]
	_update_stake_display()


func _set_controls_enabled(enabled: bool) -> void:
	back_button.disabled = not enabled
	var can_stake: bool = enabled and not in_run
	increase_stake.disabled = not can_stake
	decrease_stake.disabled = not can_stake


func _update_stake_display() -> void:
	stake_label.text = str(current_stake())
	start_button.text = "START (%d coins)" % current_stake()
	increase_stake.disabled = in_run or is_busy
	decrease_stake.disabled = in_run or is_busy


func _on_increase_stake_pressed() -> void:
	if is_busy or in_run:
		return
	stake_index = mini(stake_index + 1, BET_STEPS.size() - 1)
	_update_stake_display()


func _on_decrease_stake_pressed() -> void:
	if is_busy or in_run:
		return
	stake_index = maxi(stake_index - 1, 0)
	_update_stake_display()


func _on_money_changed(new_amount: int) -> void:
	money_label.text = "Coins: %d" % new_amount


func _play(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()


func _set_bowser(texture: Texture2D) -> void:
	if bowser_sprite and texture:
		bowser_sprite.texture = texture


func _on_back_button_pressed() -> void:
	if is_busy:
		return
	get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
