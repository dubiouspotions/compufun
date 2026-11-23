class_name FeedbackScreen
extends CanvasLayer
## F9 (or Cmd+9) feedback, for us only: it works in a run from the editor, not in an exported game. F9 stops
## the game and shows a screenshot. The player draws on it, types a note and picks Bug or Idea.
## The report goes to <repo>/feedback/<time>_<name>/: shot.png (with the marks) and report.json
## (the note, the marks and what is under them, the Game state, the room and the build). With
## "Send to GitHub" ticked, it also makes a GitHub issue (GitHubIssues): the screenshot goes to the
## branch "feedback", and the board's own workflow adds the issue to the board.

const HINT: String = "Draw on the picture: circle or underline what you mean."
const NO_SHOT_HINT: String = "No screenshot (a headless run?). The report saves without one."
const STROKE_WIDTH: float = 5.0
const STROKE_COLOR: Color = Color(1.0, 0.2, 0.2)
const EDGE_COLOR: Color = Color(0.05, 0.05, 0.05, 0.85)
## The shortest stroke that counts as a mark, in canvas pixels.
const MIN_STROKE: float = 4.0
## The distance between two recorded points of a stroke, in canvas pixels.
const POINT_STEP: float = 3.0
## The most points per mark in report.json.
const MAX_REPORT_POINTS: int = 100
const TOAST_SECONDS: float = 3.0
## The branch that holds the screenshots of the issues. CI does not build it.
const FEEDBACK_BRANCH: String = "feedback"
## The width of the screenshot in the issue, in pixels.
const ISSUE_SHOT_WIDTH: int = 1280
const ACCENTS: Dictionary = {
	"á": "a", "à": "a", "â": "a", "ä": "a", "å": "a", "é": "e", "è": "e", "ê": "e", "ë": "e",
	"í": "i", "ï": "i", "ó": "o", "ô": "o", "ö": "o", "ø": "o", "ú": "u", "ü": "u", "ñ": "n", "ç": "c",
}

## The folder for the reports. Empty: the feedback/ folder at the root of the repo.
@export var output_dir: String = ""
## The GitHub repo for the issues, as owner/name. Empty: read it from git's remote "origin".
@export var github_repo: String = ""

var _shot: Image
var _strokes: Array[PackedVector2Array] = []
var _current: PackedVector2Array = PackedVector2Array()
var _drawing: bool = false
var _was_paused: bool = false
var _sending: bool = false
var _toast_id: int = 0

@onready var _root: Control = %Root
@onready var _picture: TextureRect = %Picture
@onready var _marks: Control = %Marks
@onready var _status: Label = %Status
@onready var _count: Label = %MarkCount
@onready var _note: LineEdit = %Note
@onready var _send: CheckBox = %SendBox
@onready var _toast: Control = %Toast
@onready var _toast_label: Label = %ToastLabel


func _ready() -> void:
	_root.visible = false
	_toast.visible = false
	_marks.gui_input.connect(_on_marks_input)
	_marks.draw.connect(_draw_marks)
	(%BugButton as Button).pressed.connect(_save.bind("bug"))
	(%IdeaButton as Button).pressed.connect(_save.bind("idea"))
	(%UndoButton as Button).pressed.connect(undo)
	(%ClearButton as Button).pressed.connect(clear_marks)
	(%CancelButton as Button).pressed.connect(close)


func is_open() -> bool:
	return _root.visible


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.is_action_pressed(&"feedback") and not is_open():
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
	_status.text = HINT if _shot != null else NO_SHOT_HINT
	_strokes.clear()
	_current = PackedVector2Array()
	_drawing = false
	_note.text = ""
	_was_paused = get_tree().paused
	get_tree().paused = true
	_root.visible = true
	_note.grab_focus()
	_changed()


## Closes the screen without a report, and lets the game run again.
func close() -> void:
	_root.visible = false
	_drawing = false
	get_tree().paused = _was_paused


## Removes the last mark.
func undo() -> void:
	if not _strokes.is_empty():
		_strokes.pop_back()
		_changed()


## Removes every mark.
func clear_marks() -> void:
	_strokes.clear()
	_changed()


func _changed() -> void:
	var n := _strokes.size()
	_count.text = "No marks" if n == 0 else ("1 mark" if n == 1 else "%d marks" % n)
	_marks.queue_redraw()


func _take_screenshot() -> Image:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return null
	# Keep only the game area: the window can have black bars around it.
	var to_window := get_viewport().get_final_transform()
	var area := Rect2(to_window.origin, get_viewport().get_visible_rect().size * to_window.get_scale())
	var crop := Rect2i(area).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	return image.get_region(crop) if crop.has_area() else image


