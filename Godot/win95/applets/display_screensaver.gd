extends PropertyPage
## Display > Screen Saver: the screensaver list. Preview plays the chosen screensaver over the whole
## screen until a key or a click; only 3D Pipes is drawn, the others show black. Apply sets it.

const _PipesSaver := preload("res://win95/pipes_saver.gd")
const _NONE := "(None)"

## The screensavers that the list offers after (None), by the name that Win95 shows.
@export var savers: PackedStringArray = ["Blank Screen", "Curves and Colors", "Flying Through Space",
		"Flying Windows", "Mystify Your Mind", "Scrolling Marquee", "3D Pipes"]
## The one of [member savers] that Preview draws as pipes.
@export var pipes: String = "3D Pipes"

var _picked := false

@onready var _saver: OptionButton = $Saver
@onready var _preview: Button = $Preview


func _ready() -> void:
	_saver.clear()
	_saver.add_item(_NONE)
	for each: String in savers:
		_saver.add_item(each)
	_saver.disabled = false
	_saver.item_selected.connect(func(_index: int) -> void:
		_picked = true
		_sync_preview()
		edited.emit())
	_preview.pressed.connect(_play_preview)


func load_from(computer: ComputerState) -> void:
	var current := computer.setup.screensaver
	var row := savers.find(current) + 1 if current != "" else 0
	if row == 0 and current != "":
		push_error("Display > Screen Saver: %s is not in the list" % current)
	_saver.select(row)
	_sync_preview()


func pending() -> Dictionary[StringName, Variant]:
	if not _picked:
		return {}
	return {&"screensaver": _chosen()}


func _chosen() -> String:
	return "" if _saver.selected <= 0 else savers[_saver.selected - 1]


func _sync_preview() -> void:
	_preview.disabled = _chosen() == ""


# Over everything on the Win95 screen: the desktop's parent holds the desktop and the taskbar.
func _play_preview() -> void:
	var desktop := owner.get_parent() if owner != null else null
	var screen := desktop.get_parent() as Control if desktop != null else null
	if screen == null:
		push_error("Display > Screen Saver: not on a Win95 screen, so Preview has nowhere to play")
		return
	var saver: Control = _PipesSaver.new()
	saver.set("pipes", _chosen() == pipes)
	saver.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(saver)
