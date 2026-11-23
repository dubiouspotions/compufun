extends Control
## The Win95 screen of one job's computer. It shows NO SIGNAL while the computer is off, and on
## boot it rebuilds the desktop from %ComputerState's setup: palette, wallpaper, desktop icons,
## folders, the Recycle Bin and sound. Right-click menus act on the setup through %ComputerState,
## and every icon view lists the setup again after each change. While the cable is on another
## computer, BenchScreen parks it in a viewport that draws nothing: it runs on, but plays its Win95
## sounds silently and leaves the shared palette and the Win95 bus to the computer on the cable.

const _BOOT := preload("res://win95/boot_sequence.tscn")
const _FLOPPY_IN := preload("res://sounds/floppy_insert.tres")
const _FLOPPY_OUT := preload("res://sounds/floppy_eject.tres")
const _BLUESCREEN := preload("res://win95/bluescreen.tscn")
const _GpuArtifacts := preload("res://win95/gpu_artifacts.gd")
const _FOLDER := preload("res://win95/folder_window.tscn")
const _PROPERTIES := preload("res://win95/properties_window.tscn")
const _MESSAGE := preload("res://win95/message_box.tscn")
const _CLOSE_PROGRAM := preload("res://win95/close_program.tscn")
## The keys that open Close Program with Ctrl+Alt: Del, End as Remote Desktop sends it, and
## Backspace for keyboards without Del. A Windows host keeps Ctrl+Alt+Del to itself.
const _CLOSE_PROGRAM_KEYS: Array[Key] = [KEY_DELETE, KEY_END, KEY_BACKSPACE]
const _BIN_EMPTY := preload("res://win95/theme/icons/recycle_bin_empty_32.png")
const _BIN_FULL := preload("res://win95/theme/icons/recycle_bin_full_32.png")
const _COVER := preload("res://win95/cover_screen.gd")
const _DESKTOP_ICONS := preload("res://win95/desktop_icons.tscn")
const _CRUSH := preload("res://shaders/psx_post.gdshader")
## The applet that the desktop's Properties opens. Loaded when used: a preload here cycles.
const _DISPLAY := "res://win95/applets/display.tres"
const _SHARED_PALETTE := preload("res://win95/theme/palette.tres")
const _ICONS := "res://win95/theme/icons/"
## The meta key on a FileIcon that holds its Win95File, or its Applet in the Control Panel.
const _FILE_META := &"win95_file"
## The meta key on a Win95 sound player that holds its own volume_db while the computer is off the cable.
const _OWN_DB := &"win95_own_db"
const _SILENT_DB := -80.0
## The View submenu's items: action id to folder view and label.
const _VIEW_IDS := {&"large_icons": [IconView.FolderView.LARGE_ICONS, "Large Icons"], &"small_icons": [IconView.FolderView.SMALL_ICONS, "Small Icons"],
	&"list": [IconView.FolderView.LIST, "List"], &"details": [IconView.FolderView.DETAILS, "Details"]}

## What an icon view shows: the desktop, a folder, drive C, My Computer, the Control Panel or the
## Recycle Bin.
class Listing:
	extends RefCounted
	var title: String = ""
	## 32 x 32; the title bar shows its 16 px twin.
	var icon: Texture2D
	var kind: StringName = &"folder"
	## Returns the Array of Win95Files, or of Applets for the Control Panel, to show. For a folder,
	## the desktop or drive C it is the live Array, which New Folder adds to.
	var files: Callable
	var creatable: bool = false
	## What the listing shows: a folder's Win95File, or a name such as &"drive_c". Two windows never
	## show the same key; opening it again brings the open one to the front.
	var key: Variant

	func _init(listing_title: String, listing_icon: Texture2D, listing_kind: StringName, listing_files: Callable, can_create: bool, listing_key: Variant) -> void:
		title = listing_title
		icon = listing_icon
		kind = listing_kind
		files = listing_files
		creatable = can_create
		key = listing_key


## pointer_visible changed.
signal pointer_changed

## Plays when the player empties the Recycle Bin; null plays nothing.
@export var empty_bin_sound: AudioStream
## The looped buzz of a hung sound card, from the moment a hanging Windows freezes until it reboots.
## tools/make_hang_buzz.sh cuts it from the startup sound.
@export var hang_buzz: AudioStream = preload("res://win95/sounds/hang_buzz.wav")
## The seconds from the start of a hang until Windows freezes and the buzz starts.
@export var hang_sag_seconds: float = 0.8
## How far the sounds' pitch sags before Windows freezes; 1 keeps it.
@export_range(0.1, 1.0) var hang_pitch: float = 0.8

## Win95 shows the mouse pointer: false while the computer is off and while it boots, until the
## desktop appears, and while a screensaver (a [Saver] child) plays. Setting it doesn't show the
## pointer over a screensaver.
var pointer_visible := false:
	get:
		return _pointer_on and not _saver_up
	set(value):
		if value != _pointer_on:
			_pointer_on = value
			pointer_changed.emit()

