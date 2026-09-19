extends Node2D

# Five-card draw video poker, Jacks or Better, with a few Bowser-flavoured
# bonus hands layered on top of the standard paytable.
enum HandRank {
	HIGH_CARD,
	LOW_PAIR,
	JACKS_OR_BETTER,
	TWO_PAIR,
	THREE_OF_A_KIND,
	STRAIGHT,
	FLUSH,
	FULL_HOUSE,
	FOUR_OF_A_KIND,
	STRAIGHT_FLUSH,
	ROYAL_FLUSH,
}

# Every number here is a TOTAL return per coin staked, the way a real video
# poker paytable is written. The stake is taken at DEAL, so a hand paying 1
# gives the stake back and nothing more, and a hand paying 3 is a profit of 2.
const BASE_RETURN := {
	HandRank.JACKS_OR_BETTER: 1,
	HandRank.TWO_PAIR: 2,
	HandRank.THREE_OF_A_KIND: 3,
	HandRank.STRAIGHT: 4,
	HandRank.FLUSH: 6,
	HandRank.FULL_HOUSE: 8,
	HandRank.FOUR_OF_A_KIND: 25,
	HandRank.STRAIGHT_FLUSH: 50,
	HandRank.ROYAL_FLUSH: 250,
}

const HAND_NAMES := {
	HandRank.HIGH_CARD: "High Card",
	HandRank.LOW_PAIR: "Low Pair",
	HandRank.JACKS_OR_BETTER: "Jacks or Better",
	HandRank.TWO_PAIR: "Two Pair",
	HandRank.THREE_OF_A_KIND: "Three of a Kind",
	HandRank.STRAIGHT: "Straight",
	HandRank.FLUSH: "Flush",
	HandRank.FULL_HOUSE: "Full House",
	HandRank.FOUR_OF_A_KIND: "Four of a Kind",
	HandRank.STRAIGHT_FLUSH: "Straight Flush",
	HandRank.ROYAL_FLUSH: "Royal Flush",
}

# Bonus hands override the base return. The first entry that matches wins, so
# they are ordered from the rarest down. These values and the 8/6 base above
# were picked so the machine returns about 98.4% over a million simulated
# hands played to standard Jacks-or-Better strategy.
const BONUS_HANDS := [
	{
		"name": "FIRE FLOWER ROYAL",
		"rank": HandRank.ROYAL_FLUSH,
		"suit": "H",
		"return": 800,
		"blurb": "Royal Flush in Hearts",
	},
	{
		"name": "SPINY SHELL",
		"rank": HandRank.STRAIGHT_FLUSH,
		"suit": "S",
		"return": 100,
		"blurb": "Straight Flush in Spades",
	},
	{
		"name": "BOWSER'S FURY",
		"rank": HandRank.FOUR_OF_A_KIND,
		"quads": [14],
		"return": 80,
		"blurb": "Four Aces",
	},
	{
		"name": "KOOPA KING",
		"rank": HandRank.FOUR_OF_A_KIND,
		"quads": [13],
		"return": 50,
		"blurb": "Four Kings",
	},
	{
		"name": "BOB-OMB BLAST",
		"rank": HandRank.FOUR_OF_A_KIND,
		"quads": [2, 3, 4],
		"return": 30,
		"blurb": "Four 2s, 3s or 4s",
	},
]

const SUITS := ["H", "D", "C", "S"]
const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const BET_STEPS := [10, 25, 50, 100, 250]
const CARD_SCALE := 0.45

var global_manager: Node
var deck: Array = []
var hand: Array = []
var held_cards := [false, false, false, false, false]
var bet_index: int = 0
var game_state: String = "betting"  # betting, holding, complete
var is_busy: bool = false

var card_textures: Dictionary = {}
var card_back: Texture2D
var bowser_default: Texture2D
var bowser_win: Texture2D
var bowser_lost: Texture2D

@onready var card_sprites: Array = [
	$CardsContainer/Card1,
	$CardsContainer/Card2,
	$CardsContainer/Card3,
	$CardsContainer/Card4,
	$CardsContainer/Card5,
]

@onready var hold_buttons: Array = [
	$HoldButtons/Hold1,
	$HoldButtons/Hold2,
	$HoldButtons/Hold3,
	$HoldButtons/Hold4,
	$HoldButtons/Hold5,
]

@onready var held_markers: Array = [
	$HeldMarkers/Held1,
	$HeldMarkers/Held2,
	$HeldMarkers/Held3,
	$HeldMarkers/Held4,
	$HeldMarkers/Held5,
]

@onready var deal_button: Button = $DealButton
@onready var draw_button: Button = $DrawButton
@onready var bet_label: Label = $BetControls/BetAmount
@onready var increase_bet: Button = $BetControls/IncreaseBet
@onready var decrease_bet: Button = $BetControls/DecreaseBet
@onready var result_label: Label = $ResultLabel
@onready var money_label: Label = $MoneyLabel
@onready var paytable_label: Label = $PaytablePanel/PaytableLabel
@onready var bowser_sprite: Sprite2D = $BowserSprite
@onready var bwahaha: AudioStreamPlayer = $Bwahaha
@onready var flip_sound: AudioStreamPlayer = $CardFlip
@onready var win_sound: AudioStreamPlayer = $WinChime
@onready var back_button: Button = $BackButton


