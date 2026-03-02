extends Node

const CardScene = preload("res://scenes/Card.tscn")

var cards: Array = []

func _ready() -> void:
	initialize_deck()
	shuffle_deck()

func initialize_deck() -> void:
	cards.clear()
	for suit in 4:  # 4 suits
		for rank in range(1, 14):  # Ranks 1-13 (Ace through King)
			var card = CardScene.instantiate()
			card.suit = suit
			card.rank = rank
			cards.append(card)

func shuffle_deck() -> void:
	cards.shuffle()

func draw_card():
	if cards.is_empty():
		initialize_deck()
		shuffle_deck()
	return cards.pop_back()

func get_remaining_cards() -> int:
	return cards.size()
