extends Node2D

## A small colored cube that plays one song stem on a loop.
## Its volume rises as the player gets closer.

@export var stem: AudioStream
@export var cube_color: Color = Color.WHITE
@export var hearing_radius: float = 700.0

@onready var _visual: ColorRect = $Visual
@onready var _audio: AudioStreamPlayer2D = $Audio

var _player: Node2D


func _ready() -> void:
	_visual.color = cube_color
	if stem != null:
		_audio.stream = stem
	if _audio.stream != null:
		_audio.play()
	_player = get_tree().get_first_node_in_group("player")


func _process(_delta: float) -> void:
	if _player == null:
		return

	var distance := global_position.distance_to(_player.global_position)
	var closeness := clampf(1.0 - distance / hearing_radius, 0.0, 1.0)
	# Square the linear closeness so the fade is more noticeable up close.
	var amplitude := maxf(closeness * closeness, 0.0001)
	_audio.volume_db = linear_to_db(amplitude)
