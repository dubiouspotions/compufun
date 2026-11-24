extends "res://win95/window.gd"
## Disk Defragmenter: Start runs it for run_seconds, the block map sorts itself, and finished fires.
## On a fragmented drive C (Win95Setup.fragmented) a run takes all night instead: it crawls through
## the evening, and the computer finishes it overnight if it stays on (Game starts the next day).

## Defragmenting is done.
signal finished

## How long a run takes, in seconds, on a drive that isn't fragmented.
@export var run_seconds: float = 10.0
## How long the progress bar would take on a fragmented drive; the night finishes it sooner.
@export var fragmented_run_seconds: float = 3600.0
## The share of blocks that start out fragmented, 0 to 1.
@export_range(0.0, 1.0) var fragmented: float = 0.34
@export var block_count: int = 400
@export var used_color: Color = Color(0, 0, 0.502)
@export var fragment_color: Color = Color(1, 0, 0)
@export var free_color: Color = Color(1, 1, 1)

## The share of the run that is done, 0 to 1.
var _done: float = 0.0
var _running: bool = false
var _computer: ComputerState
## Per block: 0 free, 1 in place, 2 fragmented. Shuffled once, then sorted as the run goes.
var _blocks: PackedByteArray = PackedByteArray()

@onready var _map: Control = %Map
@onready var _progress: ProgressBar = %Progress
@onready var _status: Label = %Status
@onready var _start: Button = %Start


func _ready() -> void:
	super()
	var rng := RandomNumberGenerator.new()
	_blocks.resize(block_count)
	for i in block_count:
		var roll := rng.randf()
		_blocks[i] = 0 if roll < 0.3 else (2 if roll < 0.3 + 0.7 * fragmented else 1)
	_map.draw.connect(_draw_map)
	var desktop := get_parent() as Win95Desktop
	_computer = desktop.computer if desktop != null else null
	if _computer != null:
		_computer.changed.connect(_sync_computer)
		_sync_computer()
	_start.pressed.connect(func() -> void:
		_running = not _running
		if _running and _fragmented() and _computer != null:
			_computer.start_defrag()
		_sync())
	%CloseButton.pressed.connect(close)
	set_process(false)
	_sync()


func _process(delta: float) -> void:
	_done = minf(1.0, _done + delta / (fragmented_run_seconds if _fragmented() else run_seconds))
	if _done >= 1.0:
		_running = false
		finished.emit()
	_sync()


func _fragmented() -> bool:
	return _computer != null and _computer.setup != null and _computer.setup.fragmented


# The run finished overnight: the drive is no longer fragmented, and the window shows it complete.
func _sync_computer() -> void:
	if _computer.setup == null:
		return
	if not _computer.setup.fragmented and _done > 0.0 and _done < 1.0:
		_done = 1.0
		_running = false
		finished.emit()
		_sync()


func _sync() -> void:
	set_process(_running)
	_start.disabled = _done >= 1.0
	_start.text = "Pause" if _running else "Start"
	_progress.value = _done * 100.0
	if _done >= 1.0:
		_status.text = "Defragmentation of drive C is complete."
	elif _running:
		_status.text = "Defragmenting file system..."
	_map.queue_redraw()


func _draw_map() -> void:
	var used := 0
	for b in _blocks:
		used += 1 if b != 0 else 0
	var sorted := int(used * _done)
	var columns := 40
	var cell := Vector2(_map.size.x / columns, _map.size.y / ceilf(float(block_count) / columns))
	var drawn := 0  # used blocks so far: the sorted ones moved to the front, so as many blocks are free further on
	for i in block_count:
		var color := free_color
		if i < sorted:
			color = used_color
			drawn += 1
		elif _blocks[i] != 0 and drawn < used:
			color = fragment_color if _blocks[i] == 2 else used_color
			drawn += 1
		@warning_ignore("integer_division")
		var at := Vector2(i % columns, i / columns) * cell
		_map.draw_rect(Rect2(at + Vector2.ONE, cell - Vector2(2, 2)), color)
