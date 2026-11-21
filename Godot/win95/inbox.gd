extends "res://win95/window.gd"
## The Inbox: the emails in the Inbox folder, and the selected one below them. Unread ones show a
## mark; selecting one marks it read.

## Every email; the window lists those in the Inbox folder, in order.
@export var emails: Array[Email] = []

var _shown: Array[Email] = []

@onready var _list: ItemList = %List
@onready var _reader: Label = %Reader


func _ready() -> void:
	super()
	_list.item_selected.connect(_read)
	_sync()


func _read(index: int) -> void:
	var email := _shown[index]
	email.read = true
	_reader.text = "From: %s\nSubject: %s\n\n%s" % [email.from, email.subject, email.body]
	_sync()
	_list.select(index)


func _sync() -> void:
	_shown = emails.filter(func(e: Email) -> bool: return e.folder == Email.Folder.INBOX)
	_list.clear()
	for email in _shown:
		_list.add_item("%s %-16s %s" % [" " if email.read else "*", email.from, email.subject])
