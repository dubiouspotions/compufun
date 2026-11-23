extends PropertyPage
## Display > Screen Saver: the screensaver list. Preview plays the chosen screensaver over the whole
## screen until a key or a click. Apply sets it.

## The screensavers that Preview draws, by the name that Win95 shows: each a script in win95/savers/
## that extends cover_screen.gd and draws over its whole rect. A name in [member savers] without one
## shows black.
const SAVERS: Dictionary[String, Script] = {
	"3D Pipes": preload("res://win95/savers/3d_pipes.gd"),
	"Blank Screen": preload("res://win95/savers/blank_screen.gd"),
	"Curves and Colors": preload("res://win95/savers/curves_and_colors.gd"),
	"Flying Through Space": preload("res://win95/savers/flying_through_space.gd"),
	"Flying Windows": preload("res://win95/savers/flying_windows.gd"),
	"Mystify Your Mind": preload("res://win95/savers/mystify_your_mind.gd"),
	"Scrolling Marquee": preload("res://win95/savers/scrolling_marquee.gd"),
}
const _COVER := preload("res://win95/cover_screen.gd")
const _NONE := "(None)"

## The screensavers that the list offers after (None), by the name that Win95 shows.
@export var savers: PackedStringArray = ["Blank Screen", "Curves and Colors", "Flying Through Space",
		"Flying Windows", "Mystify Your Mind", "Scrolling Marquee", "3D Pipes"]

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
	var drawn: Script = SAVERS.get(_chosen())
	var saver: Control = drawn.new() if drawn != null else _black()
	saver.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(saver)


func _black() -> Control:
	var cover: Control = _COVER.new()
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.add_child(black)
	return cover
