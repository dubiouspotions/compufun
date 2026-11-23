extends "res://win95/cover_screen.gd"
## The Blank Screen screensaver: the whole screen black. Any key or click ends it.


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
