extends Control
## The Win95 screen of the computer on the bench. It shows NO SIGNAL while the computer is off,
## and on boot it rebuilds the desktop from %ComputerState's setup: palette, wallpaper, desktop
## icons, folders and sound. Changes the player makes go back into the setup.

const _BOOT := preload("res://win95/boot_sequence.tscn")
const _FOLDER := preload("res://win95/folder_window.tscn")
const _COVER := preload("res://win95/cover_screen.gd")
const _SHARED_PALETTE := preload("res://win95/theme/palette.tres")
const _ICONS := "res://win95/theme/icons/"
## The meta key on a FileIcon that holds its Win95File.
const _FILE_META := &"win95_file"

var _stock_palette: Win95Palette
var _setup_icons: Array[FileIcon] = []
var _my_computer: Win95File
var _boot: Node

@onready var _state: ComputerState = %ComputerState
@onready var _desktop: Win95Desktop = $Desktop
@onready var _background: TextureRect = $Desktop/DesktopBackground
@onready var _icons: IconView = $Desktop/DesktopIcons
@onready var _systray: Node = %Systray
@onready var _no_signal: Control = %NoSignal


func _ready() -> void:
	_stock_palette = _SHARED_PALETTE.duplicate() as Win95Palette
	_state.booted.connect(_on_booted)
	_state.powered_off.connect(_on_powered_off)
	_state.changed.connect(_apply_sound)
	_icons.item_opened.connect(_open_item)
	_systray.mute_toggled.connect(func(_muted: bool) -> void: _state.set_sound(_systray.volume, _systray.muted))
	_systray.volume_changed.connect(func(_volume: float) -> void: _state.set_sound(_systray.volume, _systray.muted))
	_no_signal.visible = not _state.is_on


func _on_booted() -> void:
	var setup := _state.setup
	_desktop.close_all()
	for child in get_children():
		if child.get_script() == _COVER:
			child.queue_free()
	_apply_palette(setup.palette)
	if setup.wallpaper != null:
		_background.texture = setup.wallpaper
		# As Win95 showed them: a small pattern tiles, a picture fills the screen.
		var tiles := setup.wallpaper.get_width() * 2 < _background.size.x
		_background.stretch_mode = TextureRect.STRETCH_TILE if tiles else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rebuild_desktop_icons(setup)
	_my_computer = _build_my_computer(setup)
	_apply_sound()
	_no_signal.hide()
	if is_instance_valid(_boot):
		_boot.queue_free()
	_boot = _BOOT.instantiate()
	add_child(_boot)
	move_child(_boot, _no_signal.get_index())


func _on_powered_off() -> void:
	if is_instance_valid(_boot):
		_boot.queue_free()
	_no_signal.show()


# Every bevel in the theme draws with the one shared palette, so copying colours into it recolours all.
func _apply_palette(palette: Win95Palette) -> void:
	var source := _stock_palette if palette == null or palette == _SHARED_PALETTE else palette
	for colour in [&"face_color", &"window_color", &"highlight_color", &"light_color", &"shadow_color", &"dark_shadow_color"]:
		_SHARED_PALETTE.set(colour, source.get(colour))


func _apply_sound() -> void:
	if _state.setup == null:
		return
	_systray.volume = _state.setup.volume
	_systray.muted = _state.setup.muted


func _rebuild_desktop_icons(setup: Win95Setup) -> void:
	for icon in _setup_icons:
		icon.queue_free()
	_setup_icons.clear()
	for file: Win95File in setup.desktop:
		_setup_icons.append(_add_file(_icons, file))


func _build_my_computer(setup: Win95Setup) -> Win95File:
	var drive_c := _folder("(C:)", "drive_hard_32.png", setup.drive_c)
	return _folder("My Computer", "my_computer_32.png", [
		_folder("3½ Floppy (A:)", "drive_floppy_35_32.png", []),
		drive_c,
		_folder("(D:)", "drive_cdrom_32.png", []),
		_folder("Control Panel", "folder_control_panel_32.png", []),
		_folder("Printers", "folder_printers_32.png", []),
	])


func _folder(folder_name: String, icon_file: String, children: Array) -> Win95File:
	var folder := Win95File.new()
	folder.name = folder_name
	folder.icon = load(_ICONS + icon_file)
	folder.is_folder = true
	folder.children.assign(children)
	return folder


func _add_file(view: IconView, file: Win95File) -> FileIcon:
	var item := view.add_item(file.name, file.icon)
	item.set_meta(_FILE_META, file)
	item.name_edited.connect(func(_old: String, new_text: String) -> void: _state.rename_file(file, new_text))
	return item


func _open_item(item: FileIcon) -> void:
	var file: Win95File = item.get_meta(_FILE_META) if item.has_meta(_FILE_META) else null
	if item.name == &"MyComputer" and _my_computer != null:
		file = _my_computer
	if file != null and file.is_folder:
		_open_folder(file)


func _open_folder(folder: Win95File) -> void:
	var window: Node = _desktop.open(_FOLDER)
	var title_bar: Node = window.get_node("%TitleBar")
	title_bar.title = folder.name
	title_bar.icon = _small_icon(folder.icon)
	var view: IconView = window.items
	if not view.item_opened.is_connected(_open_item):
		view.item_opened.connect(_open_item)
	view.clear()
	for child: Win95File in folder.children:
		_add_file(view, child)


# Kalle's icon set pairs every name_32.png with a name_16.png.
func _small_icon(icon: Texture2D) -> Texture2D:
	if icon == null or not icon.resource_path.ends_with("_32.png"):
		return null
	var small := icon.resource_path.trim_suffix("_32.png") + "_16.png"
	return load(small) if ResourceLoader.exists(small) else null