func _on_marks_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_drawing = true
			_current = PackedVector2Array([button.position])
		elif _drawing:
			_drawing = false
			_current.append(button.position)
			if _bounds(_current).size.length() >= MIN_STROKE:
				_strokes.append(_current)
			_current = PackedVector2Array()
			_changed()
		_marks.queue_redraw()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _drawing:
		if _current.is_empty() or _current[_current.size() - 1].distance_to(motion.position) >= POINT_STEP:
			_current.append(motion.position)
			_marks.queue_redraw()


func _draw_marks() -> void:
	for stroke: PackedVector2Array in _strokes:
		_draw_stroke(stroke)
	if _drawing:
		_draw_stroke(_current)


func _draw_stroke(stroke: PackedVector2Array) -> void:
	if stroke.size() < 2:
		return
	_marks.draw_polyline(stroke, EDGE_COLOR, STROKE_WIDTH + 4.0, true)
	_marks.draw_polyline(stroke, STROKE_COLOR, STROKE_WIDTH, true)


func _bounds(stroke: PackedVector2Array) -> Rect2:
	if stroke.is_empty():
		return Rect2()
	var rect := Rect2(stroke[0], Vector2.ZERO)
	for point: Vector2 in stroke:
		rect = rect.expand(point)
	return rect


func _save(kind: String) -> void:
	var canvas_size := get_viewport().get_visible_rect().size
	var author := _author()
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var folder := _output_dir().path_join("%s_%s" % [stamp, author])
	var copy := 2
	while DirAccess.dir_exists_absolute(folder):
		folder = _output_dir().path_join("%s_%s_%d" % [stamp, author, copy])
		copy += 1
	var err := DirAccess.make_dir_recursive_absolute(folder)
	if err != OK:
		_fail("cannot make %s: %s" % [folder, error_string(err)])
		return
	var marks: Array[Dictionary] = []
	for stroke: PackedVector2Array in _strokes:
		var bounds := _bounds(stroke)
		marks.append({
			"bounds": [bounds.position.x / canvas_size.x, bounds.position.y / canvas_size.y,
				bounds.size.x / canvas_size.x, bounds.size.y / canvas_size.y],
			"points": _report_points(stroke, canvas_size),
			"hotspot": _hotspot_at(bounds.get_center()),
			"ui": _control_at(bounds.get_center()),
		})
	var report := {
		"kind": kind,
		"note": _note.text,
		"time": Time.get_datetime_string_from_system(),
		"author": author,
		"marks": marks,
		"game": Game.snapshot(),
		"story_drafts": Game.story_drafts,
		"camera": _camera_info(),
		"open_screens": _open_screens(),
		"build": {
			"commit": GitHubIssues.git(["rev-parse", "--short", "HEAD"]),
			"branch": GitHubIssues.git(["rev-parse", "--abbrev-ref", "HEAD"]),
			"godot": Engine.get_version_info().string,
			"os": OS.get_name(),
		},
		"shot": "shot.png" if _shot != null else "",
	}
	if _shot != null:
		var marked := _shot.duplicate() as Image
		_paint_marks(marked, canvas_size)
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
	if _send.button_pressed:
		_start_send(report, folder)
	else:
		_show_toast("Report saved: feedback/%s" % folder.get_file())


## The points of [param stroke] from 0 to 1, at most MAX_REPORT_POINTS of them.
func _report_points(stroke: PackedVector2Array, canvas_size: Vector2) -> Array:
	var step := maxi(1, ceili(float(stroke.size()) / MAX_REPORT_POINTS))
	var points: Array = []
	for i: int in range(0, stroke.size(), step):
		points.append([snappedf(stroke[i].x / canvas_size.x, 0.0001), snappedf(stroke[i].y / canvas_size.y, 0.0001)])
	return points


func _fail(message: String) -> void:
	push_error("F9 report: " + message)
	_status.text = "Not saved: %s" % message


## Shows [param text] at the top of the screen. [param seconds] 0 keeps it until the next toast.
func _show_toast(text: String, seconds: float = TOAST_SECONDS) -> void:
	_toast_id += 1
	var id := _toast_id
	_toast_label.text = text
	_toast.visible = true
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout
	if id == _toast_id:
		_toast.visible = false


