class_name Win95File
extends Resource
## A file or folder on a customer's computer, on the desktop or on drive C.

## The name with its extension, for example "PBRUSH.EXE".
@export var name: String = ""
## A 32 x 32 texture.
@export var icon: Texture2D
@export var is_folder: bool = false
## For a program file such as NOTEPAD.EXE: the app that it runs. Win95 runs it only while the name
## ends in .EXE, and the app's `opens` says which files it opens. Null for other files.
@export var program: PackedScene
## The text of a text file, which Notepad shows and saves.
@export_multiline var contents: String = ""
## The picture of a .bmp file, which Paint shows and saves. Null for a blank canvas.
@export var picture: Texture2D
## The sound of a .mid file, which Media Player plays: a recording, as Godot plays no MIDI.
@export var sound: AudioStream
## The date that Properties shows as Modified, as Win95 writes it: "Tuesday, March 12, 1996 4:05:12 PM".
## Empty hides it.
@export var modified: String = ""
## The files in this folder (Win95File only). Empty for a file.
@export_custom(PROPERTY_HINT_TYPE_STRING, "24/17:Win95File") var children: Array[Resource] = []  # Array[Win95File] here leaks: the script would reference itself


## The size in bytes that Properties shows: the text with Win95's CRLF line ends, or the picture
## as a 24-bit BMP. 0 for other files.
func size_in_bytes() -> int:
	if picture != null:
		var row := (picture.get_width() * 3 + 3) & ~3  # rows pad to 4 bytes
		return 54 + row * picture.get_height()
	return contents.to_utf8_buffer().size() + contents.count("\n")
