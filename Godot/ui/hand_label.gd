extends Label
## What the player holds, at the bottom of the screen in every view (wiki: Hardware Repair). Hidden
## while the hand is empty.


func _ready() -> void:
	Game.changed.connect(_sync)
	_sync()


func _sync() -> void:
	visible = Game.hand != null
	if Game.hand != null:
		text = "In your hand: %s%s" % [Game.hand.part.display_name, " (broken)" if Game.hand.broken else ""]
