extends "res://win95/window.gd"
## The Properties dialog of a file or folder: its icon, name, type and location; for a folder, what
## it contains; for a document, its size and, when the file says, the date it was modified.

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
	var sized := not file.is_folder and file.program == null
	%SizeLabel.visible = sized
	%Size.visible = sized
	%Size.text = size_text(file.size_in_bytes())
	%Dates.visible = file.modified != ""
	%Modified.text = file.modified
	%ContainsLabel.visible = file.is_folder
	%Contains.visible = file.is_folder
	if file.is_folder:
		var folders := 0
		for child: Win95File in file.children:
			if child.is_folder:
				folders += 1
		%Contains.text = "%d Files, %d Folders" % [file.children.size() - folders, folders]


## [param bytes] as Win95 writes a size: "426 bytes", "1.23KB (1,262 bytes)".
static func size_text(bytes: int) -> String:
	if bytes < 1024:
		return "%d bytes" % bytes
	var grouped := str(bytes)
	for i in range(grouped.length() - 3, 0, -3):
		grouped = grouped.insert(i, ",")
	var units := "%.2fKB" % (bytes / 1024.0) if bytes < 1048576 else "%.2fMB" % (bytes / 1048576.0)
	return "%s (%s bytes)" % [units, grouped]


## What Win95 calls the type of [param file]: "File Folder", "Application", "TXT File" and so on.
static func type_name(file: Win95File) -> String:
	if file.is_folder:
		return "File Folder"
	var dot := file.name.rfind(".")
	if dot < 0:
		return "File"
	var extension := file.name.substr(dot + 1).to_upper()
	return _TYPES.get(extension, "%s File" % extension)
