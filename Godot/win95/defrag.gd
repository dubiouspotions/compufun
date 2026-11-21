extends "res://win95/window.gd"
## Disk Defragmenter: Start runs it for run_seconds, the block map sorts itself, and finished fires.

## Defragmenting is done.
signal finished

## How long a run takes, in seconds.
@export var run_seconds: float = 10.0
## The share of blocks that start out fragmented, 0 to 1.
@export_range(0.0, 1.0) var fragmented: float = 0.34
@export var block_count: int = 400
@export var used_color: Color = Color(0, 0, 0.502)
@export var fragment_color: Color = Color(1, 0, 0)
@export var free_color: Color = Color(1, 1, 1)

## The share of the run that is done, 0 to 1.
var _done: float = 0.0
var _running: bool = false
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
	_start.pressed.connect(func() -> void:
		_running = not _running
		_sync())
	%CloseButton.pressed.connect(close)
	set_process(false)
	_sync()


func _process(delta: float) -> void:
	_done = minf(1.0, _done + delta / run_seconds)
	if _done >= 1.0:
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
	for i in block_count:
		var color := free_color
		if i < sorted:
			color = used_color
		elif _blocks[i] == 2 and i >= sorted:
			color = fragment_color
		elif _blocks[i] != 0:
			color = used_color
		var at := Vector2(i % columns, i / columns) * cell
		_map.draw_rect(Rect2(at + Vector2.ONE, cell - Vector2(2, 2)), color)
