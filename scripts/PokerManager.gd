extends Node2D

# Poker hand rankings
enum HandRank {
	HIGH_CARD,
	PAIR,
	TWO_PAIR,
	THREE_OF_A_KIND,
	STRAIGHT,
	FLUSH,
	FULL_HOUSE,
	FOUR_OF_A_KIND,
	STRAIGHT_FLUSH,
	ROYAL_FLUSH
}

# Payout multipliers for each hand
const PAYOUTS = {
	HandRank.PAIR: 1,
	HandRank.TWO_PAIR: 2,
	HandRank.THREE_OF_A_KIND: 3,
	HandRank.STRAIGHT: 4,
	HandRank.FLUSH: 6,
	HandRank.FULL_HOUSE: 9,
	HandRank.FOUR_OF_A_KIND: 25,
	HandRank.STRAIGHT_FLUSH: 50,
	HandRank.ROYAL_FLUSH: 250
}

var global_manager: Node
var deck: Array = []
var hand: Array = []
var held_cards: Array = [false, false, false, false, false]
var current_bet: int = 10
var game_state: String = "betting"  # betting, holding, complete

@onready var card_sprites: Array = [
	$CardsContainer/Card1,
	$CardsContainer/Card2,
	$CardsContainer/Card3,
	$CardsContainer/Card4,
	$CardsContainer/Card5
]

@onready var hold_buttons: Array = [
	$HoldButtons/Hold1,
	$HoldButtons/Hold2,
	$HoldButtons/Hold3,
	$HoldButtons/Hold4,
	$HoldButtons/Hold5
]

@onready var deal_button: Button = $DealButton
@onready var draw_button: Button = $DrawButton
@onready var bet_label: Label = $BetControls/BetAmount
@onready var result_label: Label = $ResultLabel
@onready var increase_bet: Button = $BetControls/IncreaseBet
@onready var decrease_bet: Button = $BetControls/DecreaseBet

func _ready() -> void:
	global_manager = get_node("/root/GlobalManager")
	_update_bet_display()
	_hide_hold_buttons()
	draw_button.visible = false

func _initialize_deck() -> void:
	deck.clear()
	var suits = ["H", "D", "C", "S"]
	var ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
	
	for suit in suits:
		for rank in ranks:
			deck.append({"suit": suit, "rank": rank})
	
	deck.shuffle()

func _draw_card() -> Dictionary:
	if deck.is_empty():
		_initialize_deck()
	return deck.pop_front()

func _on_deal_button_pressed() -> void:
	if global_manager.get_money() < current_bet:
		result_label.text = "Not enough money!"
		return
	
	# Deduct bet
	global_manager.remove_money(current_bet)
	global_manager.increment_games_played()
	
	# Reset game
	hand.clear()
	held_cards = [false, false, false, false, false]
	result_label.text = ""
	
	# Initialize and deal cards
	_initialize_deck()
	for i in range(5):
		hand.append(_draw_card())
		_display_card(i, hand[i])
	
	# Update UI
	game_state = "holding"
	deal_button.visible = false
	draw_button.visible = true
	_show_hold_buttons()
	_update_hold_buttons()

func _on_draw_button_pressed() -> void:
	# Replace non-held cards
	for i in range(5):
		if not held_cards[i]:
			hand[i] = _draw_card()
			_display_card(i, hand[i])
	
	# Evaluate hand
	var hand_result = _evaluate_hand()
	_show_result(hand_result)
	
	# Update UI
	game_state = "complete"
	draw_button.visible = false
	deal_button.visible = true
	_hide_hold_buttons()

func _on_hold_button_pressed(index: int) -> void:
	if game_state != "holding":
		return
	
	held_cards[index] = !held_cards[index]
	_update_hold_buttons()

func _display_card(index: int, card: Dictionary) -> void:
	var card_sprite = card_sprites[index]
	var card_name = card["suit"] + card["rank"]
	var texture = load("res://assets/cards/" + card_name + ".png")
	if texture:
		card_sprite.texture = texture

func _show_hold_buttons() -> void:
	for button in hold_buttons:
		button.visible = true

