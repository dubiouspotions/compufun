extends CorruptionSign
## The mouse cursor in the shop becomes the Windows cursor: the arrow, and the hand over a hotspot.
## Stage 0 gives back the game's arrow (ScreenView's game_cursor) and the system hand.

## The arrow, and the pixel of it that points.
@export var arrow: Texture2D = preload("res://win95/theme/arrow_cursor.png")
@export var arrow_hotspot: Vector2 = Vector2.ZERO
## The hand over a hotspot, and the pixel of it that points.
@export var hand: Texture2D = preload("res://corruption/win_cursor/hand_cursor.png")
@export var hand_hotspot: Vector2 = Vector2(5, 0)
## The whole-number scale of the cursors. 2 matches the desktop's cursor in the open Screen View.
@export_range(1, 4) var pixel_scale: int = 2

var _shown: bool = false
var _arrow_image: Image
var _hand_image: Image


func _apply(shown_stage: int) -> void:
	# Deferred: ScreenView sets its arrow in its _ready, after this sign's.
	_show.call_deferred(shown_stage > 0)


# The display server outlives the images and logs a leak at exit unless they are cleared.
func _exit_tree() -> void:
	if _shown:
		ScreenView.set_cursor(null, Input.CURSOR_ARROW)
		ScreenView.set_cursor(null, Input.CURSOR_POINTING_HAND)
		_shown = false


# Sets the cursors again on every change while on: the display server caches the same image.
func _show(on: bool) -> void:
	if not is_inside_tree() or (not on and not _shown):
		return
	_shown = on
	if on:
		if _arrow_image == null:
			_arrow_image = _scaled(arrow)
			_hand_image = _scaled(hand)
		ScreenView.set_cursor(_arrow_image, Input.CURSOR_ARROW, arrow_hotspot * pixel_scale)
		ScreenView.set_cursor(_hand_image, Input.CURSOR_POINTING_HAND, hand_hotspot * pixel_scale)
		return
	var view := _screen_view()
	if view != null:
		ScreenView.set_cursor(view.game_cursor, Input.CURSOR_ARROW, view.game_cursor_hotspot)
	else:
		ScreenView.set_cursor(null, Input.CURSOR_ARROW)
	ScreenView.set_cursor(null, Input.CURSOR_POINTING_HAND)


# The ScreenView that owns the game's arrow, or null in a scene without one.
func _screen_view() -> ScreenView:
	for layer: Node in get_tree().get_nodes_in_group(&"ui_layer"):
		for child: Node in layer.get_children():
			if child is ScreenView:
				return child as ScreenView
	return null


func _scaled(texture: Texture2D) -> Image:
	var image := texture.get_image() if texture != null else null
	if image == null:
		push_error("win_cursor: the cursor %s has no image" % texture)
		return null
	image.resize(image.get_width() * pixel_scale, image.get_height() * pixel_scale, Image.INTERPOLATE_NEAREST)
	return image
