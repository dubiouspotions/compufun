extends "res://win95/document_window.gd"
## Paint: draw on the canvas with the left button, pick a colour from the palette. It shows and
## saves a .bmp file's picture.

## The colours in the palette, two rows of eight as in Win95.
@export var palette: PackedColorArray = PackedColorArray([
	Color8(0, 0, 0), Color8(128, 128, 128), Color8(128, 0, 0), Color8(128, 128, 0),
	Color8(0, 128, 0), Color8(0, 128, 128), Color8(0, 0, 128), Color8(128, 0, 128),
	Color8(255, 255, 255), Color8(192, 192, 192), Color8(255, 0, 0), Color8(255, 255, 0),
	Color8(0, 255, 0), Color8(0, 255, 255), Color8(0, 0, 255), Color8(255, 0, 255),
])
## The pen's width, in canvas pixels.
@export var pen_size: int = 2
## The file extensions that this app opens, lower case, without the dot.
@export var opens: Array[String] = ["bmp"]

var _color: Color = Color.BLACK
var _image: Image
var _texture: ImageTexture
var _last: Vector2i = Vector2i(-1, -1)
var _drawn := false

@onready var _canvas: TextureRect = %Canvas
@onready var _current: ColorRect = %Current


func _ready() -> void:
	super()
	for color in palette:
		var swatch := ColorRect.new()
		swatch.color = color
		swatch.custom_minimum_size = Vector2(14, 13)
		swatch.gui_input.connect(func(event: InputEvent) -> void:
			var button := event as InputEventMouseButton
			if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
				_color = color
				_current.color = color)
		%Palette.add_child(swatch)
	_current.color = _color
	_canvas.gui_input.connect(_on_canvas_input)
	_load(null)


# A white canvas with the file's picture in its top left corner.
func _load(from: Win95File) -> void:
	var canvas_size := Vector2i(_canvas.custom_minimum_size)
	_image = Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	_image.fill(Color.WHITE)
	if from != null and from.picture != null:
		var picture := from.picture.get_image()
		if picture == null:
			push_error("Paint: the picture of %s has no image data" % from.name)
		else:
			if picture.is_compressed():
				picture.decompress()
			picture.convert(Image.FORMAT_RGBA8)
			_image.blit_rect(picture, Rect2i(Vector2i.ZERO, picture.get_size()), Vector2i.ZERO)
	_texture = ImageTexture.create_from_image(_image)
	_canvas.texture = _texture
	_drawn = false


func _save(state: ComputerState, into: Win95File) -> void:
	state.write_picture(into, _image)
	_drawn = false


func _is_dirty() -> bool:
	return _drawn


func _on_canvas_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		_last = Vector2i(button.position) if button.pressed else Vector2i(-1, -1)
		if button.pressed:
			_line(_last, _last)
	var motion := event as InputEventMouseMotion
	if motion and motion.button_mask & MOUSE_BUTTON_MASK_LEFT and _last.x >= 0:
		var at := Vector2i(motion.position)
		_line(_last, at)
		_last = at


func _line(from: Vector2i, to: Vector2i) -> void:
	var steps := maxi(1, int(Vector2(to - from).length()))
	for i in steps + 1:
		var point := Vector2i(Vector2(from).lerp(Vector2(to), float(i) / steps))
		@warning_ignore("integer_division")
		_image.fill_rect(Rect2i(point - Vector2i(pen_size / 2, pen_size / 2), Vector2i(pen_size, pen_size)).intersection(Rect2i(Vector2i.ZERO, _image.get_size())), _color)
	_texture.update(_image)
	_drawn = true

