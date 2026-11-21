extends "res://win95/window.gd"
## The Properties dialog of a file or folder: its icon, name, type, location and, for a folder,
## what it contains.

## The file types that Win95 names, by extension.
const _TYPES := {
	"EXE": "Application",
	"COM": "MS-DOS Application",
	"BAT": "MS-DOS Batch File",
	"TXT": "Text Document",
	"DOC": "WordPad Document",
	"INI": "Configuration Settings",
	"SYS": "System file",
	"DLL": "Application Extension",
	"BMP": "Bitmap Image",
	"MID": "MIDI Sequence",
	"WAV": "Wave Sound",
	"LOG": "Text Document",
}


func _ready() -> void:
	super()
	%Ok.pressed.connect(close)
	%Cancel.pressed.connect(close)


## Fills the dialog for [param file], which is in [param location] (for example "C:\\WINDOWS").
func show_file(file: Win95File, location: String) -> void:
	%TitleBar.title = "%s Properties" % file.name
	%Icon.texture = file.icon
	%Name.text = file.name
	%Type.text = type_name(file)
	%Location.text = location
	%ContainsLabel.visible = file.is_folder
	%Contains.visible = file.is_folder
	if file.is_folder:
		var folders := 0
		for child: Win95File in file.children:
			if child.is_folder:
				folders += 1
		%Contains.text = "%d Files, %d Folders" % [file.children.size() - folders, folders]


## What Win95 calls the type of [param file]: "File Folder", "Application", "TXT File" and so on.
static func type_name(file: Win95File) -> String:
	if file.is_folder:
		return "File Folder"
	var dot := file.name.rfind(".")
	if dot < 0:
		return "File"
	var extension := file.name.substr(dot + 1).to_upper()
	return _TYPES.get(extension, "%s File" % extension)
