extends AudioListener2D

## Makes this listener the active one so 2D audio pans relative to the player.


func _ready() -> void:
	make_current()