## How long a folder takes to open on a fragmented drive C.
const _FRAGMENTED_OPEN_SECONDS := 2.0

var _pointer_on := false
var _saver_up := false

static var _stock_palette: Win95Palette
## What each of Win95's own icons opens, by its node name in desktop_icons.tscn: [opens, stub].
var _system_icons: Dictionary[StringName, Array] = {}
var _listings: Dictionary[IconView, Listing] = {}
var _drive_a: Win95File
var _drive_c: Win95File
var _drive_d: Win95File
var _control_panel: Win95File
var _drives: Array[Win95File] = []
var _context: ContextMenu
var _context_view: IconView
var _context_item: FileIcon
## The files that Cut picked, for the next Paste.
var _cut: Array[Win95File] = []
var _boot: Node
## Whether a floppy was in A: at the last change, to hear it go in or out.
var _floppy_heard: bool = false
## Counts hangs, so that a boot or a power cut stops the one in progress.
var _hangs: int = 0
var _buzz: AudioStreamPlayer
## The bluescreen of a hang with a message (Problem.hang_message), until the reboot; null otherwise.
var _hang_screen: Control

@onready var _state: ComputerState = %ComputerState
@onready var _desktop: Win95Desktop = $Desktop
@onready var _background: TextureRect = $Desktop/DesktopBackground
@onready var _icons: IconView = $Desktop/DesktopIcons
@onready var _systray: Node = %Systray
@onready var _taskbar: Control = $TaskBar
@onready var _start_button: Control = $TaskBar/HBoxContainer/StartButton
@onready var _task_buttons: Control = %TaskButtons
@onready var _no_signal: Control = %NoSignal


func _ready() -> void:
	_desktop.computer = _state
	child_entered_tree.connect(_on_child_changed)
	child_exiting_tree.connect(_on_child_changed)
	var artifacts: Control = _GpuArtifacts.new()
	artifacts.set("state", _state)
	add_child(artifacts)
	if _stock_palette == null:
		_stock_palette = _SHARED_PALETTE.duplicate() as Win95Palette
	_state.booted.connect(_on_booted)
	_state.powered_off.connect(_on_powered_off)
	_state.shut_down_done.connect(_on_shut_down)
	_state.hanging.connect(_on_hanging)
	_buzz = AudioStreamPlayer.new()
	_buzz.stream = hang_buzz
	_buzz.bus = Win95Desktop.SOUND_BUS
	_buzz.process_mode = Node.PROCESS_MODE_ALWAYS  # it buzzes while the rest is stuck
	add_child(_buzz)
	_state.changed.connect(_on_changed)
	_context = ContextMenu.new()
	add_child(_context)
	_context.chosen.connect(_on_action)
	_taskbar.gui_input.connect(_on_taskbar_input)
	# desktop_icons.tscn's icons are the template; the setup's files show them (Win95File.system).
	for template: FileIcon in _icons.get_children():
		_system_icons[template.name] = [template.opens, template.stub]
		_icons.remove_child(template)
		template.free()
	_wire_view(_icons)
	_systray.computer = _state
	_systray.mute_toggled.connect(func(_muted: bool) -> void: _state.set_sound(_systray.volume, _systray.muted))
	_systray.volume_changed.connect(func(_volume: float) -> void: _state.set_sound(_systray.volume, _systray.muted))
	_no_signal.visible = not _state.is_on
	if _state.is_on:
		_on_booted()
	_apply_speakers()


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)
	if is_node_ready():
		if _state.is_on and _on_cable():
			_apply_palette(_state.setup.palette)
			_apply_sound()
		_apply_speakers()


func _exit_tree() -> void:
	get_tree().node_added.disconnect(_on_node_added)


# Ctrl+Alt+Del on the desktop opens Close Program, and pressed again restarts the computer. NT's
# Ctrl+Shift+Esc opens it too, as Windows hosts keep Ctrl+Alt+Del for themselves.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not (_state.is_on and pointer_visible):
		return
	var reboot_keys := key.ctrl_pressed and key.alt_pressed and key.keycode in _CLOSE_PROGRAM_KEYS
	if not reboot_keys and not (key.ctrl_pressed and key.shift_pressed and key.keycode == KEY_ESCAPE):
		return
	get_viewport().set_input_as_handled()
	var open := _close_program()
	if open != null and reboot_keys:
		open.call(&"restart")
	elif open == null:
		_open_close_program()


func _close_program() -> Node:
	for window in _desktop.windows():
		if window.scene_file_path == _CLOSE_PROGRAM.resource_path:
			return window
	return null


func _open_close_program() -> void:
	var open := _close_program()
	if open != null:
		_desktop.activate(open)
		return
	var dialog: Node = _desktop.open(_CLOSE_PROGRAM, false)
	dialog.closed.connect(dialog.queue_free)


# A right-click on the taskbar offers Close Program, as NT 4.0's taskbar offers Task Manager.
func _on_taskbar_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_RIGHT and not click.pressed and _state.is_on and pointer_visible:
		_context_view = null
		_context.open(click.global_position, [ContextMenu.item("Close Program...", &"close_program")] as Array[ContextMenu.Entry])