func _start_send(report: Dictionary, folder: String) -> void:
	if _sending:
		_show_toast("Still sending the last report; this one is saved in feedback/%s." % folder.get_file(), 6.0)
		return
	var token := GitHubIssues.read_token()
	if token.has("error"):
		_on_sent(token)
		return
	var shot := ""
	var shot_error := ""
	if _shot != null:
		var image := Image.load_from_file(folder.path_join("shot.png"))
		if image == null or image.is_empty():
			shot_error = "cannot read %s" % folder.path_join("shot.png")
		else:
			if image.get_width() > ISSUE_SHOT_WIDTH:
				image.resize(ISSUE_SHOT_WIDTH, image.get_height() * ISSUE_SHOT_WIDTH / image.get_width(), Image.INTERPOLATE_BILINEAR)
			shot = folder.path_join("shot.jpg")
			var err := image.save_jpg(shot, 0.85)
			if err != OK:
				shot_error = "cannot write %s: %s" % [shot, error_string(err)]
				shot = ""
	var github := GitHubIssues.new(self, token["token"], github_repo, "HumanError-F9")
	_sending = true
	_show_toast("Sending the report to GitHub...", 0.0)
	var result := await _send_to_github(github, folder, shot, shot_error, _issue_title(report), _issue_body(report))
	_sending = false
	_on_sent(result)


func _on_sent(result: Dictionary) -> void:
	if result.has("error"):
		push_error("F9 report: not sent to GitHub: %s" % result["error"])
		_show_toast("Not sent to GitHub: %s. The report is saved in feedback/." % String(result["error"]).get_slice("\n", 0), 10.0)
		return
	var url: String = result["url"]
	var text := "Issue #%s created" % url.get_file()
	if result.get("image_error", "") != "":
		push_warning("F9 report: the issue has no screenshot: %s" % result["image_error"])
		text += ", without the screenshot"
	print("F9 report sent: %s" % url)
	_show_toast(text, 6.0)


func _send_to_github(github: GitHubIssues, folder: String, shot: String, shot_error: String, title: String, body: String) -> Dictionary:
	if github.repo() == "":
		return {"error": "cannot find the GitHub repo: set github_repo, or check git's remote origin"}
	var image := ""
	var image_error := shot_error
	if shot != "":
		var uploaded := await _upload_shot(github, folder, shot)
		image = uploaded.get("url", "")
		image_error = uploaded.get("error", "")
	var picture := "_No screenshot._"
	if image != "":
		picture = "![screenshot](%s)" % image
	elif image_error != "":
		picture = "_No screenshot: %s_" % image_error.get_slice("\n", 0)
	var result := await github.create_issue(title, body.replace("%IMAGE%", picture), [GitHubIssues.FEEDBACK_LABEL])
	if not result.has("error"):
		result["image_error"] = image_error
	return result


## Puts the screenshot on the branch FEEDBACK_BRANCH (made from the default branch when it is
## missing) and returns {"url"} of the raw file, or {"error"}.
func _upload_shot(github: GitHubIssues, folder: String, shot: String) -> Dictionary:
	var repo := github.repo()
	var ref := await github.api(HTTPClient.METHOD_GET, "/repos/%s/git/ref/heads/%s" % [repo, FEEDBACK_BRANCH])
	if ref["code"] == 404:
		var info := await github.api(HTTPClient.METHOD_GET, "/repos/%s" % repo)
		if info.has("error"):
			return {"error": "cannot read the default branch: %s" % info["error"]}
		var base := String(info["data"]["default_branch"])
		var head := await github.api(HTTPClient.METHOD_GET, "/repos/%s/git/ref/heads/%s" % [repo, base])
		if head.has("error"):
			return {"error": "cannot read the head of %s: %s" % [base, head["error"]]}
		var made := await github.api(HTTPClient.METHOD_POST, "/repos/%s/git/refs" % repo, {"ref": "refs/heads/" + FEEDBACK_BRANCH, "sha": head["data"]["object"]["sha"]})
		if made.has("error"):
			return {"error": "cannot make the branch %s: %s" % [FEEDBACK_BRANCH, made["error"]]}
	elif ref.has("error"):
		return {"error": "cannot read the branch %s: %s" % [FEEDBACK_BRANCH, ref["error"]]}
	var bytes := FileAccess.get_file_as_bytes(shot)
	if bytes.is_empty():
		return {"error": "cannot read %s: %s" % [shot, error_string(FileAccess.get_open_error())]}
	var put := await github.api(HTTPClient.METHOD_PUT, "/repos/%s/contents/feedback/%s/shot.jpg" % [repo, folder.get_file()], {
		"message": "F9 report %s" % folder.get_file(),
		"content": Marshalls.raw_to_base64(bytes),
		"branch": FEEDBACK_BRANCH,
	})
	if put.has("error"):
		return {"error": "cannot upload the screenshot: %s" % put["error"]}
	return {"url": String(put["data"]["content"]["download_url"])}


