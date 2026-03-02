extends Node2D

# Roulette numbers and their colors
const RED_NUMBERS = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const BLACK_NUMBERS = [2, 4, 6, 8, 10, 11, 13, 15, 17, 20, 22, 24, 26, 28, 29, 31, 33, 35]

var global_manager: Node
var current_bets: Dictionary = {}
var is_spinning: bool = false
var target_number: int = -1
var target_rotation: float = 0.0
var spin_duration: float = 0.0
var spin_elapsed: float = 0.0

# Roulette wheel order (American layout with 00)
const WHEEL_ORDER = [0, 28, 9, 26, 30, 11, 7, 20, 32, 17, 5, 22, 34, 15, 3, 24, 36, 13, 1, 37, 27, 10, 25, 29, 12, 8, 19, 31, 18, 6, 21, 33, 16, 4, 23, 35, 14, 2]
const DOUBLE_ZERO = 37  # We use 37 to represent 00

@onready var wheel: Node2D = $WheelArea/Wheel
@onready var ball: Sprite2D = $WheelArea/Wheel/Ball
@onready var result_label: Label = $ResultLabel
@onready var total_bet_label: Label = $TotalBetLabel
@onready var spin_button: Button = $SpinButton
@onready var clear_bets_button: Button = $ClearBetsButton

# Bet buttons
@onready var bet_amount_label: Label = $BetControls/BetAmount
var bet_amount: int = 10

func _ready() -> void:
	global_manager = get_node("/root/GlobalManager")
	_update_bet_display()
	_update_total_bet()

func _process(delta: float) -> void:
	if is_spinning:
		spin_elapsed += delta
		var progress = min(spin_elapsed / spin_duration, 1.0)
		
		# Ease out cubic for smooth deceleration
		var eased_progress = 1.0 - pow(1.0 - progress, 3.0)
		
		# Rotate wheel with easing
		wheel.rotation = eased_progress * target_rotation
		
		# Ball follows wheel but with slight offset for realism
		var ball_angle = wheel.rotation + sin(progress * TAU * 3.0) * 0.2
		ball.position = Vector2(sin(-ball_angle) * 120, -cos(-ball_angle) * 120)

func _place_bet(bet_type: String, bet_value) -> void:
	if is_spinning:
		return
	
	if global_manager.get_money() < bet_amount:
		result_label.text = "Not enough money!"
		return
	
	var bet_key = str(bet_type) + "_" + str(bet_value)
	
	if bet_key in current_bets:
		current_bets[bet_key].amount += bet_amount
	else:
		current_bets[bet_key] = {
			"type": bet_type,
			"value": bet_value,
			"amount": bet_amount
		}
	
	global_manager.remove_money(bet_amount)
	_update_total_bet()
	result_label.text = "Bet placed: " + str(bet_amount) + " on " + _get_bet_description(bet_type, bet_value)

func _get_bet_description(bet_type: String, bet_value) -> String:
	match bet_type:
		"number":
			return "Number " + str(bet_value)
		"color":
			return bet_value.to_upper()
		"odd_even":
			return bet_value.to_upper()
		"high_low":
			return bet_value.to_upper()
		"dozen":
			return "Dozen " + str(bet_value)
		"column":
			return "Column " + str(bet_value)
	return ""

func _on_spin_button_pressed() -> void:
	if is_spinning:
		return
	
	if current_bets.is_empty():
		result_label.text = "Place a bet first!"
		return
	
	is_spinning = true
	spin_button.disabled = true
	clear_bets_button.disabled = true
	result_label.text = "Spinning..."
	
	global_manager.increment_games_played()
	
	# Pick a random slot on the wheel (0-37)
	var random_slot = randi() % WHEEL_ORDER.size()
	target_number = WHEEL_ORDER[random_slot]
	
	# Calculate target angle: each slot is TAU/38 radians apart
	var slot_angle = (TAU / WHEEL_ORDER.size()) * random_slot
	
	# Add multiple full rotations (3-5 spins) plus the target angle
	var full_spins = randf_range(3.0, 5.0) * TAU
	target_rotation = wheel.rotation + full_spins + slot_angle
	
	# Random spin duration between 3.5 and 4.5 seconds
	spin_duration = randf_range(3.5, 4.5)
	spin_elapsed = 0.0
	
	# Wait for spin to complete
	await get_tree().create_timer(spin_duration + 0.5).timeout
	
	# Snap to final position
	wheel.rotation = target_rotation
	var final_angle = -slot_angle
	ball.position = Vector2(sin(final_angle) * 120, -cos(final_angle) * 120)
	
	await get_tree().create_timer(0.5).timeout
	
	# Calculate results
	_process_results()
	
	is_spinning = false
	spin_button.disabled = false
	clear_bets_button.disabled = false