# The computer is on the VGA cable, so its picture is on the bench screen and its sound card reaches the speakers.
func _on_cable() -> bool:
	return is_inside_tree() and _state != null and _state.job != null and _state.job == Game.connected


func _on_node_added(node: Node) -> void:
	if node is AudioStreamPlayer and is_ancestor_of(node):
		_speak(node, _on_cable())


# Off the cable the Win95 sounds play on silently, so the cable picks up a sound where it is.
func _apply_speakers() -> void:
	var aloud := _on_cable()
	for player: AudioStreamPlayer in find_children("*", "AudioStreamPlayer", true, false):
		_speak(player, aloud)


func _speak(player: AudioStreamPlayer, aloud: bool) -> void:
	if player.bus != Win95Desktop.SOUND_BUS:
		return
	var silenced := player.has_meta(_OWN_DB)
	if aloud and silenced:
		player.volume_db = player.get_meta(_OWN_DB)
		player.remove_meta(_OWN_DB)
	elif not aloud and not silenced:
		player.set_meta(_OWN_DB, player.volume_db)
		player.volume_db = _SILENT_DB


func _on_booted() -> void:
	_end_hang()
	var setup := _state.setup
	_desktop.close_all()
	_uncover()
	_apply_look()
	_drive_a = _folder("3\u00bd Floppy (A:)", "drive_floppy_35_32.png")
	_drive_c = _folder("(C:)", "drive_hard_32.png")
	_drive_d = _folder("(D:)", "drive_cdrom_32.png")
	_control_panel = _folder("Control Panel", "folder_control_panel_32.png")
	_drives.assign([_drive_a, _drive_c, _drive_d,
		_control_panel, _folder("Printers", "folder_printers_32.png")])
	_listings.clear()
	_listings[_icons] = Listing.new("Desktop", null, &"desktop", func() -> Array: return _state.setup.desktop, true, &"desktop")
	_fill(_icons)
	_apply_sound()
	if is_instance_valid(_boot):
		_boot.queue_free()
	if _state.job != null and _state.job.post_fault() != Job.Fault.NONE:
		pointer_visible = false
		_no_signal.show()  # the BIOS stops before the video card sends a picture
		return
	_no_signal.hide()
	_boot = _BOOT.instantiate()
	_boot.floppy_in_a = setup.floppy_in_a
	if _state.job != null:
		var computer := _state.job.customer.computer
		var hardware: Hardware = computer.hardware.duplicate() if computer != null and computer.hardware != null else Hardware.new()
		hardware.memory_kb = int(hardware.memory_kb * _state.job.memory_share())
		if not _state.job.has(&"hard_drive"):
			hardware.hard_drive = ""
		_boot.hardware = hardware
		_boot.memory_fails = _state.job.memory_fails()
	_floppy_heard = setup.floppy_in_a
	_boot.desktop_parts = _desktop_parts
	pointer_visible = false
	_boot.finished.connect(func() -> void:
		pointer_visible = true
		_state.reached_desktop()
		_open_startup())
	if setup.fragmented:
		_boot.splash_seconds *= 3.0  # a fragmented disk loads Windows slowly
	add_child(_boot)
	move_child(_boot, _no_signal.get_index())


# The parts that appear one by one after the boot: the wallpaper, each desktop icon, the windows,
# the taskbar, then its Start button, task buttons and tray.
func _desktop_parts() -> Array[CanvasItem]:
	var parts: Array[CanvasItem] = []
	if _background.texture != null:
		parts.append(_background)
	for item: Node in _icons.get_children():
		if item is CanvasItem and (item as CanvasItem).visible and not item.is_queued_for_deletion():
			parts.append(item)
	parts.append_array(_desktop.windows().filter(func(window: Control) -> bool: return window.visible))
	parts.append_array([_taskbar, _start_button])
	parts.append_array(_task_buttons.get_children())
	parts.append(_systray)
	return parts


func _on_powered_off() -> void:
	_end_hang()
	pointer_visible = false
	if is_instance_valid(_boot):
		_boot.queue_free()
	_uncover()
	_no_signal.show()


# The shut-down screen (win95/shut_down.gd covers the screen with it) stays until the power goes off.
func _on_shut_down() -> void:
	_end_hang()
	pointer_visible = false
	_desktop.close_all()
	if is_instance_valid(_boot):
		_boot.queue_free()


func _on_child_changed(child: Node) -> void:
	if child is Saver:
		_sync_saver.call_deferred()  # a child that is exiting is still among the children


func _sync_saver() -> void:
	var up := get_children().any(func(child: Node) -> bool: return child is Saver)
	if up != _saver_up:
		_saver_up = up
		pointer_changed.emit()


func _uncover() -> void:
	for child in get_children():
		if child.get_script() == _COVER:
			child.queue_free()


