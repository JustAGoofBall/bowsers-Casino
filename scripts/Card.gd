extends Node2D

enum Suit { HEARTS, DIAMONDS, CLUBS, SPADES }
enum Rank { ACE = 1, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING }

var suit: Suit = Suit.HEARTS
var rank: Rank = Rank.ACE
var is_face_up: bool = false:
	set(value):
		if is_face_up != value:
			is_face_up = value
			_play_flip_animation()

@onready var front_sprite: Sprite2D = $FrontSprite
@onready var back_sprite: Sprite2D = $BackSprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _init(card_suit: Suit = Suit.HEARTS, card_rank: Rank = Rank.ACE) -> void:
	suit = card_suit
	rank = card_rank

func _ready() -> void:
	_load_card_texture()
	_update_visual()

func _load_card_texture() -> void:
	# Make sure sprites exist before loading textures
	if not front_sprite or not back_sprite:
		return
	
	# Load the card front texture
	var card_name = _get_card_filename()
	var front_path = "res://assets/cards/" + card_name
	front_sprite.texture = load(front_path)
	
	# Load the card back texture
	var back_path = "res://assets/cards/CardBack.png"
	back_sprite.texture = load(back_path)

func _get_card_filename() -> String:
	# Format: H/D/C/S + rank (A, 2-10, J, Q, K)
	var suit_codes = ["H", "D", "C", "S"]
	var rank_codes = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
	
	# Example: "HA.png" for Ace of Hearts, "S10.png" for 10 of Spades
	return suit_codes[suit] + rank_codes[rank - 1] + ".png"

func _update_visual() -> void:
	if not front_sprite or not back_sprite:
		return
	
	front_sprite.visible = is_face_up
	back_sprite.visible = not is_face_up

func _play_flip_animation() -> void:
	if not animation_player:
		_update_visual()
		return
	
	if is_face_up:
		animation_player.play("flip_to_front")
	else:
		animation_player.play("flip_to_back")

func play_slide_in_animation() -> void:
	if animation_player and animation_player.has_animation("slide_in"):
		animation_player.play("slide_in")
	else:
		if not animation_player:
			print("AnimationPlayer not ready")
		else:
			print("Animation 'slide_in' not found")

func get_value() -> int:
	if rank >= Rank.JACK:
		return 10
	return rank

func get_card_name() -> String:
	var rank_names = ["Ace", "2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King"]
	var suit_names = ["Hearts", "Diamonds", "Clubs", "Spades"]
	return rank_names[rank - 1] + " of " + suit_names[suit]

func flip() -> void:
	is_face_up = !is_face_up
