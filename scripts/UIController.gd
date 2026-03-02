extends CanvasLayer

@onready var game_manager = get_parent().get_node("GameManager")
@onready var player_hand = game_manager.get_node("PlayerHand")
@onready var dealer_hand = game_manager.get_node("DealerHand")

@onready var money_label = $MoneyLabel
@onready var bet_label = $BetLabel
@onready var player_value_label = $PlayerValueLabel
@onready var dealer_value_label = $DealerValueLabel
@onready var result_label = $ResultLabel

@onready var betting_panel = $BettingPanel
@onready var game_panel = $GamePanel
@onready var new_round_button = $NewRoundButton

@onready var bet_slider = $BettingPanel/VBoxContainer/BetSlider
@onready var bet_amount_label = $BettingPanel/VBoxContainer/BetAmountLabel
@onready var deal_button = $BettingPanel/VBoxContainer/DealButton

@onready var hit_button = $GamePanel/HBoxContainer/HitButton
@onready var stand_button = $GamePanel/HBoxContainer/StandButton
@onready var back_button = $BackButton

var global_manager: Node

func _ready() -> void:
	global_manager = get_node("/root/GlobalManager")
	
	# Connect signals
	game_manager.game_state_changed.connect(_on_game_state_changed)
	game_manager.player_money_changed.connect(_on_player_money_changed)
	game_manager.hand_result.connect(_on_hand_result)
	
	# Connect buttons
	deal_button.pressed.connect(_on_deal_pressed)
	hit_button.pressed.connect(_on_hit_pressed)
	stand_button.pressed.connect(_on_stand_pressed)
	new_round_button.pressed.connect(_on_new_round_pressed)
	bet_slider.value_changed.connect(_on_bet_slider_changed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Initialize UI
	_update_money_display(game_manager.player_money)
	_update_bet_display(int(bet_slider.value))

func _process(_delta: float) -> void:
	# Update hand values
	player_value_label.text = "Your Hand: %d" % player_hand.get_value()
	
	# Only show dealer value if all cards are face up
	var all_face_up = true
	for card in dealer_hand.cards:
		if not card.is_face_up:
			all_face_up = false
			break
	
	if all_face_up and dealer_hand.cards.size() > 0:
		dealer_value_label.text = "Dealer Hand: %d" % dealer_hand.get_value()
	else:
		dealer_value_label.text = "Dealer Hand: ?"

func _on_deal_pressed() -> void:
	var bet = int(bet_slider.value)
	game_manager.start_new_round(bet)
	result_label.text = ""

func _on_hit_pressed() -> void:
	game_manager.player_hit()

func _on_stand_pressed() -> void:
	game_manager.player_stand()

func _on_new_round_pressed() -> void:
	betting_panel.visible = true
	game_panel.visible = false
	new_round_button.visible = false
	result_label.text = ""

func _on_bet_slider_changed(value: float) -> void:
	_update_bet_display(int(value))

func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		game_manager.GameState.BETTING:
			betting_panel.visible = true
			game_panel.visible = false
			new_round_button.visible = false
		game_manager.GameState.PLAYER_TURN:
			betting_panel.visible = false
			game_panel.visible = true
			new_round_button.visible = false
		game_manager.GameState.DEALER_TURN:
			game_panel.visible = false
		game_manager.GameState.GAME_OVER:
			game_panel.visible = false
			new_round_button.visible = true

func _on_player_money_changed(amount: int) -> void:
	_update_money_display(amount)
	bet_slider.max_value = min(500, amount)

func _on_hand_result(message: String) -> void:
	result_label.text = message

func _on_back_pressed() -> void:
	global_manager.change_scene("res://scenes/menu/MainMenu.tscn")

func _update_money_display(amount: int) -> void:
	money_label.text = "Money: $%d" % amount

func _update_bet_display(amount: int) -> void:
	bet_amount_label.text = "Bet Amount: $%d" % amount
	bet_label.text = "Bet: $%d" % amount
