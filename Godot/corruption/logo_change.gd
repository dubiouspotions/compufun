extends CorruptionSign
## A change to the CompuFun logo signs: they turn Windows blue, or read CambIon. Started in play,
## the change happens while the ceiling lights are dark (CeilingLight.cover); after a jump (a new
## day, a restore) it shows at once.

## The LogoSign property that the sign turns on: &"blue" or &"cambion".
@export var property: StringName = &"blue"
## On: the sign also turns on [member CambionLabel.cambion] of every CambionLabel in the shop.
@export var renames_labels: bool = false

var _shown: bool = false
var _jump: int = -1
var _covering: bool = false


func _ready() -> void:
	var names: Array = (LogoSign as Script).get_script_property_list().map(func(each: Dictionary) -> String: return each.name)
	if not names.has(String(property)):
		push_error("%s: LogoSign has no property %s" % [scene_file_path, property])
	super()


func _apply(shown_stage: int) -> void:
	if _covering:
		return
	var on := shown_stage >= 1
	if on and not _shown and _jump == Game.jump:
		_covering = true
		CeilingLight.cover(get_tree(), func() -> void: _show(stage() >= 1))
	else:
		_show(on)
	_jump = Game.jump


func _show(on: bool) -> void:
	_covering = false
	_shown = on
	for logo: LogoSign in LogoSign.every(get_tree()):
		logo.set(property, on)
	if renames_labels:
		for label: CambionLabel in CambionLabel.every(get_tree()):
			label.cambion = on
