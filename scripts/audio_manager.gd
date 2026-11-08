extends Node

## Persistent menu music and UI sounds. Lives across scene changes so the menu
## track keeps playing from the main menu into the game's intro screen.

const MENU_MUSIC := preload("res://assets/music/main-menu.ogg")
const SELECT_SFX := preload("res://assets/sounds/select.wav")

const SILENCE_DB := -80.0
const SELECT_PLAYER_COUNT := 3

var _music: AudioStreamPlayer
var _music_tween: Tween
var _select_players: Array[AudioStreamPlayer] = []
var _select_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var music_stream := MENU_MUSIC as AudioStreamOggVorbis
	if music_stream != null:
		music_stream.loop = true

	_music = AudioStreamPlayer.new()
	_music.name = "MenuMusic"
	_music.stream = MENU_MUSIC
	add_child(_music)

	for i in SELECT_PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.name = "Select%d" % (i + 1)
		player.stream = SELECT_SFX
		add_child(player)
		_select_players.append(player)

	_music.play()


func _stop_all() -> void:
	if _music != null:
		_music.stop()
		_music.stream = null

	for player in _select_players:
		player.stop()
		player.stream = null


func _exit_tree() -> void:
	if is_instance_valid(_music_tween):
		_music_tween.kill()
		_music_tween = null

	_stop_all()


## Start (or resume at full volume) the looping menu track.
func play_menu_music() -> void:
	if is_instance_valid(_music_tween):
		_music_tween.kill()
	_music_tween = null

	if not _music.playing:
		_music.play()
	_music.volume_db = 0.0


## Smoothly fade the menu track out, then stop it.
func fade_out_menu_music(duration: float = 2.0) -> void:
	if not _music.playing:
		return

	if is_instance_valid(_music_tween):
		_music_tween.kill()

	_music_tween = create_tween()
	_music_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_music_tween.tween_property(_music, "volume_db", SILENCE_DB, maxf(duration, 0.01))
	_music_tween.tween_callback(_music.stop)


## Play the menu button hover sound.
func play_select() -> void:
	if _select_players.is_empty():
		return

	var player := _select_players[_select_index]
	_select_index = (_select_index + 1) % _select_players.size()
	player.play()
