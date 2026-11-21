class_name FeedbackScreen
extends CanvasLayer
## F9 feedback, for us only: it works in a run from the editor, not in an exported game. F9 stops
## the game and shows a screenshot. The player drags boxes, types a note and picks Bug or Idea.
## The report goes to <repo>/feedback/<time>_<name>/: shot.png (with the boxes) and report.json
## (the note, the boxes and what is under them, the Game state, the room and the build).

const HINT: String = "F9 feedback: drag a box around what you mean. Ctrl+Z (Cmd+Z): undo. Esc: cancel."
const MIN_BOX: float = 6.0
const BOX_COLOR: Color = Color(1.0, 0.15, 0.15)
const BOX_WIDTH: int = 4
const TOAST_SECONDS: float = 3.0
const ACCENTS: Dictionary = {
	"á": "a", "à": "a", "â": "a", "ä": "a", "å": "a", "é": "e", "è": "e", "ê": "e", "ë": "e",
	"í": "i", "ï": "i", "ó": "o", "ô": "o", "ö": "o", "ø": "o", "ú": "u", "ü": "u", "ñ": "n", "ç": "c",
}

## The folder for the reports. Empty: the feedback/ folder at the root of the repo.
@export var output_dir: String = ""

var _shot: Image
var _boxes_list: Array[Rect2] = []
var _dragging: bool = false
var _drag_from: Vector2
var _drag_rect: Rect2
var _was_paused: bool = false

@onready var _root: Control = %Root
@onready var _picture: TextureRect = %Picture
@onready var _boxes: Control = %Boxes
@onready var _status: Label = %Status
@onready var _note: LineEdit = %Note
@onready var _toast: Label = %Toast


func _ready() -> void:
	_root.visible = false
	_toast.visible = false
	_boxes.gui_input.connect(_on_boxes_input)
	_boxes.draw.connect(_draw_boxes)
	(%BugButton as Button).pressed.connect(_save.bind("bug"))
	(%IdeaButton as Button).pressed.connect(_save.bind("idea"))
	(%CancelButton as Button).pressed.connect(close)


func is_open() -> bool:
	return _root.visible


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F9 and not is_open():
		if OS.has_feature("editor"):
			open()
	elif is_open() and key.keycode == KEY_ESCAPE:
		close()
	elif is_open() and key.keycode == KEY_Z and key.is_command_or_control_pressed():
		undo()
	else:
		return
	get_viewport().set_input_as_handled()


## Takes the screenshot and opens the screen. The game stays stopped until [method close].
func open() -> void:
	_shot = _take_screenshot()
	_picture.texture = ImageTexture.create_from_image(_shot) if _shot != null else null
	_status.text = HINT if _shot != null else "No screenshot (a headless run?). The report saves without one."
	_boxes_list.clear()
	_dragging = false
	_note.text = ""
	_was_paused = get_tree().paused
	get_tree().paused = true
	_root.visible = true
	_note.grab_focus()
	_boxes.queue_redraw()


## Closes the screen without a report, and lets the game run again.
func close() -> void:
	_root.visible = false
	_dragging = false
	get_tree().paused = _was_paused


## Removes the last box.
func undo() -> void:
	if not _boxes_list.is_empty():
		_boxes_list.pop_back()
		_boxes.queue_redraw()


func _take_screenshot() -> Image:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return null
	# Keep only the game area: the window can have black bars around it.
	var to_window := get_viewport().get_final_transform()
	var area := Rect2(to_window.origin, get_viewport().get_visible_rect().size * to_window.get_scale())
	var crop := Rect2i(area).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	return image.get_region(crop) if crop.has_area() else image


func _on_boxes_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_dragging = true
			_drag_from = button.position
			_drag_rect = Rect2(button.position, Vector2.ZERO)
		elif _dragging:
			_dragging = false
			var rect := _drag_rect.abs()
			if rect.size.x >= MIN_BOX and rect.size.y >= MIN_BOX:
				_boxes_list.append(rect)
		_boxes.queue_redraw()
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_drag_rect = Rect2(_drag_from, motion.position - _drag_from)
		_boxes.queue_redraw()


