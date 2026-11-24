class_name Win95File
extends Resource
## A file or folder on a customer's computer, on the desktop or on drive C.

## The name with its extension, for example "PBRUSH.EXE".
@export var name: String = ""
## A 32 x 32 texture.
@export var icon: Texture2D
@export var is_folder: bool = false
## One of Win95's own desktop icons, by its node in win95/desktop_icons.tscn, such as &"MyComputer":
## the icon opens what that node opens. Empty for a file. Win95Setup.copy adds them.
@export var system: StringName = &""
## Where the icon stands on the desktop, in pixels from its top left. ZERO lines it up with the
## others, column by column. Folder windows ignore it.
@export var desktop_position := Vector2.ZERO
## For a program file such as NOTEPAD.EXE: the app that it runs. Win95 runs it only while the name
## ends in .EXE, and the app's `opens` says which files it opens. Null for other files.
@export var program: PackedScene
## For a shortcut (a .LNK file, whose extension Win95 hides): the path of the file that it opens,
## such as "C:\WINDOWS\NOTEPAD.EXE". Empty for other files.
@export var target: String = ""
## The text of a text file, which Notepad shows and saves.
@export_multiline var contents: String = ""
## The picture of a .bmp file, which Paint shows and saves. Null for a blank canvas.
@export var picture: Texture2D
## The sound of a .mid file, which Media Player plays: a recording, as Godot plays no MIDI.
@export var sound: AudioStream
## The date that Properties shows as Modified, as Win95 writes it: "Tuesday, March 12, 1996 4:05:12 PM".
## Empty hides it.
@export var modified: String = ""
## For a .CPL file in C:\WINDOWS\SYSTEM: the Control Panel icons that it holds. Win95 lists them only
## while the name ends in .CPL.
@export var applets: Array[Applet] = []
## The files in this folder (Win95File only). Empty for a file.
@export_custom(PROPERTY_HINT_TYPE_STRING, "24/17:Win95File") var children: Array[Resource] = []  # Array[Win95File] here leaks: the script would reference itself


## The 16 x 16 version of [param icon], a 32 x 32 icon named like name_32.png, or null when the
## icon set has none.
static func small_icon(texture: Texture2D) -> Texture2D:
	if texture == null or not texture.resource_path.ends_with("_32.png"):
		return null
	var small := texture.resource_path.trim_suffix("_32.png") + "_16.png"
	return load(small) if ResourceLoader.exists(small) else null


## The size in bytes that Properties shows: the text with Win95's CRLF line ends, or the picture
## as a 24-bit BMP. 0 for other files.
func size_in_bytes() -> int:
	if picture != null:
		var row := (picture.get_width() * 3 + 3) & ~3  # rows pad to 4 bytes
		return 54 + row * picture.get_height()
	return contents.to_utf8_buffer().size() + contents.count("\n")


## The value of [param property] on [param program]'s root: as the scene sets it, else the root
## script's default; null when the root has no such property. Reads it without making the scene.
static func root_property(scene: PackedScene, property: StringName) -> Variant:
	var state := scene.get_state()
	var script: Script
	for i in state.get_node_property_count(0):
		var property_name := state.get_node_property_name(0, i)
		if property_name == property:
			return state.get_node_property_value(0, i)
		if property_name == &"script":
			script = state.get_node_property_value(0, i)
	if script == null:
		return null
	var bare: Object = script.new()  # get_property_default_value returns null outside the editor (docs/gotchas.md)
	var value: Variant = bare.get(property)
	if bare is Node:
		bare.free()
	return value


## True when the root script of [param program] is [param base] or extends it. Reads the scene
## without making it.
static func root_extends(scene: PackedScene, base: Script) -> bool:
	var state := scene.get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"script":
			var script: Script = state.get_node_property_value(0, i)
			while script != null:
				if script == base:
					return true
				script = script.get_base_script()
	return false
