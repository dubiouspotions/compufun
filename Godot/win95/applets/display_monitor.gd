extends TextureRect
## The monitor picture at the top of Display Properties, in the scheme's 3D colours. Its screen
## shows a 640 x 480 desktop scaled down, or a fixed picture.

const _PALETTE := preload("res://win95/theme/palette.tres")
const _WIN95 := preload("res://win95/win95.gd")

## A picture of the whole screen, shown 1:1 instead of the desktop; null shows the desktop.
@export var picture: Texture2D:
	set(value):
		picture = value
		if is_node_ready():
			_sync()

@onready var _desktop: Control = %Desktop
@onready var _wallpaper: TextureRect = %Wallpaper
@onready var _picture: TextureRect = %Picture


func _ready() -> void:
	_PALETTE.changed.connect(_recolour)
	_recolour()
	var screen: Control = %Screen
	_desktop.scale = screen.size / _desktop.size
	_sync()


## Shows the desktop with [param wallpaper], tiled or centred as the real desktop shows it; null
## shows the bare desktop. Returns true when the wallpaper tiles.
func show_wallpaper(wallpaper: Texture2D) -> bool:
	_wallpaper.texture = wallpaper
	if wallpaper == null:
		return false
	_wallpaper.stretch_mode = _WIN95.wallpaper_stretch(wallpaper, _desktop.size.x)
	return _wallpaper.stretch_mode == TextureRect.STRETCH_TILE


func _sync() -> void:
	_picture.texture = picture
	_picture.visible = picture != null
	_desktop.visible = picture == null


func _recolour() -> void:
	var shader := material as ShaderMaterial
	for colour: StringName in [&"face_color", &"shadow_color", &"highlight_color", &"dark_shadow_color"]:
		shader.set_shader_parameter(colour, _PALETTE.get(colour))
