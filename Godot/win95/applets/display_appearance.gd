extends PropertyPage
## Display > Appearance: the colour scheme, previewed live. Apply sets the palette. The Item, Size,
## Color and Font rows, Save As... and Delete show Win95's layout, disabled.

const _SHARED_PALETTE := preload("res://win95/theme/palette.tres")
const _Preview := preload("res://win95/applets/display_scheme_preview.gd")

## The schemes that the drop-down lists, each named by its resource_name; it shows them sorted.
@export var schemes: Array[Win95Palette] = []

var _sorted: Array[Win95Palette] = []
var _picked := false

@onready var _scheme: OptionButton = %Scheme
@onready var _preview: _Preview = %Preview


func _ready() -> void:
	_sorted = schemes.duplicate()
	_sorted.sort_custom(func(a: Win95Palette, b: Win95Palette) -> bool: return a.resource_name.naturalnocasecmp_to(b.resource_name) < 0)
	for scheme in _sorted:
		_scheme.add_item(scheme.resource_name)
	_scheme.item_selected.connect(func(index: int) -> void:
		_picked = true
		_show(_sorted[index])
		edited.emit())


func load_from(computer: ComputerState) -> void:
	var current := computer.setup.palette
	# The shared palette holds whatever scheme is on screen; as a setting it means the stock one.
	var colours := Win95Palette.new() if current == null or current == _SHARED_PALETTE else current
	_scheme.select(scheme_index(current, colours))
	_show(colours)


func pending() -> Dictionary[StringName, Variant]:
	if not _picked or _scheme.selected < 0:
		return {}
	return {&"palette": _sorted[_scheme.selected]}


## The row of [param palette] in the drop-down: the scheme itself, else the first scheme with the
## same colours and font size as [param colours]; -1 when none has them, which leaves the box empty as in Win95.
func scheme_index(palette: Win95Palette, colours: Win95Palette) -> int:
	var row := _sorted.find(palette)
	if row >= 0:
		return row
	for i in _sorted.size():
		if _sorted[i].same_scheme(colours):
			return i
	return -1


func _show(scheme: Win95Palette) -> void:
	_preview.palette.copy_scheme(scheme)
