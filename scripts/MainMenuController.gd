extends CanvasLayer

@onready var money_label = $MoneyLabel
@onready var stats_label = $StatsLabel
@onready var blackjack_button = $GameButtons/BlackjackButton
@onready var slots_button = $GameButtons/SlotsButton
@onready var poker_button = $GameButtons/PokerButton
@onready var roulette_button = $GameButtons/RouletteButton

var global_manager: Node

func _ready() -> void:
	# Get reference to GlobalManager autoload
	global_manager = get_node("/root/GlobalManager")
	
	# Connect signals
	global_manager.money_changed.connect(_on_money_changed)
	blackjack_button.pressed.connect(_on_blackjack_pressed)
	slots_button.pressed.connect(_on_slots_pressed)
	poker_button.pressed.connect(_on_poker_pressed)
	roulette_button.pressed.connect(_on_roulette_pressed)
	
	# Update displays
	_update_money_display()
	_update_stats_display()

func _update_money_display() -> void:
	money_label.text = "Money: $%d" % global_manager.get_money()

func _update_stats_display() -> void:
	stats_label.text = "Games Played: %d\nTotal Winnings: $%d" % [
		global_manager.total_games_played,
		global_manager.total_winnings
	]

func _on_money_changed(_new_amount: int) -> void:
	_update_money_display()

func _on_blackjack_pressed() -> void:
	global_manager.change_scene("res://scenes/Main.tscn")

func _on_slots_pressed() -> void:
	global_manager.change_scene("res://scenes/Slots.tscn")

func _on_poker_pressed() -> void:
	global_manager.change_scene("res://scenes/Poker.tscn")

func _on_roulette_pressed() -> void:
	global_manager.change_scene("res://scenes/Roulette.tscn")
