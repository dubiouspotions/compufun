extends "res://win95/window.gd"
## Paint: draw on the canvas with the left button, pick a colour from the palette. File > New
## clears the canvas.

enum FileMenu { NEW, CLOSE }

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
	%File.id_pressed.connect(_on_file_menu)
	_clear()


## Titles the window after [param file], as Win95 does, on a blank canvas: files have no pictures yet.
func open_file(file: Win95File) -> void:
	%TitleBar.title = "%s - Paint" % file.name
	_clear()


func _clear() -> void:
	var canvas_size := Vector2i(_canvas.custom_minimum_size)
	_image = Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	_image.fill(Color.WHITE)
	_texture = ImageTexture.create_from_image(_image)
	_canvas.texture = _texture


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
		_image.fill_rect(Rect2i(point - Vector2i(pen_size / 2, pen_size / 2), Vector2i(pen_size, pen_size)).intersection(Rect2i(Vector2i.ZERO, _image.get_size())), _color)
	_texture.update(_image)


func _on_file_menu(id: int) -> void:
	match id:
		FileMenu.NEW:
			_clear()
		FileMenu.CLOSE:
			close()