# The setup's colour scheme and wallpaper, as they are now: on boot and after every change.
func _apply_look() -> void:
	var setup := _state.setup
	if _on_cable():
		_apply_palette(setup.palette)
	_background.texture = setup.wallpaper
	var shot := setup.wallpaper as DesktopScreenshot
	if shot != null and not shot.taken:
		_take_screenshot(shot)
	if setup.wallpaper != null:
		_background.stretch_mode = wallpaper_stretch(setup.wallpaper, _background.size.x)


# Draws the prank's screenshot offscreen: the desktop as it showed shot's icons on its wallpaper,
# through psx_post for the colours that it loses. The taskbar is left out: the real one covers it.
func _take_screenshot(shot: DesktopScreenshot) -> void:
	shot.taken = true
	var viewport := _offscreen()
	var crush := ShaderMaterial.new()
	crush.shader = _CRUSH
	crush.set_shader_parameter(&"color_levels", shot.color_levels)
	crush.set_shader_parameter(&"dither", shot.dither)
	var container := SubViewportContainer.new()
	container.material = crush
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.size = DesktopScreenshot.SIZE
	viewport.add_child(container)
	var inner := _offscreen()
	container.add_child(inner)
	var desk := Control.new()
	desk.theme = theme
	desk.size = DesktopScreenshot.SIZE
	inner.add_child(desk)
	desk.add_child(_desktop.get_node(^"DesktopColour").duplicate())
	var background := _background.duplicate() as TextureRect
	background.texture = shot.wallpaper
	if shot.wallpaper != null:
		background.stretch_mode = wallpaper_stretch(shot.wallpaper, DesktopScreenshot.SIZE.x)
	desk.add_child(background)
	var icons := _DESKTOP_ICONS.instantiate() as IconView
	for template in icons.get_children():
		template.free()
	desk.add_child(icons)
	for file in shot.icons:
		_add_icon(icons, file, true)
	add_child(viewport)
	for i in 3:  # the icons lay out over the first frames
		await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	if image == null or image.is_empty():
		push_error("Win95: the desktop screenshot of the prank drew nothing, so the wallpaper stays black")
		return
	shot.set_image(image)


# Before the desktop's icons are remade, each one still there keeps the place where the player saw it,
# so others leaving its column don't move it. The first layout can't pin: its labels aren't sized yet.
func _pin_desktop(still_there: Array) -> void:
	for item in _icons.get_children():
		var file := _file_of(item)
		if file != null and file.desktop_position == Vector2.ZERO and still_there.has(file):
			file.desktop_position = item.position


static func _offscreen() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = DesktopScreenshot.SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS  # its texture shows nowhere
	return viewport


## How a desktop [param screen_width] pixels wide shows [param wallpaper], as Win95 showed them:
## a small pattern tiles, a picture fills the screen.
static func wallpaper_stretch(wallpaper: Texture2D, screen_width: float) -> TextureRect.StretchMode:
	return TextureRect.STRETCH_TILE if wallpaper.get_width() * 2 < screen_width else TextureRect.STRETCH_KEEP_ASPECT_CENTERED


# Windows stops answering at once: nothing here processes, so clicks and keys do nothing; the
# pointer still moves, as it did on a hung Win95. The sounds play on, sagging, then Windows freezes
# and the sound card loops its last moment as a buzz until the reboot.
func _on_hanging(_seconds: float) -> void:
	_hangs += 1
	var hang := _hangs
	process_mode = Node.PROCESS_MODE_DISABLED
	var message := _state.job.problem.hang_message if _state.job != null and _state.job.problem != null else ""
	if message != "":
		for player: AudioStreamPlayer in _sounds():
			player.stop()
		_hang_screen = _BLUESCREEN.instantiate() as Control
		_hang_screen.set("dismissable", false)
		(_hang_screen.get_node(^"Center/Column/Message") as Label).text = message
		add_child(_hang_screen)
		return
	if is_instance_valid(_boot):
		_boot.process_mode = Node.PROCESS_MODE_ALWAYS  # it plays the startup sound
	for player: AudioStreamPlayer in _sounds():
		player.create_tween().tween_property(player, "pitch_scale", player.pitch_scale * hang_pitch, hang_sag_seconds)
	await get_tree().create_timer(hang_sag_seconds).timeout
	if hang != _hangs:
		return
	var pitch := hang_pitch
	for player: AudioStreamPlayer in _sounds():
		pitch = player.pitch_scale
		player.stop()
	_buzz.pitch_scale = pitch
	_buzz.play()


# The sounds playing on this computer, but the buzz.
func _sounds() -> Array[AudioStreamPlayer]:
	var playing: Array[AudioStreamPlayer] = []
	for player: AudioStreamPlayer in find_children("*", "AudioStreamPlayer", true, false):
		if player != _buzz and player.playing:
			playing.append(player)
	return playing


func _end_hang() -> void:
	_hangs += 1
	_buzz.stop()
	if is_instance_valid(_hang_screen):
		_hang_screen.queue_free()
	_hang_screen = null
	process_mode = Node.PROCESS_MODE_INHERIT


