extends "res://win95/window.gd"
## CompuFun AntiVirus Setup (SETUP.EXE on the AntiVirus floppy), a Win95 setup wizard: Welcome, then
## Next copies [member program] from A: over [member copy_seconds], then "Setup is complete." It
## installs through ComputerState.install. On a computer that has it already, Next says so instead;
## a disk that left A: while it copied fails the copy, and nothing is installed.

## The wizard went to another page: [param page] is one of WELCOME, COPYING, DONE, INSTALLED, FAILED.
signal page_changed(page: StringName)

## The program that Setup installs, such as AV.EXE with its icon and its program (the scanner).
@export var program: Win95File
## The installed program's folder in C:\Program Files, and the name of its shortcuts and in
## installed_apps.
@export var app_name: String = "CompuFun AntiVirus"
## The packed program on the floppy in A: that Setup copies from, such as "AV.EX_". It must still be
## there when the copy ends.
@export var source_name: String = "AV.EX_"
## How long the copy takes, in seconds.
@export var copy_seconds: float = 3.0
## The text of each page. Welcome's and Done's take [member app_name].
@export_multiline var welcome_text: String = "Welcome to %s Setup.\n\nThis program will install %s on your computer.\n\nClick Next to continue, or Cancel to quit Setup."
@export_multiline var copying_text: String = "Copying files..."
@export_multiline var done_text: String = "Setup is complete.\n\nTo scan your computer, double-click %s on the desktop."
@export_multiline var installed_text: String = "%s is already installed on this computer."
## Takes the path of the source on A:.
@export_multiline var failed_text: String = "Setup cannot read %s.\n\nPut the disk back in drive A: and run Setup again."

var _computer: ComputerState
var _page: StringName = &""
var _done: float = 0.0

@onready var _text: Label = %Text
@onready var _file: Label = %File
@onready var _progress: ProgressBar = %Progress
@onready var _back: Button = %Back
@onready var _next: Button = %Next
@onready var _cancel: Button = %Cancel


func _ready() -> void:
	super()
	var desktop := get_parent() as Win95Desktop
	_computer = desktop.computer if desktop != null else null
	if program == null:
		push_error("CompuFun AntiVirus Setup: %s has no program to install" % scene_file_path)
	_next.pressed.connect(next)
	_cancel.pressed.connect(close)
	set_process(false)
	_show(&"WELCOME")


## The page that shows: WELCOME, COPYING, DONE, INSTALLED or FAILED.
func page() -> StringName:
	return _page


## What the page says.
func text() -> String:
	return _text.text


## Next or Finish, as its button does: from Welcome it starts the copy, or says that the program is
## installed already; on a last page it closes the window.
func next() -> void:
	match _page:
		&"WELCOME":
			if _computer == null or _computer.setup == null or program == null:
				push_error("CompuFun AntiVirus Setup: no computer or no program to install; the window must open on a Win95Desktop")
				return
			_show(&"INSTALLED" if _computer.is_installed(program.name, app_name) else &"COPYING")
		&"DONE", &"INSTALLED", &"FAILED":
			close()


## Closes the window for good, as Setup exits; a copy that runs stops, and nothing is installed.
func close() -> void:
	set_process(false)
	super()
	queue_free()


func _process(delta: float) -> void:
	_done = minf(1.0, _done + delta / maxf(copy_seconds, 0.001))
	_progress.value = _done * 100.0
	if _done < 1.0:
		return
	set_process(false)
	var source := _computer.setup.floppy_files.filter(func(file: Win95File) -> bool: return file.name.nocasecmp_to(source_name) == 0)
	if source.is_empty():
		_show(&"FAILED")
		return
	_show(&"DONE" if _computer.install(program, app_name) != null else &"FAILED")


func _show(page_name: StringName) -> void:
	_page = page_name
	var copying := page_name == &"COPYING"
	_file.visible = copying
	_progress.visible = copying
	_back.disabled = true
	_next.disabled = copying
	_next.text = "Next >" if page_name in [&"WELCOME", &"COPYING"] else "Finish"
	_cancel.disabled = page_name not in [&"WELCOME", &"COPYING"]
	match page_name:
		&"WELCOME":
			_text.text = welcome_text.replace("%s", app_name)
		&"COPYING":
			_text.text = copying_text
			_file.text = "C:\\Program Files\\%s\\%s" % [app_name, program.name]
			_done = 0.0
			_progress.value = 0.0
			set_process(true)
		&"DONE":
			_text.text = done_text.replace("%s", app_name)
		&"INSTALLED":
			_text.text = installed_text.replace("%s", app_name)
		&"FAILED":
			_text.text = failed_text.replace("%s", "A:\\" + source_name)
	page_changed.emit(page_name)