func _hide_hold_buttons() -> void:
	for button in hold_buttons:
		button.visible = false

func _update_hold_buttons() -> void:
	for i in range(5):
		if held_cards[i]:
			hold_buttons[i].text = "HELD"
		else:
			hold_buttons[i].text = "HOLD"

func _evaluate_hand() -> HandRank:
	var ranks = []
	var suits = []
	
	for card in hand:
		ranks.append(_get_rank_value(card["rank"]))
		suits.append(card["suit"])
	
	ranks.sort()
	
	var is_flush = _check_flush(suits)
	var is_straight = _check_straight(ranks)
	var rank_counts = _count_ranks(ranks)
	
	# Check for hands
	if is_straight and is_flush:
		if ranks[0] == 10:
			return HandRank.ROYAL_FLUSH
		return HandRank.STRAIGHT_FLUSH
	
	if 4 in rank_counts.values():
		return HandRank.FOUR_OF_A_KIND
	
	if 3 in rank_counts.values() and 2 in rank_counts.values():
		return HandRank.FULL_HOUSE
	
	if is_flush:
		return HandRank.FLUSH
	
	if is_straight:
		return HandRank.STRAIGHT
	
	if 3 in rank_counts.values():
		return HandRank.THREE_OF_A_KIND
	
	var pairs = rank_counts.values().count(2)
	if pairs == 2:
		return HandRank.TWO_PAIR
	
	if pairs == 1:
		return HandRank.PAIR
	
	return HandRank.HIGH_CARD

func _get_rank_value(rank: String) -> int:
	match rank:
		"2": return 2
		"3": return 3
		"4": return 4
		"5": return 5
		"6": return 6
		"7": return 7
		"8": return 8
		"9": return 9
		"10": return 10
		"J": return 11
		"Q": return 12
		"K": return 13
		"A": return 14
	return 0

func _check_flush(suits: Array) -> bool:
	return suits[0] == suits[1] and suits[1] == suits[2] and suits[2] == suits[3] and suits[3] == suits[4]

func _check_straight(ranks: Array) -> bool:
	for i in range(4):
		if ranks[i + 1] != ranks[i] + 1:
			# Check for Ace-low straight (A-2-3-4-5)
			if ranks == [2, 3, 4, 5, 14]:
				return true
			return false
	return true

func _count_ranks(ranks: Array) -> Dictionary:
	var counts = {}
	for rank in ranks:
		if rank in counts:
			counts[rank] += 1
		else:
			counts[rank] = 1
	return counts

func _show_result(hand_rank: HandRank) -> void:
	var hand_name = _get_hand_name(hand_rank)
	
	if hand_rank in PAYOUTS:
		var winnings = current_bet * PAYOUTS[hand_rank]
		global_manager.add_money(winnings)
		result_label.text = hand_name + "! Win " + str(winnings) + " coins!"
	else:
		result_label.text = hand_name + " - No win"

func _get_hand_name(rank: HandRank) -> String:
	match rank:
		HandRank.ROYAL_FLUSH: return "ROYAL FLUSH"
		HandRank.STRAIGHT_FLUSH: return "STRAIGHT FLUSH"
		HandRank.FOUR_OF_A_KIND: return "FOUR OF A KIND"
		HandRank.FULL_HOUSE: return "FULL HOUSE"
		HandRank.FLUSH: return "FLUSH"
		HandRank.STRAIGHT: return "STRAIGHT"
		HandRank.THREE_OF_A_KIND: return "THREE OF A KIND"
		HandRank.TWO_PAIR: return "TWO PAIR"
		HandRank.PAIR: return "PAIR"
		_: return "HIGH CARD"

func _on_increase_bet_pressed() -> void:
	if current_bet < 100:
		current_bet += 10
		_update_bet_display()

func _on_decrease_bet_pressed() -> void:
	if current_bet > 10:
		current_bet -= 10
		_update_bet_display()

func _update_bet_display() -> void:
	bet_label.text = str(current_bet)
	deal_button.text = "DEAL (" + str(current_bet) + " coins)"

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