# Every bevel draws with the one shared palette; the desktop on screen sets it, also on entering the tree.
func _apply_palette(palette: Win95Palette) -> void:
	var source := _stock_palette if palette == null or palette == _SHARED_PALETTE else palette
	for colour in [&"face_color", &"window_color", &"highlight_color", &"light_color", &"shadow_color", &"dark_shadow_color"]:
		_SHARED_PALETTE.set(colour, source.get(colour))


func _apply_sound() -> void:
	if _state.setup == null:
		return
	_systray.volume = _state.setup.volume
	_systray.muted = _state.setup.muted
	if not _on_cable():
		return  # the bus belongs to the computer on the cable
	var bus := AudioServer.get_bus_index(Win95Desktop.SOUND_BUS)
	if bus < 0:
		push_error("Win95: no audio bus %s in default_bus_layout.tres, so Win95 sounds ignore volume and mute" % Win95Desktop.SOUND_BUS)
		return
	AudioServer.set_bus_volume_linear(bus, _state.setup.volume / 100.0)
	AudioServer.set_bus_mute(bus, _state.setup.muted)


func _on_changed() -> void:
	_apply_sound()
	if _state.setup != null:
		if _state.is_on:
			_apply_look()
		if is_instance_valid(_boot):
			_boot.floppy_in_a = _state.setup.floppy_in_a
		if _state.setup.floppy_in_a != _floppy_heard:
			_floppy_heard = _state.setup.floppy_in_a
			(_FLOPPY_IN if _floppy_heard else _FLOPPY_OUT).play_at(self)
	for view: IconView in _listings.keys():
		_fill(view)


## Lists the view's Win95Files or Applets again, keeping the selection.
func _fill(view: IconView) -> void:
	var listing: Listing = _listings[view]
	var keep: Array[Resource] = []
	for item in view.selected_items():
		var entry := _entry_of(item)
		if entry != null:
			keep.append(entry)
	var focused := _entry_of(view.focus_item()) if view.focus_item() != null else null
	var entries: Array = listing.files.call()
	if view == _icons:
		_pin_desktop(entries)
	for item: Node in view.get_children():
		view.remove_child(item)  # now, so that a new system icon gets its name
		item.queue_free()
	for entry: Resource in entries:
		var item := _add_icon(view, entry, view == _icons)
		if entry is Applet:
			item.renamable = false
			item.stub = (entry as Applet).sheet == null
			item.details = PackedStringArray([(entry as Applet).description])
		else:
			var file: Win95File = entry
			item.name_edited.connect(func(_old: String, new_text: String) -> void: _rename(view, file, new_text))
			if file.system == &"":
				item.stub = ComputerState.is_program_name(file.name) and file.program == null
			item.details = FileDetails.cells(listing.kind, file, _state)
		item.selected = keep.has(entry)
		if entry == focused:
			view.set_focus_item(item)


# The icon of a Win95File or an Applet. One of Win95's own icons is named after its node in
# desktop_icons.tscn and opens what that opens; on the desktop, a file stands at its desktop_position.
func _add_icon(view: IconView, entry: Resource, on_desktop: bool) -> FileIcon:
	var item := view.add_item(entry.get(&"name"), entry.get(&"icon"))
	item.set_meta(_FILE_META, entry)
	var file := entry as Win95File
	if file == null:
		return item
	if file.system != &"":
		item.name = file.system
		var template: Array = _system_icons.get(file.system, [null, true])
		item.opens = template[0]
		item.stub = template[1]
		if file.system == &"RecycleBin":
			item.icon = _BIN_EMPTY if _state.setup.recycle_bin.is_empty() else _BIN_FULL
	if on_desktop and file.desktop_position != Vector2.ZERO:
		view.place(item, file.desktop_position)
	return item


func _folder(folder_name: String, icon_file: String) -> Win95File:
	var folder := Win95File.new()
	folder.name = folder_name
	folder.icon = load(_ICONS + icon_file)
	folder.is_folder = true
	return folder


func _file_of(item: FileIcon) -> Win95File:
	return _entry_of(item) as Win95File


func _entry_of(item: FileIcon) -> Resource:
	return item.get_meta(_FILE_META) if item.has_meta(_FILE_META) else null


func _wire_view(view: IconView) -> void:
	view.item_opened.connect(_open_item)
	view.context_requested.connect(func(item: FileIcon, at: Vector2) -> void: _open_context(view, item, at))
	view.delete_requested.connect(func(items: Array[FileIcon]) -> void: _delete(view, items))
	view.items_dropped.connect(_on_dropped.bind(view))
	view.clipboard_requested.connect(func(action: StringName) -> void:
		_context_view = view
		_context_item = null
		_on_action(action))


