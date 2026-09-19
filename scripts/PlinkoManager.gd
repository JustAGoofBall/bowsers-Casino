extends Node2D

# A Galton board: the ball takes twelve fair left/right decisions on the way
# down and lands in one of thirteen slots.
#
# The path is decided up front and the animation is then driven along it,
# rather than letting a physics body find its own way. That matters because
# it makes the landing distribution exactly binomial, so the payouts below
# can be priced against real numbers instead of whatever a physics engine
# happens to produce.

const ROWS := 12
const SLOT_COUNT := ROWS + 1

# Payouts in TENTHS of the stake. Every stake step is a multiple of ten, so
# stake * tenths / 10 is always exact and no rounding leaks into the edge.
# Weighted by the binomial counts these return 97.44% (see the verification
# script in the commit that added this file).
const SLOT_PAYOUT_TENTHS := [280, 85, 40, 20, 12, 6, 2, 6, 12, 20, 40, 85, 280]
const BET_STEPS := [10, 20, 50, 100, 250]

const BOARD_CENTRE_X := 576.0
const SLOT_WIDTH := 62.0
const TOP_Y := 118.0
const ROW_HEIGHT := 28.0
const SLOT_TOP_Y := TOP_Y + ROWS * ROW_HEIGHT + 12.0
const SLOT_HEIGHT := 48.0

var global_manager: Node
var bet_index: int = 0
var is_dropping: bool = false
var slot_panels: Array = []

@onready var pegs: Node2D = $Pegs
@onready var slots: Control = $Slots
@onready var ball: Sprite2D = $Ball
@onready var drop_button: Button = $DropButton
@onready var bet_label: Label = $BetControls/BetAmount
@onready var increase_bet: Button = $BetControls/IncreaseBet
@onready var decrease_bet: Button = $BetControls/DecreaseBet
@onready var money_label: Label = $MoneyLabel
@onready var result_label: Label = $ResultLabel
@onready var back_button: Button = $BackButton
@onready var peg_sound: AudioStreamPlayer = $PegHit
@onready var win_sound: AudioStreamPlayer = $WinChime
@onready var bwahaha: AudioStreamPlayer = $Bwahaha

var peg_texture: Texture2D


func _ready() -> void:
	global_manager = get_node("/root/GlobalManager")
	global_manager.money_changed.connect(_on_money_changed)
	peg_texture = load("res://assets/plinko/Peg.svg")

	_build_pegs()
	_build_slots()
	_reset_ball()

	_on_money_changed(global_manager.get_money())
	_update_bet_display()
	result_label.text = "Drop a ball. The edges pay best, but you will rarely get there."


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if is_dropping or key == null or not key.pressed or key.echo:
		return
	if key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_on_drop_button_pressed()
		get_viewport().set_input_as_handled()


# --- board -------------------------------------------------------------------

func _peg_position(row: int, index: int) -> Vector2:
	return Vector2(
		BOARD_CENTRE_X + (float(index) - float(row) * 0.5) * SLOT_WIDTH,
		TOP_Y + float(row) * ROW_HEIGHT
	)


func _build_pegs() -> void:
	for row in range(ROWS):
		for index in range(row + 1):
			var peg := Sprite2D.new()
			peg.texture = peg_texture
			peg.position = _peg_position(row, index)
			pegs.add_child(peg)


func _slot_centre_x(slot: int) -> float:
	return BOARD_CENTRE_X + (float(slot) - float(ROWS) * 0.5) * SLOT_WIDTH


func _build_slots() -> void:
	slot_panels.clear()
	for slot in range(SLOT_COUNT):
		var tenths: int = SLOT_PAYOUT_TENTHS[slot]
		# hottest at the edges, coolest in the middle
		var heat: float = abs(float(slot) - float(ROWS) * 0.5) / (float(ROWS) * 0.5)

		var panel := ColorRect.new()
		panel.color = Color(0.20 + 0.62 * heat, 0.34 - 0.20 * heat, 0.12, 0.92)
		panel.position = Vector2(_slot_centre_x(slot) - SLOT_WIDTH * 0.5 + 2.0, SLOT_TOP_Y)
		panel.size = Vector2(SLOT_WIDTH - 4.0, SLOT_HEIGHT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var label := Label.new()
		label.text = _format_multiplier(tenths)
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(1, 0.97, 0.85))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", 4)
		panel.add_child(label)

		slots.add_child(panel)
		slot_panels.append(panel)


