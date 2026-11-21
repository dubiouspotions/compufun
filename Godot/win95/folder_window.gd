extends "res://win95/window.gd"
## A Win95 folder window, as explorer.exe opens it: large icons, a menu bar, and a status bar that
## counts the icons.

enum FileMenu { CLOSE }

## The icon grid. Fill it with items.add_item(); its item_opened signal reports double-clicks.
@onready var items: IconView = %Items
@onready var _object_count: Label = %ObjectCount


func _ready() -> void:
	super()
	%File.id_pressed.connect(func(id: int) -> void:
		if id == FileMenu.CLOSE:
			close())
	%Edit.id_pressed.connect(func(_id: int) -> void: items.select_all())
	items.items_changed.connect(_sync_status)
	_sync_status()


func _sync_status() -> void:
	_object_count.text = "%d object(s)" % items.item_count()