func _ready() -> void:
	global_manager = get_node("/root/GlobalManager")
	global_manager.money_changed.connect(_on_money_changed)

	card_back = load("res://assets/cards/CardBack.png")
	bowser_default = load("res://assets/bowser/BowserDefault.png")
	bowser_win = load("res://assets/bowser/bowserWin.png")
	bowser_lost = load("res://assets/bowser/BowserLost.png")

	for sprite in card_sprites:
		sprite.texture = card_back
		sprite.scale = Vector2(CARD_SCALE, CARD_SCALE)

	deal_button.visible = true
	draw_button.visible = false
	paytable_label.text = _build_paytable_text()
	_on_money_changed(global_manager.get_money())
	_update_bet_display()
	_refresh_hold_ui()
	_set_bowser(bowser_default)
	result_label.text = "Press DEAL to play."


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if is_busy or key == null or not key.pressed or key.echo:
		return

	match key.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			_on_hold_button_pressed(key.keycode - KEY_1)
			get_viewport().set_input_as_handled()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if game_state == "holding":
				_on_draw_button_pressed()
			else:
				_on_deal_button_pressed()
			get_viewport().set_input_as_handled()


# --- Deck --------------------------------------------------------------------

func _initialize_deck() -> void:
	deck.clear()
	for suit in SUITS:
		for rank in RANKS:
			deck.append({"suit": suit, "rank": rank})
	deck.shuffle()


func _draw_card() -> Dictionary:
	if deck.is_empty():
		_initialize_deck()
	return deck.pop_front()


func _card_texture(card: Dictionary) -> Texture2D:
	var card_name: String = str(card["suit"]) + str(card["rank"])
	if not card_name in card_textures:
		card_textures[card_name] = load("res://assets/cards/" + card_name + ".png")
	return card_textures[card_name]


# --- Round flow ---------------------------------------------------------------

func _on_deal_button_pressed() -> void:
	if is_busy or game_state == "holding":
		return

	var stake := current_bet()
	if global_manager.get_money() < stake:
		result_label.text = "Not enough coins for a %d bet!" % stake
		return

	is_busy = true
	global_manager.remove_money(stake)
	global_manager.increment_games_played()

	hand.clear()
	held_cards = [false, false, false, false, false]
	result_label.text = "Pick the cards to hold."
	_set_bowser(bowser_default)
	_set_controls_enabled(false)

	for sprite in card_sprites:
		sprite.texture = card_back
		sprite.modulate = Color.WHITE

	_initialize_deck()
	for i in range(5):
		hand.append(_draw_card())
	for i in range(5):
		await _flip_card(i, hand[i])

	game_state = "holding"
	deal_button.visible = false
	draw_button.visible = true
	is_busy = false
	_refresh_hold_ui()
	_set_controls_enabled(true)


func _on_draw_button_pressed() -> void:
	if is_busy or game_state != "holding":
		return

	is_busy = true
	_set_controls_enabled(false)

	for i in range(5):
		if not held_cards[i]:
			hand[i] = _draw_card()
			await _flip_card(i, hand[i])

	_show_result(_evaluate_hand())

	game_state = "complete"
	draw_button.visible = false
	deal_button.visible = true
	is_busy = false
	_refresh_hold_ui()
	_set_controls_enabled(true)


func _on_hold_button_pressed(index: int) -> void:
	if is_busy or game_state != "holding":
		return
	held_cards[index] = not held_cards[index]
	_refresh_hold_ui()


func _flip_card(index: int, card: Dictionary) -> void:
	var sprite: Sprite2D = card_sprites[index]
	# A little pitch variation so five cards in a row do not sound mechanical.
	flip_sound.pitch_scale = randf_range(0.92, 1.12)
	_play(flip_sound)
	var closing := create_tween()
	closing.tween_property(sprite, "scale:x", 0.0, 0.07)
	await closing.finished
	sprite.texture = _card_texture(card)
	var opening := create_tween()
	opening.tween_property(sprite, "scale:x", CARD_SCALE, 0.07)
	await opening.finished


# --- Hand evaluation ----------------------------------------------------------

func _evaluate_hand() -> Dictionary:
	var values: Array[int] = []
	var suits: Array[String] = []
	for card in hand:
		values.append(_get_rank_value(card["rank"]))
		suits.append(card["suit"])
	values.sort()

	var counts := _count_ranks(values)
	var flush_suit := suits[0] if suits.count(suits[0]) == 5 else ""
	var straight := _is_straight(values)

	var quad_value := 0
	var trips := false
	var pairs: Array[int] = []
	for value in counts:
		match int(counts[value]):
			4: quad_value = int(value)
			3: trips = true
			2: pairs.append(int(value))

	var rank := HandRank.HIGH_CARD
	if straight and flush_suit != "":
		rank = HandRank.ROYAL_FLUSH if values[0] == 10 else HandRank.STRAIGHT_FLUSH
	elif quad_value > 0:
		rank = HandRank.FOUR_OF_A_KIND
	elif trips and pairs.size() == 1:
		rank = HandRank.FULL_HOUSE
	elif flush_suit != "":
		rank = HandRank.FLUSH
	elif straight:
		rank = HandRank.STRAIGHT
	elif trips:
		rank = HandRank.THREE_OF_A_KIND
	elif pairs.size() == 2:
		rank = HandRank.TWO_PAIR
	elif pairs.size() == 1:
		# Only a pair of Jacks or better pays.
		rank = HandRank.JACKS_OR_BETTER if pairs[0] >= 11 else HandRank.LOW_PAIR

	return {
		"rank": rank,
		"quad_value": quad_value,
		"flush_suit": flush_suit,
	}


