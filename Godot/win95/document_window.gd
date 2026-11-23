extends "res://win95/window.gd"
## A window that edits one file on the computer, such as Notepad or Paint: titled "todo.txt -
## Notepad", it saves into the computer's running copy with File > Save, and asks before New or
## Close throw away unsaved changes. Without a file it is "Untitled" and can't save.
## The scene has a %File PopupMenu with the ids of FileMenu.

enum FileMenu { NEW, CLOSE, SAVE }

## The file that the window shows and saves; null for Untitled.
var file: Win95File

var _state: ComputerState
var _app_title: String


func _ready() -> void:
	super()
	_app_title = %TitleBar.title
	%File.id_pressed.connect(_on_file_menu)
	_retitle()


## Shows [param opened], a file in [param state]'s running copy, where Save writes it.
func open_file(opened: Win95File, state: ComputerState) -> void:
	file = opened
	_state = state
	_load(file)
	_retitle()


## Saves into the file, if there is one.
func save() -> void:
	if file != null and _state != null:
		_save(_state, file)


func request_close() -> void:
	_settle(close)


## Shows [param from], or a blank document when it is null.
func _load(_from: Win95File) -> void:
	pass


## Writes the document into [param into] through [param state].
func _save(_state_: ComputerState, _into: Win95File) -> void:
	pass


func _is_dirty() -> bool:
	return false


## The Yes/No/Cancel question about unsaved changes to [param path].
func _unsaved_question(path: String) -> String:
	return "Save changes to %s?" % path


# Calls [param then] at once, or after the player said Yes (and it saved) or No to saving.
func _settle(then: Callable) -> void:
	if file == null or _state == null or not _is_dirty():
		then.call()
		return
	var desktop := get_parent() as Win95Desktop
	if desktop == null:
		push_error("%s: not on a Win95Desktop, so it can't ask to save %s" % [_app_title, file.name])
		return
	var box: Node = desktop.open(preload("res://win95/message_box.tscn"), false)
	box.closed.connect(box.queue_free)
	box.answered.connect(func(button: String) -> void:
		if button == "Yes":
			save()
		if button != "Cancel":
			then.call())
	box.ask(_app_title, _unsaved_question(_state.path_of(file)))
	box.belong_to(self)


func _retitle() -> void:
	%TitleBar.title = "%s - %s" % [file.name if file != null else "Untitled", _app_title]
	%File.set_item_disabled(%File.get_item_index(FileMenu.SAVE), file == null)


func _on_file_menu(id: int) -> void:
	match id:
		FileMenu.NEW:
			_settle(func() -> void:
				file = null
				_load(null)
				_retitle())
		FileMenu.SAVE:
			save()
		FileMenu.CLOSE:
			request_close()
