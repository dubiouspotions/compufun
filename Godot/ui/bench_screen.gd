class_name BenchScreen
extends Control
## What the bench screen shows: the desktop of the job that the cable is connected to
## (Game.connected), and NO SIGNAL while the cable hangs free.

## The shown desktop's [code]pointer_visible[/code] or [code]pointer_busy[/code] changed.
signal pointer_changed

## The desktop of one job's computer, with a %ComputerState node. Each job gets its own when it is
## first switched on or connected. While the cable is elsewhere it keeps running in a viewport that
## draws nothing, so a computer boots without the screen. It is freed when the job leaves the
## counter, and reports software fixes to Game itself.
@export var desktop_scene: PackedScene


var _desktops: Dictionary[Job, Control] = {}
## Holds the desktops that the screen doesn't show; it draws nothing, but they run.
var _parked: SubViewport

@onready var _no_signal: Control = %NoSignal


func _ready() -> void:
	_parked = SubViewport.new()
	_parked.size = Vector2i(custom_minimum_size)
	_parked.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_parked.gui_embed_subwindows = true
	add_child(_parked, false, Node.INTERNAL_MODE_BACK)
	if desktop_scene == null:
		push_error("BenchScreen: desktop_scene is empty")
	Game.changed.connect(_sync)
	_sync()


## True while a running computer is connected, so the tube locks onto its picture.
func has_picture() -> bool:
	return Game.connected != null and Game.connected.powered


## False while the shown desktop hides its mouse pointer, as before Windows has booted.
func pointer_visible() -> bool:
	var shown := _desktops.get(Game.connected) as Control if Game.connected != null else null
	return shown != null and shown.get(&"pointer_visible") != false


## True while the shown desktop loads something, and its pointer is busy.
func pointer_busy() -> bool:
	var shown := _desktops.get(Game.connected) as Control if Game.connected != null else null
	return shown != null and shown.get(&"pointer_busy") == true


# Frees the desktops of jobs that left the counter, runs a desktop for every computer that is on,
# and shows the connected job's.
func _sync() -> void:
	for job: Job in _desktops.keys():
		if job not in Game.jobs:
			var desktop: Control = _desktops[job]
			_desktops.erase(job)
			var heir := _heir(job)
			if heir != null:
				_desktops[heir] = desktop
				(desktop.get_node(^"%ComputerState") as ComputerState).adopt(heir)
			else:
				desktop.queue_free()
	for job in Game.jobs:
		if job.powered:
			_desktop(job)
	var shown := _desktop(Game.connected) if Game.connected != null else null
	for desktop: Control in _desktops.values():
		@warning_ignore("incompatible_ternary")
		var home: Node = self if desktop == shown else _parked
		if desktop.get_parent() != home:
			if desktop.get_parent() != null:
				desktop.get_parent().remove_child(desktop)
			home.add_child(desktop)
	_no_signal.visible = shown == null


# The job that Game.restore made anew for [param job]'s computer (a story reload restores the
# state it had), so its desktop runs on instead of booting again; null if there is none.
func _heir(job: Job) -> Job:
	for each: Job in Game.jobs:
		if each.customer.computer == job.customer.computer and not _desktops.has(each):
			return each
	return null


# The desktop of [param job], made at the first call. Null, with an error, when the scene is unfit.
func _desktop(job: Job) -> Control:
	if _desktops.has(job):
		return _desktops[job]
	if desktop_scene == null:
		return null
	var desktop := desktop_scene.instantiate() as Control
	var state := desktop.get_node_or_null(^"%ComputerState") as ComputerState if desktop != null else null
	if state == null:
		push_error("BenchScreen: %s is not a Control with a %%ComputerState node" % desktop_scene.resource_path)
		if desktop != null:
			desktop.free()
		return null
	if desktop.custom_minimum_size != custom_minimum_size:
		push_error("BenchScreen: %s is %s, but the bench screen is %s" % [desktop_scene.resource_path, desktop.custom_minimum_size, custom_minimum_size])
	state.job = job
	if desktop.has_signal(&"pointer_changed"):
		desktop.connect(&"pointer_changed", pointer_changed.emit)
	_desktops[job] = desktop  # before it enters the tree, whose boot can emit Game.changed again
	return desktop
