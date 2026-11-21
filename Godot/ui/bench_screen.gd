class_name BenchScreen
extends Control
## What the bench screen shows: the desktop of the job that the cable is connected to
## (Game.connected), and NO SIGNAL while the cable hangs free.

## The shown desktop's [code]pointer_visible[/code] changed.
signal pointer_changed

## The desktop of one job's computer, with a %ComputerState node. Each job gets its own at its
## first connection; it waits out of the tree while the cable is elsewhere, and is freed when the
## job leaves the counter. It reports software fixes to Game itself.
@export var desktop_scene: PackedScene


var _desktops: Dictionary[Job, Control] = {}

@onready var _no_signal: Control = %NoSignal


func _ready() -> void:
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


func _exit_tree() -> void:
	for desktop: Control in _desktops.values():
		if desktop.get_parent() == null:
			desktop.free()  # out of the tree, nothing else frees it


# Frees the desktops of jobs that left the counter, and shows the connected job's desktop.
func _sync() -> void:
	for job: Job in _desktops.keys():
		if job not in Game.jobs:
			_desktops[job].queue_free()
			_desktops.erase(job)
	var shown := _desktop(Game.connected) if Game.connected != null else null
	for child in get_children():
		if child != shown and child != _no_signal:
			remove_child(child)
	if shown != null and shown.get_parent() == null:
		add_child(shown)
	_no_signal.visible = shown == null


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