func _open_item(item: FileIcon) -> void:
	var file := _file_of(item)
	var folder_view := (item.get_parent() as IconView).folder_view
	var applet := _entry_of(item) as Applet
	if applet != null:
		if applet.sheet != null:
			_desktop.open(applet.sheet)
	elif item.name == &"MyComputer":
		_show(Listing.new("My Computer", load(_ICONS + "my_computer_32.png"), &"my_computer", func() -> Array: return _drives, false, &"my_computer"), folder_view)
	elif item.name == &"RecycleBin":
		_show(Listing.new("Recycle Bin", _BIN_EMPTY, &"recycle_bin", func() -> Array: return _state.setup.recycle_bin, false, &"recycle_bin"), folder_view)
	elif file == null or file.system != &"" or _listing_of_item(item).kind == &"recycle_bin":
		return  # IconView opens a system icon's window
	elif file == _control_panel:
		open_control_panel(folder_view)
	elif file == _drive_c:
		_show(Listing.new("(C:)", file.icon, &"folder", func() -> Array: return _state.setup.drive_c, true, &"drive_c"), folder_view)
	elif file == _drive_a or file == _drive_d:
		_open_removable(file, folder_view)
	elif file.is_folder:
		_show(Listing.new(file.name, file.icon, &"folder", func() -> Array: return file.children, not _drives.has(file), file), folder_view)
	else:
		open_file(file)


# A: opens while a floppy is in it and lists its files; D: never holds a disc. An empty drive says
# so, and Retry looks again.
func _open_removable(drive: Win95File, folder_view: IconView.FolderView) -> void:
	if drive == _drive_a and _state.setup.floppy_in_a:
		_show(Listing.new(drive.name, drive.icon, &"folder", func() -> Array: return _state.setup.floppy_files, false, drive), folder_view)
		return
	var drive_path := "A:\\" if drive == _drive_a else "D:\\"
	var buttons: Array[String] = ["Retry", "Cancel"]
	var box: Node = _desktop.open(_MESSAGE, false)
	box.closed.connect(box.queue_free)
	box.answered.connect(func(button: String) -> void:
		if button == "Retry":
			_open_removable(drive, folder_view))
	box.show_message(drive_path, "%s is not accessible.\n\nThe device is not ready." % drive_path, buttons)


## Opens the Control Panel folder in [param folder_view], or brings it to the front.
func open_control_panel(folder_view := IconView.FolderView.LARGE_ICONS) -> void:
	_show(Listing.new("Control Panel", _control_panel.icon, &"control_panel", func() -> Array: return _state.control_panel(), false, &"control_panel"), folder_view)


## Opens [param file] as Win95 does: a program file runs while its name ends in .EXE or .COM;
## any other file opens in the installed program whose app lists its extension. A program file
## whose name lost its .EXE still claims the extension, so its files fail with "Cannot find the file".
## A shortcut opens its target, or fails with "Problem with Shortcut" when the target is gone.
func open_file(file: Win95File) -> void:
	if file.target != "":
		var target := _state.setup.file_at(file.target)
		if target == null or target.is_folder:
			_message("Problem with Shortcut", "The item '%s' that this shortcut refers to has been changed or moved, so this shortcut will no longer work properly." % file.target.substr(file.target.rfind("\\") + 1))
		else:
			open_file(target)
		return
	if ComputerState.is_runnable(file):
		_launch(file, null)
		return
	var programs := _state.programs_for(file.name.get_extension().to_lower())
	for program in programs:
		if ComputerState.is_runnable(program):
			_launch(program, file)
			_state.note_opened(file)
			return
	if not programs.is_empty():
		var location := _state.location_of(programs[0]).trim_suffix("\\")
		var expected := "%s\\%s.EXE" % [location, programs[0].name.get_basename().to_upper()]
		_message(file.name, "Cannot find the file '%s' (or one of its components). Make sure the path and filename are correct and that all required libraries are available." % expected)
	else:
		_message(file.name, "Windows cannot open this file:\n\n%s\n\nNo program on this computer opens files of this type." % file.name)


# A program whose scene is a BackgroundTask runs without a window; any other opens one, with [param document].
func _launch(program: Win95File, document: Win95File) -> void:
	if BackgroundTask.runs_in_background(program.program):
		_state.run_task(program.program.instantiate() as BackgroundTask, program)
		return
	var window: Node = _desktop.open(program.program)
	if document != null and window.has_method(&"open_file"):
		window.open_file(document, _state)


# Each boot that reaches the desktop opens what the StartUp folder holds, as Win95 does.
func _open_startup() -> void:
	var startup := _state.setup.file_at(Win95Setup.STARTUP_PATH)
	if startup == null:
		return
	for item: Win95File in startup.children.duplicate():
		if not item.is_folder:
			open_file(item)


func _message(title: String, text: String) -> void:
	var box: Node = _desktop.open(_MESSAGE, false)
	box.closed.connect(box.queue_free)
	box.show_message(title, text)


func _listing_of_item(item: FileIcon) -> Listing:
	return _listings.get(item.get_parent() as IconView)


