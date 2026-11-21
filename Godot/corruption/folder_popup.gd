extends CorruptionSign
## A Win95 folder window floats in the shop, in front of the Main view. A click on its [X], or
## [member close_seconds] of the player facing it, closes it for good: stage 2.

## The view that faces the window; the close timer runs only while the player is in it.
const FACING_VIEW: StringName = &"Main"

## The seconds that the player can face the window before it closes by itself. 0: only the [X] closes it.
@export var close_seconds: float = 15.0

var _faced: float = 0.0

@onready var _screen: SubViewport = %Screen
@onready var _sheet: MeshInstance3D = %Sheet
@onready var _close: Hotspot = %CloseHotspot


func _ready() -> void:
	(_sheet.material_override as StandardMaterial3D).albedo_texture = _screen.get_texture()
	_close.clicked.connect(func(_hotspot: Hotspot) -> void: set_stage(2))
	super()


func _apply(shown_stage: int) -> void:
	var shown := shown_stage == 1
	_sheet.visible = shown
	if _close.input_ray_pickable != shown:  # set_enabled resets the cursor, which another hotspot may own
		_close.set_enabled(shown)
	_screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
	set_process(shown and close_seconds > 0.0)
	if not shown:
		_faced = 0.0


func _process(delta: float) -> void:
	if Game.view != FACING_VIEW:
		return
	_faced += delta
	if _faced >= close_seconds:
		set_stage(2)
