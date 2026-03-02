extends Node


enum GameState { BETTING, DEALING, PLAYER_TURN, DEALER_TURN, GAME_OVER }

var deck: Node
var player_hand: Node2D
var dealer_hand: Node2D
var current_state: GameState = GameState.BETTING
var global_manager: Node
var bwahaha_sound: AudioStreamPlayer
var bowser_sprite: Sprite2D
var bowser_flame_sprite: Sprite2D

var current_bet: int = 0

# Bowser textures
var bowser_default: Texture2D
var bowser_win: Texture2D
var bowser_lose: Texture2D
var bowser_tie: Texture2D

signal game_state_changed(new_state: GameState)
signal player_money_changed(amount: int)
signal hand_result(message: String)

func _ready() -> void:
	global_manager = get_node("/root/GlobalManager")
	deck = get_node("Deck")
	player_hand = get_node("PlayerHand")
	dealer_hand = get_node("DealerHand")
	bowser_sprite = get_node("../Bowser")
	bowser_flame_sprite = get_node("../BowserFlameEffect")
	
	# Load Bowser textures
	bowser_default = load("res://assets/bowser/BowserDefault.png")
	bowser_win = load("res://assets/bowser/bowserWin.png")
	bowser_lose = load("res://assets/bowser/BowserLost.png")
	bowser_tie = load("res://assets/bowser/BowserTie.png")
	
	# Normalize Bowser sprite sizes
	_normalize_bowser_size()
	
	# Setup audio
	_setup_audio()
	
	# Initialize UI with global money
	player_money_changed.emit(global_manager.get_money())

var player_money: int:
	get:
		return global_manager.get_money() if global_manager else 1000

func _normalize_bowser_size() -> void:
	# Get the reference size from the default texture
	var reference_size = bowser_default.get_size()
	
	# Store the original scale values
	var base_scale_x = 0.7
	var base_scale_y = 0.85
	
	# Calculate target display size
	var _target_width = reference_size.x * base_scale_x
	var _target_height = reference_size.y * base_scale_y
	
	# This function will be called when changing textures to maintain consistent size
	pass