func _format_multiplier(tenths: int) -> String:
	if tenths % 10 == 0:
		return "%dx" % (tenths / 10)
	return "%.1fx" % (float(tenths) / 10.0)


func _reset_ball() -> void:
	ball.position = Vector2(BOARD_CENTRE_X, TOP_Y - 48.0)
	ball.modulate = Color.WHITE


# --- dropping -----------------------------------------------------------------

func _on_drop_button_pressed() -> void:
	if is_dropping:
		return

	var stake := current_bet()
	if global_manager.get_money() < stake:
		result_label.text = "Not enough coins for a %d drop!" % stake
		return

	is_dropping = true
	_set_controls_enabled(false)
	global_manager.remove_money(stake)
	global_manager.increment_games_played()
	result_label.text = "Dropping..."
	_reset_ball()

	# Twelve fair decisions; the slot is how many of them went right.
	var rights := 0
	var points: Array[Vector2] = []
	for row in range(ROWS):
		if randi() % 2 == 1:
			rights += 1
		points.append(Vector2(
			BOARD_CENTRE_X + (2.0 * float(rights) - float(row + 1)) * SLOT_WIDTH * 0.5,
			TOP_Y + float(row + 1) * ROW_HEIGHT
		))

	var tween := create_tween()
	for point in points:
		tween.tween_property(ball, "position", point, 0.105).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(_peg_click)
	tween.tween_property(ball, "position",
		Vector2(_slot_centre_x(rights), SLOT_TOP_Y + SLOT_HEIGHT * 0.5), 0.22
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if not is_inside_tree():
		return

	_settle(rights, stake)

	is_dropping = false
	_set_controls_enabled(true)


func _peg_click() -> void:
	if peg_sound and peg_sound.stream:
		peg_sound.pitch_scale = randf_range(0.88, 1.18)
		peg_sound.play()


func _settle(slot: int, stake: int) -> void:
	var tenths: int = SLOT_PAYOUT_TENTHS[slot]
	var returned: int = stake * tenths / 10
	if returned > 0:
		global_manager.add_money(returned)

	var net := returned - stake
	if net > 0:
		result_label.text = "%s slot - you win %d coins!" % [_format_multiplier(tenths), net]
		_play(win_sound)
	elif net == 0:
		result_label.text = "%s slot - you break even." % _format_multiplier(tenths)
	else:
		result_label.text = "%s slot - you lose %d coins." % [_format_multiplier(tenths), -net]
		_play(bwahaha)

	_flash_slot(slot)


func _flash_slot(slot: int) -> void:
	if slot < 0 or slot >= slot_panels.size():
		return
	var panel: ColorRect = slot_panels[slot]
	var original: Color = panel.color
	var tween := create_tween()
	tween.tween_property(panel, "color", Color(1.0, 0.95, 0.5, 1.0), 0.10)
	tween.tween_property(panel, "color", original, 0.45)


# --- UI ---------------------------------------------------------------------------

func current_bet() -> int:
	return int(BET_STEPS[bet_index])


func _set_controls_enabled(enabled: bool) -> void:
	drop_button.disabled = not enabled
	increase_bet.disabled = not enabled
	decrease_bet.disabled = not enabled
	back_button.disabled = not enabled


func _update_bet_display() -> void:
	bet_label.text = str(current_bet())
	drop_button.text = "DROP (%d coins)" % current_bet()


func _on_increase_bet_pressed() -> void:
	if is_dropping:
		return
	bet_index = mini(bet_index + 1, BET_STEPS.size() - 1)
	_update_bet_display()


func _on_decrease_bet_pressed() -> void:
	if is_dropping:
		return
	bet_index = maxi(bet_index - 1, 0)
	_update_bet_display()


func _on_money_changed(new_amount: int) -> void:
	money_label.text = "Coins: %d" % new_amount


func _play(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()


func _on_back_button_pressed() -> void:
	if is_dropping:
		return
	get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