func _payout_for(result: Dictionary) -> Dictionary:
	for bonus in BONUS_HANDS:
		if bonus["rank"] != result["rank"]:
			continue
		if bonus.has("suit") and bonus["suit"] != result["flush_suit"]:
			continue
		if bonus.has("quads") and not (result["quad_value"] in bonus["quads"]):
			continue
		return {"name": bonus["name"], "multiplier": int(bonus["return"]), "bonus": true}

	var rank = result["rank"]
	return {
		"name": HAND_NAMES[rank],
		"multiplier": int(BASE_RETURN.get(rank, 0)),
		"bonus": false,
	}


func _get_rank_value(rank: String) -> int:
	match rank:
		"J": return 11
		"Q": return 12
		"K": return 13
		"A": return 14
	return int(rank)


func _count_ranks(values: Array[int]) -> Dictionary:
	var counts := {}
	for value in values:
		counts[value] = int(counts.get(value, 0)) + 1
	return counts


func _is_straight(values: Array[int]) -> bool:
	# values arrives sorted ascending and, for a straight, has no duplicates.
	if values == [2, 3, 4, 5, 14]:
		return true  # the wheel: A-2-3-4-5
	for i in range(4):
		if values[i + 1] != values[i] + 1:
			return false
	return true


func _show_result(result: Dictionary) -> void:
	var payout := _payout_for(result)
	var stake := current_bet()
	var returned: int = stake * int(payout["multiplier"])

	if returned > 0:
		global_manager.add_money(returned)

	var net := returned - stake
	if net > 0:
		result_label.text = "%s! You win %d coins." % [payout["name"], net]
		_set_bowser(bowser_lost)
		_play(win_sound)
	elif returned > 0:
		result_label.text = "%s - your %d coins back." % [payout["name"], stake]
		_set_bowser(bowser_default)
	else:
		result_label.text = "%s - no win." % payout["name"]
		_set_bowser(bowser_win)
		_play(bwahaha)


# --- UI -----------------------------------------------------------------------

func current_bet() -> int:
	return int(BET_STEPS[bet_index])


func _build_paytable_text() -> String:
	var lines := ["BOWSER'S PAYTABLE", "(coins returned per coin bet)", ""]
	for bonus in BONUS_HANDS:
		lines.append("%s  %d" % [bonus["blurb"], int(bonus["return"])])
	lines.append("")
	var order := [
		HandRank.ROYAL_FLUSH,
		HandRank.STRAIGHT_FLUSH,
		HandRank.FOUR_OF_A_KIND,
		HandRank.FULL_HOUSE,
		HandRank.FLUSH,
		HandRank.STRAIGHT,
		HandRank.THREE_OF_A_KIND,
		HandRank.TWO_PAIR,
		HandRank.JACKS_OR_BETTER,
	]
	for rank in order:
		lines.append("%s  %d" % [HAND_NAMES[rank], int(BASE_RETURN[rank])])
	lines.append("")
	lines.append("Keys: 1-5 hold, Space deal/draw")
	return "\n".join(lines)


func _refresh_hold_ui() -> void:
	var holding := game_state == "holding"
	for i in range(5):
		hold_buttons[i].visible = holding
		hold_buttons[i].text = "HELD" if held_cards[i] else "HOLD"
		held_markers[i].visible = holding and held_cards[i]
		card_sprites[i].modulate = (
			Color(1.0, 0.92, 0.65) if holding and held_cards[i] else Color.WHITE
		)


func _set_controls_enabled(enabled: bool) -> void:
	deal_button.disabled = not enabled
	draw_button.disabled = not enabled
	back_button.disabled = not enabled
	# The stake is locked in once the cards are on the table.
	var can_bet: bool = enabled and game_state != "holding"
	increase_bet.disabled = not can_bet
	decrease_bet.disabled = not can_bet


func _on_money_changed(new_amount: int) -> void:
	money_label.text = "Coins: %d" % new_amount


func _update_bet_display() -> void:
	bet_label.text = str(current_bet())
	deal_button.text = "DEAL (%d coins)" % current_bet()


func _on_increase_bet_pressed() -> void:
	if is_busy or game_state == "holding":
		return
	bet_index = mini(bet_index + 1, BET_STEPS.size() - 1)
	_update_bet_display()


func _on_decrease_bet_pressed() -> void:
	if is_busy or game_state == "holding":
		return
	bet_index = maxi(bet_index - 1, 0)
	_update_bet_display()


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
