extends CanvasLayer

@onready var money_label = $MoneyLabel
@onready var stats_label = $StatsLabel
# Each button just needs the scene it opens, so the list is the whole wiring.
const GAMES := [
	["BlackjackButton", "res://scenes/Main.tscn"],
	["SlotsButton", "res://scenes/Slots.tscn"],
	["PokerButton", "res://scenes/Poker.tscn"],
	["RouletteButton", "res://scenes/Roulette.tscn"],
	["HiLoButton", "res://scenes/HiLo.tscn"],
	["PlinkoButton", "res://scenes/Plinko.tscn"],
	["CrapsButton", "res://scenes/Craps.tscn"],
]

@onready var game_buttons = $GameButtons

var global_manager: Node

func _ready() -> void:
	# Get reference to GlobalManager autoload
	global_manager = get_node("/root/GlobalManager")
	
	# Connect signals
	global_manager.money_changed.connect(_on_money_changed)
	for entry in GAMES:
		var button := game_buttons.get_node_or_null(String(entry[0])) as Button
		if button:
			button.pressed.connect(_open_game.bind(String(entry[1])))
		else:
			push_warning("MainMenu: no button named %s" % entry[0])
	
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

func _open_game(scene_path: String) -> void:
	global_manager.change_scene(scene_path)