func _animate_flame_visibility(show: bool) -> void:
	if not bowser_flame_sprite:
		return
	
	if show:
		bowser_flame_sprite.visible = true
		bowser_flame_sprite.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(bowser_flame_sprite, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	else:
		if bowser_flame_sprite.visible:
			var tween = create_tween()
			tween.tween_property(bowser_flame_sprite, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
			await tween.finished
			bowser_flame_sprite.visible = false
		else:
			bowser_flame_sprite.visible = false

func _setup_audio() -> void:
	# Create AudioStreamPlayer for Bwahaha sound
	bwahaha_sound = AudioStreamPlayer.new()
	add_child(bwahaha_sound)
	var sound = load("res://assets/sounds/Bwahaha.wav")
	if sound:
		bwahaha_sound.stream = sound
		bwahaha_sound.volume_db = 0.0
		bwahaha_sound.bus = "Master"
		print("Bwahaha sound loaded successfully")
	else:
		print("Failed to load Bwahaha sound")

func _set_bowser_texture(sprite: Sprite2D, texture: Texture2D, animate: bool = true) -> void:
	if not sprite or not texture:
		return
	
	# Calculate scale to maintain consistent size
	var reference_size = bowser_default.get_size()
	var texture_size = texture.get_size()
	
	var scale_x = 0.7 * (reference_size.x / texture_size.x)
	var scale_y = 0.85 * (reference_size.y / texture_size.y)
	var target_scale = Vector2(scale_x, scale_y)
	
	if animate:
		# Animate the transition
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Shrink and fade out
		tween.tween_property(sprite, "scale", target_scale * 0.8, 0.15).set_ease(Tween.EASE_IN)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
		
		# Wait for shrink to complete, then change texture
		await tween.finished
		sprite.texture = texture
		
		# Create new tween for expanding back
		var tween2 = create_tween()
		tween2.set_parallel(true)
		
		# Grow and fade in
		tween2.tween_property(sprite, "scale", target_scale, 0.15).set_ease(Tween.EASE_OUT)
		tween2.tween_property(sprite, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
	else:
		# Instant change without animation
		sprite.texture = texture
		sprite.scale = target_scale
		sprite.modulate.a = 1.0

func start_new_round(bet: int) -> void:
	if bet > global_manager.get_money():
		return
	
	# Reset Bowser to default expression
	_set_bowser_texture(bowser_sprite, bowser_default, false)  # No animation at round start
	if bowser_flame_sprite:
		_animate_flame_visibility(false)
	
	current_bet = bet
	global_manager.remove_money(bet)
	player_money_changed.emit(global_manager.get_money())
	global_manager.increment_games_played()
	
	player_hand.clear_hand()
	dealer_hand.clear_hand()
	
	# Deal initial cards
	deal_card(player_hand, true)
	deal_card(dealer_hand, true)
	deal_card(player_hand, true)
	deal_card(dealer_hand, false) # Dealer's second card is face down
	
	# Check for blackjack
	if player_hand.is_blackjack():
		end_round()
	else:
		current_state = GameState.PLAYER_TURN
		game_state_changed.emit(current_state)

func deal_card(hand: Node2D, face_up: bool) -> void:
	var card = deck.draw_card()
	card.is_face_up = face_up
	hand.add_card(card)

func player_hit() -> void:
	if current_state != GameState.PLAYER_TURN:
		return
	
	deal_card(player_hand, true)
	
	if player_hand.is_bust():
		end_round()

func player_stand() -> void:
	if current_state != GameState.PLAYER_TURN:
		return
	
	current_state = GameState.DEALER_TURN
	game_state_changed.emit(current_state)
	dealer_turn()

func dealer_turn() -> void:
	# Reveal dealer's hidden card
	dealer_hand.show_all_cards()
	
	await get_tree().create_timer(0.5).timeout
	
	# Dealer must hit on 16 or less, stand on 17 or more
	while dealer_hand.get_value() < 17:
		deal_card(dealer_hand, true)
		await get_tree().create_timer(0.5).timeout
	
	end_round()

func end_round() -> void:
	current_state = GameState.GAME_OVER
	game_state_changed.emit(current_state)
	
	var player_value = player_hand.get_value()
	var dealer_value = dealer_hand.get_value()
	var result_message = ""
	
	if player_hand.is_blackjack() and not dealer_hand.is_blackjack():
		# Blackjack pays 3:2
		var winnings = int(current_bet * 2.5)
		global_manager.add_money(winnings)
		result_message = "BLACKJACK! You win $%d!" % (winnings - current_bet)
		_set_bowser_texture(bowser_sprite, bowser_lose)
		_animate_flame_visibility(false)
	elif dealer_hand.is_blackjack() and not player_hand.is_blackjack():
		# Dealer wins with blackjack - play Bwahaha sound
		print("Dealer blackjack! Playing Bwahaha sound...")
		if bwahaha_sound and bwahaha_sound.stream:
			bwahaha_sound.play()
			print("Sound playing: ", bwahaha_sound.playing)
		else:
			print("Sound not available")
		result_message = "Dealer BLACKJACK! You lose $%d" % current_bet
		_set_bowser_texture(bowser_sprite, bowser_default)
		_set_bowser_texture(bowser_flame_sprite, bowser_win)
		_animate_flame_visibility(true)
	elif player_hand.is_bust():
		result_message = "BUST! You lose $%d" % current_bet
		_set_bowser_texture(bowser_sprite, bowser_default)
		_set_bowser_texture(bowser_flame_sprite, bowser_win)
		_animate_flame_visibility(true)
	elif dealer_hand.is_bust():
		global_manager.add_money(current_bet * 2)
		result_message = "Dealer busts! You win $%d!" % current_bet
		_set_bowser_texture(bowser_sprite, bowser_lose)
		_animate_flame_visibility(false)
	elif player_value > dealer_value:
		global_manager.add_money(current_bet * 2)
		result_message = "You win $%d!" % current_bet
		_set_bowser_texture(bowser_sprite, bowser_lose)
		_animate_flame_visibility(false)
	elif player_value < dealer_value:
		result_message = "Dealer wins. You lose $%d" % current_bet
		_set_bowser_texture(bowser_sprite, bowser_default)
		_set_bowser_texture(bowser_flame_sprite, bowser_win)
		_animate_flame_visibility(true)
	else:
		global_manager.add_money(current_bet)
		result_message = "Push! Your bet is returned."
		_set_bowser_texture(bowser_sprite, bowser_tie)
		_animate_flame_visibility(false)
	
	player_money_changed.emit(global_manager.get_money())
	hand_result.emit(result_message)
	
	# Check if player is broke
	if global_manager.get_money() == 0:
		await get_tree().create_timer(1.0).timeout
		hand_result.emit("HA! BROKE BOZO!")
		if bwahaha_sound and bwahaha_sound.stream:
			bwahaha_sound.play()
	
	dealer_hand.show_all_cards()
