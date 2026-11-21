extends PropertyPage
## Display > Background: the wallpaper list, previewed on the monitor. Apply sets the wallpaper.
## The patterns, Edit Pattern..., Browse... and Tile / Center show Win95's layout, disabled; the
## radio buttons show how the desktop will lay the chosen wallpaper out.

const _Monitor := preload("res://win95/applets/display_monitor.gd")
const _NONE := "(None)"
const _WINDOWS := "C:\\WINDOWS"

## The wallpapers of a stock Win95's C:\WINDOWS, by the name that the list shows.
@export var stock_wallpapers: Dictionary[String, Texture2D] = {}
## The wallpaper that is only the desktop colour, so that the list selects (None) for it.
@export var plain_desktop: Texture2D
## The names that the Pattern list shows, in order.
@export var patterns: PackedStringArray = []

## The texture of each row of %Wallpapers; null for (None).
var _textures: Array[Texture2D] = []
var _picked := false

@onready var _list: ItemList = %Wallpapers
@onready var _monitor: _Monitor = %Monitor


func _ready() -> void:
	for pattern in patterns:
		%Patterns.add_item(pattern)
	%Patterns.select(0)
	_list.item_selected.connect(func(index: int) -> void:
		_picked = true
		_show(_textures[index])
		edited.emit())


func load_from(computer: ComputerState) -> void:
	var setup := computer.setup
	var current := setup.wallpaper
	var named := wallpapers(setup)
	var names := named.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	_list.clear()
	_textures.clear()
	_list.add_item(_NONE)
	_textures.append(null)
	for wallpaper_name: String in names:
		_list.add_item(wallpaper_name)
		_textures.append(named[wallpaper_name])
	var shown: Texture2D = null if current == plain_desktop else current
	var row := _textures.find(shown)
	if row >= 0:
		_list.select(row)
		_list.ensure_current_is_visible()
	_show(shown)


func pending() -> Dictionary[StringName, Variant]:
	if not _picked or not _list.is_anything_selected():
		return {}
	return {&"wallpaper": _textures[_list.get_selected_items()[0]]}


## The wallpapers that the list offers for [param setup], by name: the stock ones, every .bmp with a
## picture in C:\WINDOWS, and the setup's wallpaper when it is none of those, named after its file,
## as Win95 adds the current wallpaper from another folder.
func wallpapers(setup: Win95Setup) -> Dictionary[String, Texture2D]:
	var found: Dictionary[String, Texture2D] = stock_wallpapers.duplicate()
	var windows := setup.file_at(_WINDOWS)
	if windows != null:
		for file: Win95File in windows.children:
			if not file.is_folder and file.picture != null and file.name.get_extension().to_lower() == "bmp":
				_add(found, _display_name(file.name.get_basename()), file.picture)
	var current := setup.wallpaper
	if current != null and current != plain_desktop and not found.values().has(current) and current.resource_path != "":
		_add(found, current.resource_path.get_file().get_basename().capitalize(), current)
	return found


# A name the list already shows keeps its first picture.
func _add(found: Dictionary[String, Texture2D], wallpaper_name: String, texture: Texture2D) -> void:
	for existing: String in found:
		if existing.nocasecmp_to(wallpaper_name) == 0:
			return
	found[wallpaper_name] = texture


# Win95 lists an all-caps short name such as REDBLK as Redblk.
static func _display_name(file_name: String) -> String:
	if file_name == file_name.to_upper():
		return file_name.substr(0, 1) + file_name.substr(1).to_lower()
	return file_name


func _show(wallpaper: Texture2D) -> void:
	var tiles := _monitor.show_wallpaper(wallpaper)
	%Tile.button_pressed = tiles
	%Center.button_pressed = not tiles