func _process_results() -> void:
	var total_winnings = 0
	var winning_color = _get_number_color(target_number)
	var is_odd = target_number > 0 and target_number % 2 == 1
	var is_even = target_number > 0 and target_number % 2 == 0
	var is_high = target_number >= 19 and target_number <= 36
	var is_low = target_number >= 1 and target_number <= 18
	
	for bet_key in current_bets:
		var bet = current_bets[bet_key]
		var payout = 0
		
		match bet.type:
			"number":
				if bet.value == target_number:
					payout = bet.amount * 36  # 35:1 + original bet
			"color":
				if bet.value == winning_color:
					payout = bet.amount * 2  # 1:1 + original bet
			"odd_even":
				if (bet.value == "odd" and is_odd) or (bet.value == "even" and is_even):
					payout = bet.amount * 2
			"high_low":
				if (bet.value == "high" and is_high) or (bet.value == "low" and is_low):
					payout = bet.amount * 2
			"dozen":
				var dozen = int(((target_number - 1) / 12.0) + 1)
				if target_number > 0 and bet.value == dozen:
					payout = bet.amount * 3  # 2:1 + original bet
			"column":
				var column = int(((target_number - 1) / 3.0) + 1)
				if target_number > 0 and bet.value == column:
					payout = bet.amount * 3
		
		total_winnings += payout
	
	var display_number = "00" if target_number == 37 else str(target_number)
	if total_winnings > 0:
		global_manager.add_money(total_winnings)
		result_label.text = "Number " + display_number + " (" + winning_color.to_upper() + ")! Won " + str(total_winnings) + " coins!"
	else:
		result_label.text = "Number " + display_number + " (" + winning_color.to_upper() + ") - Better luck next time!"
	
	current_bets.clear()
	_update_total_bet()

func _get_number_color(number: int) -> String:
	if number == 0 or number == 37:  # 0 or 00
		return "green"
	elif number in RED_NUMBERS:
		return "red"
	else:
		return "black"

func _on_clear_bets_pressed() -> void:
	if is_spinning:
		return
	
	# Refund all bets
	for bet_key in current_bets:
		global_manager.add_money(current_bets[bet_key].amount)
	
	current_bets.clear()
	_update_total_bet()
	result_label.text = "All bets cleared"

func _update_total_bet() -> void:
	var total = 0
	for bet_key in current_bets:
		total += current_bets[bet_key].amount
	total_bet_label.text = "Total Bet: " + str(total) + " coins"

func _update_bet_display() -> void:
	bet_amount_label.text = str(bet_amount)

func _on_increase_bet_pressed() -> void:
	if bet_amount < 100000:
		bet_amount += 10
		_update_bet_display()

func _on_decrease_bet_pressed() -> void:
	if bet_amount > 10:
		bet_amount -= 10
		_update_bet_display()

# Number bets
func _on_number_button_pressed(number: int) -> void:
	_place_bet("number", number)

func _on_double_zero_button_pressed() -> void:
	_place_bet("number", 37)  # 37 represents 00

# Color bets
func _on_red_button_pressed() -> void:
	_place_bet("color", "red")

func _on_black_button_pressed() -> void:
	_place_bet("color", "black")

# Odd/Even bets
func _on_odd_button_pressed() -> void:
	_place_bet("odd_even", "odd")

func _on_even_button_pressed() -> void:
	_place_bet("odd_even", "even")

# High/Low bets
func _on_high_button_pressed() -> void:
	_place_bet("high_low", "high")

func _on_low_button_pressed() -> void:
	_place_bet("high_low", "low")

# Dozen bets
func _on_dozen1_button_pressed() -> void:
	_place_bet("dozen", 1)

func _on_dozen2_button_pressed() -> void:
	_place_bet("dozen", 2)

func _on_dozen3_button_pressed() -> void:
	_place_bet("dozen", 3)

# Column bets
func _on_column_button_pressed(column: int) -> void:
	_place_bet("column", column)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
