extends PanelContainer
## A Win95 window frame. It follows title bar drags and hides itself when closed.
## Expects a title_bar.tscn instance with the unique name TitleBar.

## The window hid itself because the player closed it.
signal closed


func _ready() -> void:
	var title_bar: Node = %TitleBar
	title_bar.drag_moved.connect(func(relative: Vector2) -> void: position += relative)
	title_bar.close_pressed.connect(close)


## Hides the window and emits closed.
func close() -> void:
	hide()
	closed.emit()