func _draw_boxes() -> void:
	for rect: Rect2 in _boxes_list:
		_boxes.draw_rect(rect, BOX_COLOR, false, BOX_WIDTH)
	if _dragging:
		_boxes.draw_rect(_drag_rect.abs(), BOX_COLOR, false, BOX_WIDTH)


func _save(kind: String) -> void:
	var canvas_size := get_viewport().get_visible_rect().size
	var author := _author()
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var folder := _output_dir().path_join("%s_%s" % [stamp, author])
	var err := DirAccess.make_dir_recursive_absolute(folder)
	if err != OK:
		_fail("cannot make %s: %s" % [folder, error_string(err)])
		return
	var boxes: Array[Dictionary] = []
	for rect: Rect2 in _boxes_list:
		boxes.append({
			"rect": [rect.position.x / canvas_size.x, rect.position.y / canvas_size.y,
				rect.size.x / canvas_size.x, rect.size.y / canvas_size.y],
			"hotspot": _hotspot_at(rect.get_center()),
			"ui": _control_at(rect.get_center()),
		})
	var report := {
		"kind": kind,
		"note": _note.text,
		"time": Time.get_datetime_string_from_system(),
		"author": author,
		"boxes": boxes,
		"game": Game.snapshot(),
		"camera": _camera_info(),
		"open_screens": _open_screens(),
		"build": {
			"commit": _git(["rev-parse", "--short", "HEAD"]),
			"branch": _git(["rev-parse", "--abbrev-ref", "HEAD"]),
			"godot": Engine.get_version_info().string,
			"os": OS.get_name(),
		},
		"shot": "shot.png" if _shot != null else "",
	}
	if _shot != null:
		var marked := _shot.duplicate() as Image
		_mark(marked, canvas_size)
		err = marked.save_png(folder.path_join("shot.png"))
		if err != OK:
			_fail("cannot write %s: %s" % [folder.path_join("shot.png"), error_string(err)])
			return
	var path := folder.path_join("report.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	if JSON.parse_string(FileAccess.get_file_as_string(path)) == null:
		_fail("%s did not read back as JSON" % path)
		return
	print("F9 report saved: %s" % folder)
	close()
	_show_toast("Report saved: %s" % folder.get_file())


func _fail(message: String) -> void:
	push_error("F9 report: " + message)
	_status.text = "Not saved: %s" % message


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	await get_tree().create_timer(TOAST_SECONDS).timeout
	_toast.visible = false


## Draws the boxes into the screenshot, at the scale of the picture.
func _mark(image: Image, canvas_size: Vector2) -> void:
	var scale := Vector2(image.get_size()) / canvas_size
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	for rect: Rect2 in _boxes_list:
		var r := Rect2i(Rect2(rect.position * scale, rect.size * scale))
		var edges: Array[Rect2i] = [
			Rect2i(r.position.x, r.position.y, r.size.x, BOX_WIDTH),
			Rect2i(r.position.x, r.end.y - BOX_WIDTH, r.size.x, BOX_WIDTH),
			Rect2i(r.position.x, r.position.y, BOX_WIDTH, r.size.y),
			Rect2i(r.end.x - BOX_WIDTH, r.position.y, BOX_WIDTH, r.size.y),
		]
		for edge: Rect2i in edges:
			var clipped := edge.intersection(bounds)
			if clipped.has_area():
				image.fill_rect(clipped, BOX_COLOR)


## The name of the nearest visible hotspot under [param point] (canvas coordinates), or "".
func _hotspot_at(point: Vector2) -> String:
	var best := ""
	var best_distance := INF
	for node: Node in get_tree().root.find_children("*", "Area3D", true, false):
		var hotspot := node as Hotspot
		if hotspot == null or not hotspot.is_visible_in_tree():
			continue
		var camera := hotspot.get_viewport().get_camera_3d()
		if camera == null:
			continue
		var pixel := _to_viewport_pixel(point, hotspot.get_viewport())
		var distance := _ray_box(camera.project_ray_origin(pixel), camera.project_ray_normal(pixel), hotspot.global_transform, hotspot.size)
		if distance >= 0.0 and distance < best_distance:
			best_distance = distance
			best = String(hotspot.name)
	return best


func _to_viewport_pixel(point: Vector2, viewport: Viewport) -> Vector2:
	var container := viewport.get_parent() as SubViewportContainer
	var sub := viewport as SubViewport
	if container == null or sub == null:
		return point
	var rect := container.get_global_rect()
	return (point - rect.position) * Vector2(sub.size) / rect.size


## The distance along the ray to the box of [param size] at [param xform], or -1 for a miss.
func _ray_box(origin: Vector3, direction: Vector3, xform: Transform3D, size: Vector3) -> float:
	var inverse := xform.affine_inverse()
	var o := inverse * origin
	var d := inverse.basis * direction
	var half := size * 0.5
	var near := -INF
	var far := INF
	for axis: int in 3:
		if absf(d[axis]) < 1e-8:
			if o[axis] < -half[axis] or o[axis] > half[axis]:
				return -1.0
			continue
		var t1 := (-half[axis] - o[axis]) / d[axis]
		var t2 := (half[axis] - o[axis]) / d[axis]
		near = maxf(near, minf(t1, t2))
		far = minf(far, maxf(t1, t2))
	if near > far or far < 0.0:
		return -1.0
	return maxf(near, 0.0)


## The path of the top visible UI control under [param point] that takes the mouse, or "".
func _control_at(point: Vector2) -> String:
	var best: Control = null
	var best_layer := -INF
	for node: Node in get_tree().root.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or is_ancestor_of(control) or control.get_viewport() != get_viewport():
			continue
		if not control.is_visible_in_tree() or control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if not control.get_global_rect().has_point(point):
			continue
		var layer := _layer_of(control)
		if layer >= best_layer:
			best = control
			best_layer = layer
	return String(best.get_path()) if best != null else ""


func _layer_of(node: Node) -> int:
	var parent := node.get_parent()
	while parent != null:
		var canvas_layer := parent as CanvasLayer
		if canvas_layer != null:
			return canvas_layer.layer
		parent = parent.get_parent()
	return 0


func _camera_info() -> Dictionary:
	for node: Node in get_tree().root.find_children("*", "Camera3D", true, false):
		var camera := node as Camera3D
		if camera != null and camera.current:
			return {
				"room": camera.owner.scene_file_path if camera.owner != null else "",
				"position": [camera.global_position.x, camera.global_position.y, camera.global_position.z],
				"rotation_degrees": [camera.global_rotation_degrees.x, camera.global_rotation_degrees.y, camera.global_rotation_degrees.z],
			}
	return {}


func _open_screens() -> Array[String]:
	var names: Array[String] = []
	for node: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if node == self:
			continue
		for child: Node in node.get_children():
			var control := child as Control
			if control != null and control.visible:
				names.append(String(control.name))
	return names


func _repo_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").simplify_path()


func _output_dir() -> String:
	return output_dir if output_dir != "" else _repo_dir().path_join("feedback")


## The output of git in the repo, or "unknown" when git is missing or fails.
func _git(arguments: PackedStringArray) -> String:
	var output: Array = []
	var args := PackedStringArray(["-C", _repo_dir()])
	args.append_array(arguments)
	var code := OS.execute("git", args, output, true)
	if code != 0 or output.is_empty():
		return "unknown"
	return String(output[0]).strip_edges()


## The first name from git config user.name, in lowercase ASCII, for the folder name.
func _author() -> String:
	var full := _git(["config", "user.name"])
	if full == "unknown" or full == "":
		full = OS.get_environment("USER") if OS.has_environment("USER") else OS.get_environment("USERNAME")
	full = full.to_lower()
	for accent: String in ACCENTS:
		full = full.replace(accent, ACCENTS[accent])
	var words := full.split(" ", false)
	var clean := ""
	for character: String in (words[0] if not words.is_empty() else ""):
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			clean += character
	return clean if clean != "" else "unknown"