# A new window takes the folder view of the window that opened it, as in Win95.
func _show(listing: Listing, folder_view: IconView.FolderView) -> void:
	if _state.setup.fragmented:
		await get_tree().create_timer(_FRAGMENTED_OPEN_SECONDS).timeout  # the disk seeks all over
	for view: IconView in _listings.keys():
		if view != _icons and is_same(_listings[view].key, listing.key) and _desktop.windows().has(view.owner):
			_desktop.activate(view.owner)
			return
	var window: Node = _desktop.open(_FOLDER, false)
	var title_bar: Node = window.get_node("%TitleBar")
	title_bar.title = listing.title
	title_bar.icon = Win95File.small_icon(listing.icon)
	var view: IconView = window.items
	_wire_view(view)
	window.closed.connect(func() -> void:
		_listings.erase(view)
		window.queue_free())
	_listings[view] = listing
	view.columns = FileDetails.columns(listing.kind)
	view.folder_view = folder_view
	_fill(view)


func _open_context(view: IconView, item: FileIcon, at: Vector2) -> void:
	_context_view = view
	_context_item = item
	_context.open(at, _entries_for(view, item))


func _entries_for(view: IconView, item: FileIcon) -> Array[ContextMenu.Entry]:
	var listing: Listing = _listings[view]
	var properties := ContextMenu.item("Properties", &"properties")
	if item == null:
		return _background_entries(listing, view)
	var multi := view.selected_items().size() > 1
	if listing.kind == &"recycle_bin":
		return _entries([["Restore", &"restore"], [], ["Cut"], [], ["Delete", &"purge"], [], properties])
	match item.name:
		&"MyComputer":
			return _entries([["Open", &"open", true], ["Explore"], ["Find..."], [], ["Map Network Drive..."],
				["Disconnect Network Drive..."], [], ["Create Shortcut"], ["Rename", &"rename"], [], ["Properties"]])
		&"RecycleBin":
			return _entries([["Open", &"open", true], ["Explore"], ContextMenu.item("Empty Recycle Bin", &"empty_bin", false, _state.setup.recycle_bin.is_empty()),
				[], ["Create Shortcut"], [], ["Properties"]])
		&"Inbox":
			return _entries([["Open", &"open", true], [], ["Create Shortcut"], ["Delete"], ["Rename"], [], ["Properties"]])
		&"NetworkNeighborhood":
			return _entries([["Open", &"open", true], ["Explore"], ["Find Computer..."], [], ["Map Network Drive..."],
				["Disconnect Network Drive..."], [], ["Create Shortcut"], ["Rename", &"rename"], [], ["Properties"]])
	var file := _file_of(item)
	if listing.kind == &"my_computer":
		return _entries([["Open", &"open", true], ["Explore"], ["Find..."], [], ["Create Shortcut"], [], properties])
	if listing.kind == &"control_panel":
		return _entries([["Open", &"open", true], [], ["Create Shortcut"]])
	var entries := _entries([["Open", &"open", true]])
	if file != null and file.is_folder:
		entries.append_array(_entries([["Explore"], ["Find..."]]))
	entries.append_array(_entries([[], ContextMenu.submenu("Send To", _entries([["3\u00bd Floppy (A)"], ["Mail Recipient"], ["My Briefcase"]])),
		[], ["Cut", &"cut"], ["Copy"], [], ["Create Shortcut"], ["Delete", &"delete"]]))
	if not multi:
		entries.append(ContextMenu.item("Rename", &"rename"))
	entries.append_array(_entries([[], properties]))
	return entries


func _background_entries(listing: Listing, view: IconView) -> Array[ContextMenu.Entry]:
	var arrange := ContextMenu.submenu("Arrange Icons", _entries([["by Name"], ["by Type"], ["by Size"], ["by Date"], [], ["Auto Arrange"]]))
	var views: Array[ContextMenu.Entry] = []
	for id: StringName in _VIEW_IDS:
		views.append(ContextMenu.item(_VIEW_IDS[id][1], id, false, false, view.folder_view == _VIEW_IDS[id][0]))
	var view_menu := ContextMenu.submenu("View", views)
	var new_menu := ContextMenu.submenu("New", _entries([["Folder", &"new_folder"], ["Shortcut"], [], ["Text Document"], ["WordPad Document"], ["Bitmap Image"], ["Wave Sound"]]))
	var paste := ContextMenu.item("Paste", &"paste", false, _cut.is_empty())
	var paste_shortcut := ContextMenu.item("Paste Shortcut", &"", false, true)
	match listing.kind:
		&"desktop":
			return _entries([arrange, ["Line up Icons"], [], paste, paste_shortcut, [], new_menu, [], ["Properties", &"display"]])
		&"recycle_bin":
			return _entries([view_menu, [], arrange, ["Line up Icons"], [], ContextMenu.item("Empty Recycle Bin", &"empty_bin", false, _state.setup.recycle_bin.is_empty()), [], ["Properties"]])
		&"my_computer":
			return _entries([view_menu, [], arrange, ["Line up Icons"], [], ["Properties"]])
	if not listing.creatable:
		return _entries([view_menu, [], arrange, ["Line up Icons"], [], ["Properties"]])
	return _entries([view_menu, [], arrange, ["Line up Icons"], [], paste, paste_shortcut, [], new_menu, [], ["Properties"]])


