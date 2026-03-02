extends Node

# Player data that persists across all games
var player_money: int = 1000
var total_games_played: int = 0
var total_winnings: int = 0

# Signals
signal money_changed(new_amount: int)

func _ready() -> void:
	# Make this node persistent across scene changes
	process_mode = Node.PROCESS_MODE_ALWAYS

func add_money(amount: int) -> void:
	player_money += amount
	if amount > 0:
		total_winnings += amount
	money_changed.emit(player_money)

func remove_money(amount: int) -> bool:
	if amount > player_money:
		return false
	player_money -= amount
	money_changed.emit(player_money)
	return true

func get_money() -> int:
	return player_money

func change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

func increment_games_played() -> void:
	total_games_played += 1

# Save/Load system (optional for future)
func save_game() -> void:
	var _save_data = {
		"money": player_money,
		"games_played": total_games_played,
		"total_winnings": total_winnings
	}
	# TODO: Implement save to file

func load_game() -> void:
	# TODO: Implement load from file
	pass