func _issue_title(report: Dictionary) -> String:
	var first := String(report["note"]).strip_edges().get_slice("\n", 0)
	if first.length() > 70:
		first = first.substr(0, 67) + "..."
	if first == "":
		first = "F9 report %s" % report["time"]
	return "[%s] %s" % ["Bug" if report["kind"] == "bug" else "Idea", first]


## The issue text in Markdown. %IMAGE% marks the place of the screenshot.
func _issue_body(report: Dictionary) -> String:
	var game: Dictionary = report["game"]
	var build: Dictionary = report["build"]
	var hits: PackedStringArray = []
	for mark: Dictionary in report["marks"]:
		var hit := String(mark["hotspot"]) if mark["hotspot"] != "" else String(mark["ui"])
		hits.append("`%s`" % hit if hit != "" else "(nothing under it)")
	var note := String(report["note"]).strip_edges()
	var lines: PackedStringArray = [
		note if note != "" else "_No note._", "", "%IMAGE%", "",
		"| | |", "| --- | --- |",
		"| Kind | %s |" % report["kind"],
		"| Author | %s |" % report["author"],
		"| Time | %s |" % report["time"],
		"| View | %s |" % game["view"],
		"| Phase | %s |" % game["phase"],
		"| Day | %s |" % game["day"],
		"| Visitor | %s |" % String(game["visitor"]).get_file(),
		"| Jobs | %s |" % ", ".join(PackedStringArray((game["jobs"] as Array).map(func(j: Dictionary) -> String: return "%s (slot %d)" % [j.get("errand", j.get("problem", "?")), j["slot"]]))),
		"| Focus, cable | slot %d, slot %d |" % [game["focus_slot"], game["connected_slot"]],
		"| Marks | %s |" % ("; ".join(hits) if not hits.is_empty() else "none"),
		"| Build | %s on %s, Godot %s, %s |" % [build["commit"], build["branch"], build["godot"], build["os"]],
	]
	var drafts: Dictionary = report.get("story_drafts", {})
	if not drafts.is_empty():
		lines.append_array(["", "**The game played the writer's Story Lab drafts.** Write these files before reproducing:", ""])
		for path: String in drafts:
			var text := String(drafts[path])
			if text == "":
				lines.append("- `%s`: removed" % path)
				continue
			var fence := "```"
			while text.contains(fence):
				fence += "`"
			lines.append_array(["<details><summary><code>%s</code></summary>" % path, "", fence, text.trim_suffix("\n"), fence, "", "</details>"])
	lines.append_array(["", "<details><summary>report.json</summary>", "", "```json", JSON.stringify(report, "  "), "```", "", "</details>"])
	return "\n".join(lines)


## Paints the marks into the screenshot, at the scale of the picture, with a dark edge.
func _paint_marks(image: Image, canvas_size: Vector2) -> void:
	var scale := Vector2(image.get_size()) / canvas_size
	var radius := STROKE_WIDTH * 0.5 * scale.x
	for stroke: PackedVector2Array in _strokes:
		_paint_stroke(image, stroke, scale, radius + 2.0, EDGE_COLOR)
	for stroke: PackedVector2Array in _strokes:
		_paint_stroke(image, stroke, scale, radius, STROKE_COLOR)


func _paint_stroke(image: Image, stroke: PackedVector2Array, scale: Vector2, radius: float, color: Color) -> void:
	for i: int in range(1, stroke.size()):
		var a := stroke[i - 1] * scale
		var b := stroke[i] * scale
		var steps := maxi(1, ceili(a.distance_to(b) / maxf(radius * 0.5, 1.0)))
		for s: int in steps + 1:
			_paint_disc(image, a.lerp(b, float(s) / steps), radius, color)


func _paint_disc(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	var r := ceili(radius)
	for dy: int in range(-r, r + 1):
		var half := floori(sqrt(maxf(radius * radius - dy * dy, 0.0)))
		var row := Rect2i(roundi(center.x) - half, roundi(center.y) + dy, half * 2 + 1, 1).intersection(bounds)
		if row.has_area():
			image.fill_rect(row, color)


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


func _output_dir() -> String:
	return output_dir if output_dir != "" else GitHubIssues.repo_dir().path_join("feedback")


## The first name from git config user.name, in lowercase ASCII, for the folder name.
func _author() -> String:
	var full := GitHubIssues.git(["config", "user.name"])
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
