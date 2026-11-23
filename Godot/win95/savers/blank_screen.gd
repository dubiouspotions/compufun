extends Saver
## The Blank Screen screensaver: the whole screen black. Any key, click or mouse move ends it.


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