# Each spec is an Entry, [] for a separator, or [label, id = &"", is_default = false].
func _entries(specs: Array) -> Array[ContextMenu.Entry]:
	var entries: Array[ContextMenu.Entry] = []
	for spec: Variant in specs:
		if spec is ContextMenu.Entry:
			entries.append(spec)
		elif (spec as Array).is_empty():
			entries.append(ContextMenu.separator())
		else:
			var parts: Array = spec
			entries.append(ContextMenu.item(parts[0], parts[1] if parts.size() > 1 else &"", parts.size() > 2 and parts[2]))
	return entries


func _on_action(id: StringName) -> void:
	if id == &"close_program":
		_open_close_program()
		return
	var view := _context_view
	if not is_instance_valid(view):
		return
	var item := _context_item if is_instance_valid(_context_item) else null
	var listing: Listing = _listings[view]
	var files := _files(view.selected_items())
	if _VIEW_IDS.has(id):
		view.folder_view = _VIEW_IDS[id][0]
		return
	match id:
		&"open":
			for selected in view.selected_items():
				view.open_item(selected)
		&"rename":
			if item != null:
				item.start_rename()
		&"delete":
			_delete(view, view.selected_items())
		&"purge":
			_state.purge_files(files)
		&"restore":
			_state.restore_files(files)
		&"cut":
			if listing.creatable:
				_cut = files
		&"paste":
			if listing.creatable and not _cut.is_empty():
				_report_move(_state.move_files(_cut, listing.files.call()))
				_cut.clear()
		&"empty_bin":
			_state.empty_recycle_bin()
			Win95Desktop.play_sound(empty_bin_sound, self)
		&"new_folder":
			var folder := _state.new_folder(listing.files.call())
			_rename_new.call_deferred(view, folder)
		&"display":
			_desktop.open((load(_DISPLAY) as Applet).sheet)
		&"properties":
			var file := _file_of(item) if item != null else null
			if file != null:
				var window: Node = _desktop.open(_PROPERTIES)
				window.show_file(file, _state.location_of(file))
		_:
			push_error("Win95: no action for the menu id %s" % id)


# Drag and drop, as in Win95: onto a folder moves the files into it, onto the Recycle Bin deletes
# them, and onto empty space or a file moves them into the view's folder; on the desktop they stand
# where they were let go. The system icons stay where they are.
func _on_dropped(items: Array[FileIcon], onto: FileIcon, places: Array[Vector2], view: IconView) -> void:
	var files: Array[Win95File] = []
	var at: Array[Vector2] = []
	for i in items.size():
		var file := _file_of(items[i])
		var from := _listing_of_item(items[i])
		if file != null and from != null and from.creatable:
			files.append(file)
			at.append(places[i].clamp(Vector2.ONE, view.size - Vector2(16, 16)))
	if files.is_empty():
		return
	if onto != null and onto not in items:
		var target := _file_of(onto)
		if onto.name == &"RecycleBin":
			_report(_state.delete_files(_deletable(files)), "Error Deleting File")
			return
		if target != null and target.is_folder and not _drives.has(target):
			_report_move(_state.move_files(files, target.children))
			return
	var listing: Listing = _listings[view]
	if listing.creatable:
		if view != _icons:
			at.clear()  # only the desktop places icons
		elif items[0].get_parent() != view:
			at.resize(1)  # a folder's spacing piles icons up: the rest take free cells
		_report_move(_state.move_files(files, listing.files.call(), at))


# Win95's own icons can't be deleted.
static func _deletable(files: Array[Win95File]) -> Array[Win95File]:
	var kept: Array[Win95File] = []
	kept.assign(files.filter(func(file: Win95File) -> bool: return file.system == &""))
	return kept


func _report_move(refused: String) -> void:
	_report(refused, "Error Moving File")


# Shows why ComputerState refused a change; "" shows nothing.
func _report(refused: String, title: String) -> void:
	if refused != "":
		_message(title, refused)


func _delete(view: IconView, items: Array[FileIcon]) -> void:
	var files := _deletable(_files(items))
	if _listings[view].kind == &"recycle_bin":
		_state.purge_files(files)
	else:
		_report(_state.delete_files(files), "Error Deleting File")


# A refused rename lists the view again, so the icon shows the old name.
func _rename(view: IconView, file: Win95File, new_name: String) -> void:
	var refused := _state.rename_file(file, new_name)
	if refused != "":
		_report(refused, "Error Renaming File")
		_fill.call_deferred(view)


# Win95 names a new folder by letting the player type over "New Folder" at once.
func _rename_new(view: IconView, folder: Win95File) -> void:
	for item in view.get_children():
		if item is FileIcon and _file_of(item) == folder and not item.is_queued_for_deletion():
			view.select_only(item)
			item.start_rename()
			return


func _files(items: Array[FileIcon]) -> Array[Win95File]:
	var files: Array[Win95File] = []
	for item in items:
		var file := _file_of(item)
		if file != null:
			files.append(file)
	return files

