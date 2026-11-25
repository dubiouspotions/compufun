extends "res://win95/window.gd"
## CompuFun AntiVirus, the scanner (AV.EXE). Scan Now walks the desktop and drive C over
## [member scan_seconds], showing each path as it goes, then lists the infected files: program files
## whose scene root is a Virus. Clean ends their tasks and deletes them with their StartUp shortcuts
## (ComputerState.remove_viruses).

## The scan finished and the list shows what it found.
signal scanned
## Clean finished: [param removed] files are gone.
signal cleaned(removed: int)

## How long a scan takes, in seconds, however many files there are.
@export var scan_seconds: float = 4.0
## What the window says before the first scan.
@export var ready_text: String = "Click Scan Now to check this computer for viruses."
## What it says while it scans.
@export var scanning_text: String = "Scanning the desktop and drive C..."
## One line of the list per infected file: its name, then the virus's name.
@export var infected_format: String = "%s: infected with %s"
## What it says after a scan that found viruses, with how many files.
@export var found_format: String = "%d infected file(s) found. Click Clean to remove them."
## What it says after a scan that found none.
@export var clean_text: String = "No viruses found."
## What it says after Clean, with the count and "virus" or "viruses".
@export var removed_format: String = "%d %s removed."

var _computer: ComputerState
## [path, file] of every file to scan, in the order the scan shows them.
var _queue: Array[Array] = []
var _done: float = 0.0
var _found: Array[Win95File] = []

@onready var _status: Label = %Status
@onready var _path: Label = %Path
@onready var _progress: ProgressBar = %Progress
@onready var _results: ItemList = %Results
@onready var _scan: Button = %ScanNow
@onready var _clean: Button = %Clean


func _ready() -> void:
	super()
	var desktop := get_parent() as Win95Desktop
	_computer = desktop.computer if desktop != null else null
	_scan.pressed.connect(scan)
	_clean.pressed.connect(clean)
	%CloseButton.pressed.connect(close)
	_status.text = ready_text
	_path.text = ""
	set_process(false)
	_sync()


## Starts a scan of the desktop and drive C; the list fills when it ends, with [signal scanned].
## Does nothing while a scan runs.
func scan() -> void:
	if is_processing():
		return
	if _computer == null or _computer.setup == null:
		push_error("CompuFun AntiVirus: no computer to scan; the window must open on a Win95Desktop")
		return
	_queue.clear()
	_collect(_computer.setup.desktop, "C:\\WINDOWS\\Desktop")
	_collect(_computer.setup.drive_c, "C:")
	_found.clear()
	_results.clear()
	_done = 0.0
	_status.text = scanning_text
	set_process(true)
	_sync()
	if await read_disk(scan_seconds) and not is_queued_for_deletion() and is_processing():
		_done = 1.0
		_finish()
		_sync()


## Ends the tasks of the viruses and deletes them, with [signal cleaned]. Does nothing until a scan
## found some.
func clean() -> void:
	if _found.is_empty() or is_processing():
		return
	var removed := _computer.remove_viruses()
	_found.clear()
	_results.clear()
	_status.text = removed_format % [removed, "virus" if removed == 1 else "viruses"]
	_sync()
	cleaned.emit(removed)


## Closes the window for good, as the program exits; a scan that runs stops.
func close() -> void:
	set_process(false)
	super()
	queue_free()


## The lines of the list: one per infected file that the last scan found.
func results() -> PackedStringArray:
	var lines := PackedStringArray()
	for i in _results.item_count:
		lines.append(_results.get_item_text(i))
	return lines


## What the window says now, such as [member clean_text].
func status() -> String:
	return _status.text


func _process(delta: float) -> void:
	_done = minf(1.0, _done + delta / maxf(scan_seconds, 0.001))
	if not _queue.is_empty():
		_path.text = _queue[mini(int(_done * _queue.size()), _queue.size() - 1)][0]
	_sync()


func _finish() -> void:
	set_process(false)
	_path.text = ""
	for entry: Array in _queue:
		var file: Win95File = entry[1]
		if Virus.infects(file) and _computer.has_file(file):
			_found.append(file)
			_results.add_item(infected_format % [file.name, Virus.name_of(file)])
	_status.text = found_format % _found.size() if not _found.is_empty() else clean_text
	scanned.emit()


func _collect(container: Array, path: String) -> void:
	for file: Win95File in container:
		if file.system != &"":
			continue  # My Computer and the other desktop icons are no files on the disk
		var at := path + "\\" + file.name
		_queue.append([at, file])
		_collect(file.children, at)


func _sync() -> void:
	_progress.value = _done * 100.0
	_scan.disabled = is_processing()
	_clean.disabled = _found.is_empty() or is_processing()
