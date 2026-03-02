extends Node2D

# Symbol names
const SYMBOL_NAMES = ["Batty", "Bowsey", "Burny", "Goomby", "Kaboomy", "Koopy", "Slimey"]
const SYMBOL_COUNT = 7

# Symbol values for payouts (adjust based on your symbols)
const SYMBOL_VALUES = [2, 3, 4, 5, 10, 15, 20]

var global_manager: Node
var is_spinning: bool = false
var current_bet: int = 10
var symbol_textures: Array = []
var has_mushroom: bool = false
const MUSHROOM_COST: int = 50

@onready var reel1_sprite: Sprite2D = $ReelsContainer/Reel1/Symbol1
@onready var reel2_sprite: Sprite2D = $ReelsContainer/Reel2/Symbol2
@onready var reel3_sprite: Sprite2D = $ReelsContainer/Reel3/Symbol3
@onready var spin_button: Button = $SpinButton
@onready var bet_amount_label: Label = $BetControls/BetAmount
@onready var win_label: Label = $WinLabel
@onready var decrease_bet_button: Button = $BetControls/DecreaseBet
@onready var increase_bet_button: Button = $BetControls/IncreaseBet
@onready var handle_arm: ColorRect = $Handle/HandleArm
@onready var mushroom_button: Button = $MushroomButton
@onready var mushroom_status: Label = $MushroomStatus

func _ready() -> void:
	global_manager = get_node("/root/GlobalManager")
	_load_symbol_textures()
	_update_bet_display()
	_update_spin_button()
	_update_mushroom_button()
	# Set initial symbols
	_set_symbol(reel1_sprite, 0)
	_set_symbol(reel2_sprite, 0)
	_set_symbol(reel3_sprite, 0)

func _load_symbol_textures() -> void:
	# Load individual symbol images from assets/slots/ folder
	for symbol_name in SYMBOL_NAMES:
		var texture = load("res://assets/slots/" + symbol_name + ".png")
		symbol_textures.append(texture)

func _set_symbol(sprite: Sprite2D, symbol_index: int) -> void:
	if symbol_index >= 0 and symbol_index < symbol_textures.size():
		sprite.texture = symbol_textures[symbol_index]

func _on_spin_button_pressed() -> void:
	if is_spinning:
		return
	
	if global_manager.get_money() < current_bet:
		win_label.text = "Not enough money!"
		return
	
	# Deduct bet
	global_manager.remove_money(current_bet)
	global_manager.increment_games_played()
	
	is_spinning = true
	spin_button.disabled = true
	win_label.text = ""
	
	# Check if mushroom is active
	var using_mushroom = has_mushroom
	if using_mushroom:
		has_mushroom = false
		_update_mushroom_button()
		win_label.text = "🍄 MUSHROOM BOOST ACTIVE! 🍄"
	
	# Animate handle
	_animate_handle()
	
	# Spin animation
	await _spin_reels(using_mushroom)
	
	# Check results
	var result = _check_win()
	if result > 0:
		var winnings = current_bet * result
		global_manager.add_money(winnings)
		win_label.text = "W Money! +" + str(winnings) + " coins!"
	else:
		win_label.text = "L Bozo!"
	
	is_spinning = false
	spin_button.disabled = false
	_update_spin_button()

func _animate_handle() -> void:
	if not handle_arm:
		return
	
	# Pull handle down
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(handle_arm, "rotation_degrees", 45, 0.2)
	
	# Return handle up
	await tween.finished
	var tween2 = create_tween()
	tween2.set_ease(Tween.EASE_OUT)
	tween2.set_trans(Tween.TRANS_BOUNCE)
	tween2.tween_property(handle_arm, "rotation_degrees", 0, 0.5)

func _spin_reels(luck_boost: bool = false) -> void:
	var spin_duration = 2.0
	var spin_speed = 0.05
	var elapsed = 0.0
	
	# Store final results
	var final_reel1 = randi() % SYMBOL_COUNT
	var final_reel2 = randi() % SYMBOL_COUNT
	var final_reel3 = randi() % SYMBOL_COUNT
	
	# Mushroom luck boost: increase chance of matching symbols
	if luck_boost:
		var boost_chance = randf()
		if boost_chance < 0.6:  # 60% chance to force a match
			var base_symbol = randi() % SYMBOL_COUNT
			final_reel1 = base_symbol
			final_reel2 = base_symbol
			final_reel3 = base_symbol
		elif boost_chance < 0.85:  # 25% chance to force 2 matches
			var base_symbol = randi() % SYMBOL_COUNT
			final_reel1 = base_symbol
			final_reel2 = base_symbol
	
	# Spin all reels
	while elapsed < spin_duration:
		_set_symbol(reel1_sprite, randi() % SYMBOL_COUNT)
		await get_tree().create_timer(spin_speed).timeout
		elapsed += spin_speed
		
		if elapsed > 0.5:
			_set_symbol(reel2_sprite, randi() % SYMBOL_COUNT)
		if elapsed > 1.0:
			_set_symbol(reel3_sprite, randi() % SYMBOL_COUNT)
	
	# Set final results with staggered stops
	_set_symbol(reel1_sprite, final_reel1)
	await get_tree().create_timer(0.3).timeout
	_set_symbol(reel2_sprite, final_reel2)
	await get_tree().create_timer(0.3).timeout
	_set_symbol(reel3_sprite, final_reel3)

func _check_win() -> int:
	# Compare symbol indices directly
	var symbol1 = _get_current_symbol_index(reel1_sprite)
	var symbol2 = _get_current_symbol_index(reel2_sprite)
	var symbol3 = _get_current_symbol_index(reel3_sprite)
	
	# Three of a kind
	if symbol1 == symbol2 and symbol2 == symbol3:
		return SYMBOL_VALUES[symbol1]
	
	# Two of a kind
	if symbol1 == symbol2 or symbol2 == symbol3 or symbol1 == symbol3:
		var matching_symbol = symbol1 if symbol1 == symbol2 else symbol2
		return int(SYMBOL_VALUES[matching_symbol] * 0.5)
	
	return 0

func _get_current_symbol_index(sprite: Sprite2D) -> int:
	# Find which symbol is currently displayed
	for i in range(symbol_textures.size()):
		if sprite.texture == symbol_textures[i]:
			return i
	return 0

func _on_increase_bet_pressed() -> void:
	if current_bet < 100:
		current_bet += 10
		_update_bet_display()
		_update_spin_button()

func _on_decrease_bet_pressed() -> void:
	if current_bet > 10:
		current_bet -= 10
		_update_bet_display()
		_update_spin_button()

func _update_bet_display() -> void:
	bet_amount_label.text = str(current_bet)

func _update_spin_button() -> void:
	spin_button.text = "SPIN (" + str(current_bet) + " coins)"
	spin_button.disabled = global_manager.get_money() < current_bet

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")

func _on_mushroom_button_pressed() -> void:
	if has_mushroom:
		return
	
	if global_manager.get_money() < MUSHROOM_COST:
		win_label.text = "Not enough money for mushroom!"
		return
	
	global_manager.remove_money(MUSHROOM_COST)
	has_mushroom = true
	_update_mushroom_button()
	win_label.text = "🍄 Mushroom purchased! Luck boost next spin!"

func _update_mushroom_button() -> void:
	if has_mushroom:
		mushroom_button.text = "🍄 READY!"
		mushroom_button.disabled = true
		mushroom_status.text = "🍄 Mushroom Active!"
	else:
		mushroom_button.text = "Buy Mushroom (50)"
		mushroom_button.disabled = global_manager.get_money() < MUSHROOM_COST
		mushroom_status.text = ""
