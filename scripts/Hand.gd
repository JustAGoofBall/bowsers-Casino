extends Node2D

var cards: Array = []

func add_card(card) -> void:
	cards.append(card)
	add_child(card)
	
	# Calculate final position
	var card_index = cards.size() - 1
	var spacing = 80
	var final_position = Vector2(card_index * spacing, 0)
	
	# Start card offset to the right
	card.position = final_position + Vector2(200, 0)
	
	# Animate to final position
	await get_tree().process_frame
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "position", final_position, 0.4)

func arrange_cards() -> void:
	var spacing = 80
	for i in range(cards.size()):
		cards[i].position = Vector2(i * spacing, 0)

func get_value() -> int:
	var total = 0
	var aces = 0
	
	for card in cards:
		var value = card.get_value()
		if value == 1:
			aces += 1
			total += 11
		else:
			total += value
	
	# Adjust for aces
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	
	return total

func is_bust() -> bool:
	return get_value() > 21

func is_blackjack() -> bool:
	return cards.size() == 2 and get_value() == 21

func clear_hand() -> void:
	for card in cards:
		card.queue_free()
	cards.clear()

func show_all_cards() -> void:
	for card in cards:
		card.is_face_up = true
