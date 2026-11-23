extends SceneTree
## Measures what the game costs per frame (docs/performance.md): runs main.tscn in a real window
## with four running computers on the counter, and prints for each case the frame time, the frames
## drawn per second, the draw calls and every viewport's CPU render time. Uncapped (no V-Sync, no FPS
## cap), so a frame takes what it costs; with "capped" it keeps the project's settings, for measuring
## the CPU load from outside.
##
##   "$GODOT" --path . --resolution 1920x1080 -s res://dev/perf_probe.gd -- [day] [capped] [case ...] [+knob ...]
##
## The cases: main, screen, db, lab (the Story Lab, idle), lab_edit (typing in it), and any other view
## by its marker's name, such as Left. A knob turns a
## part off before measuring, to see what it costs; see _turn().

const MAIN := "res://main.tscn"
const WARMUP := 90
const SAMPLES := 300
const CUSTOMERS: Array[String] = [
	"res://customers/skater_bro.tres", "res://customers/retired_accountant.tres",
	"res://customers/activist_guy.tres", "res://customers/office_girl.tres",
]
const PROBLEMS: Array[String] = ["dust_overheat", "no_sound", "bad_ram", "dust_overheat"]

var game: Node
var _main: Node
var _dev_menu: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var capped := args.has("capped")
	args.erase("capped")
	var knobs: Array = args.filter(func(a: String) -> bool: return a.begins_with("+"))
	for knob in knobs:
		args.erase(knob)
	var day := 2
	if not args.is_empty() and args[0].is_valid_int():
		day = int(args[0])
		args.remove_at(0)
	var cases: Array = args if not args.is_empty() else ["main", "screen", "db", "lab", "lab_edit"]
	if not capped:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	game = root.get_node("Game")
	_main = (load(MAIN) as PackedScene).instantiate()
	root.add_child(_main)
	for i in 30:
		await process_frame
	var jobs: Array = []
	for i in CUSTOMERS.size():
		jobs.append({"customer": CUSTOMERS[i], "problem": PROBLEMS[i], "slot": i, "order": i, "powered": true})
	var refused: String = game.restore({"day": day, "jobs": jobs, "connected_slot": 1, "view": "Main"})
	if refused != "":
		push_error("perf_probe: restore refused: " + refused)
		quit(1)
		return
	for knob: String in knobs:
		_turn(knob)
	print("perf_probe: day %d, %s, knobs %s, window %s at scale %.1f, %d Hz, vsync %s, max_fps %d, %s" % [day,
			"capped" if capped else "uncapped", knobs, DisplayServer.window_get_size(), DisplayServer.screen_get_scale(),
			DisplayServer.screen_get_refresh_rate(), DisplayServer.window_get_vsync_mode(), Engine.max_fps,
			RenderingServer.get_video_adapter_name()])
	for viewport in _viewports():
		RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	for each: String in cases:
		await _case(each, capped)
	quit()


func _case(case_name: String, capped: bool) -> void:
	_close_lab()
	match case_name:
		"main":
			game.go_to_view(&"Main")
		"screen":
			game.go_to_view(&"Screen")
		"db":
			game.go_to_view(&"CompuFunDB")
		"Up", "Storage", "Left", "Right", "Trash", "Note", "Workview", "EndUp", "End":
			game.go_to_view(StringName(case_name))
		"lab", "lab_edit":
			game.go_to_view(&"Main")
			_open_lab()
		_:
			push_error("perf_probe: no case " + case_name)
			return
	for i in WARMUP:
		await process_frame
	var editor: TextEdit = _lab_editor() if case_name == "lab_edit" else null
	if case_name == "lab_edit" and editor == null:
		push_error("perf_probe: lab_edit found no TextEdit in the Story Lab")
	var frame_ms: Array[float] = []
	var samples := SAMPLES * 3 if capped else SAMPLES
	var draw_calls := 0.0
	var per_viewport := {}
	for viewport in _viewports():
		per_viewport[viewport] = 0.0
	var start := Time.get_ticks_usec()
	var last := start
	var drawn := Engine.get_frames_drawn()
	print("   %s from %.1f" % [case_name, Time.get_unix_time_from_system()])  # for matching outside samples
	for i in samples:
		if editor != null and i % 6 == 0:
			editor.insert_text_at_caret("x")
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append((now - last) / 1000.0)
		last = now
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		for viewport: Viewport in per_viewport:
			if is_instance_valid(viewport):
				per_viewport[viewport] += RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid())
	print("   %s to %.1f" % [case_name, Time.get_unix_time_from_system()])
	var drawn_per_second := (Engine.get_frames_drawn() - drawn) * 1.0e6 / (Time.get_ticks_usec() - start)
	frame_ms.sort()
	var total := (last - start) / 1000.0
	print("\n== %s: %.2f ms/frame (%.0f fps), median %.2f, p95 %.2f | drawn %.0f/s | draw calls %.0f | nodes %d" % [
			case_name, total / samples, samples * 1000.0 / total, frame_ms[samples / 2], frame_ms[samples * 95 / 100],
			drawn_per_second, draw_calls / samples, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	for viewport: Viewport in per_viewport:
		if not is_instance_valid(viewport):
			continue
		var cpu: float = per_viewport[viewport] / samples
		if cpu >= 0.005:
			print("   %-50s %s cpu %.2f ms" % [_path(viewport), _size(viewport), cpu])


# Turns a part off: +fps=N, +lowproc (low processor mode), +pause, +nopost (the world's post shader),
# +nobuffers (the screen buffers), +noworld, +noshadows, +nolights, +nopipes, +noparticles,
# +nofollow (main's camera follow), +stop=<script> (its processing), +shadowoff=<node> (its lights).
func _turn(knob: String) -> void:
	var world := _main.get_node(^"World") as SubViewportContainer
	match knob.get_slice("=", 0):
		"+fps":
			Engine.max_fps = int(knob.get_slice("=", 1))
		"+noparticles":
			for node in root.find_children("*", "CPUParticles3D", true, false):
				(node as CPUParticles3D).emitting = false
				(node as CPUParticles3D).visible = false
		"+nofollow":
			RenderingServer.frame_pre_draw.disconnect(Callable(_main, &"_follow_camera"))
		"+pause":
			paused = true
		"+lowproc":
			OS.low_processor_usage_mode = true
		"+nopost":
			world.material = null
		"+nobuffers":
			for node in _main.find_children("ScreenBuffer", "SubViewport", true, false):
				(node as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
		"+noworld":
			(world.get_child(0) as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
		"+noshadows":
			for node in _main.find_children("*", "Light3D", true, false):
				(node as Light3D).shadow_enabled = false
		"+nolights":
			for node in _main.find_children("*", "Light3D", true, false):
				(node as Light3D).visible = false
		"+nopipes":
			for node in _main.find_children("*Pipedream*", "", true, false):
				node.process_mode = Node.PROCESS_MODE_DISABLED
				if node is Node3D:
					(node as Node3D).visible = false
		"+stop":
			var file := knob.get_slice("=", 1)
			var stopped := 0
			for node in _main.find_children("*", "", true, false):
				var script := node.get_script() as Script
				if script != null and script.resource_path.get_file().get_basename() == file:
					node.set_process(false)
					node.set_physics_process(false)
					stopped += 1
			print("perf_probe: stopped %d %s" % [stopped, file])
		"+shadowoff":
			var light := _main.find_child(knob.get_slice("=", 1), true, false)
			for node in light.find_children("*", "Light3D", true, false) if light != null else []:
				(node as Light3D).shadow_enabled = false
		_:
			push_error("perf_probe: no knob " + knob)


func _viewports() -> Array[Viewport]:
	var found: Array[Viewport] = [root]
	for node in root.find_children("*", "SubViewport", true, false):
		found.append(node)
	return found


func _path(viewport: Viewport) -> String:
	return "root" if viewport == root else str(root.get_path_to(viewport))


func _size(viewport: Viewport) -> String:
	var mode := ""
	if viewport is SubViewport:
		mode = ["disabled", "once", "when_visible", "when_parent_visible", "always"][(viewport as SubViewport).render_target_update_mode]
	return "%s %s" % [viewport.get_visible_rect().size, mode]


func _lab_menu() -> Node:
	if _dev_menu == null:
		var found := _main.find_children("*", "DevMenu", true, false)
		_dev_menu = found[0] if not found.is_empty() else null
	return _dev_menu


func _open_lab() -> void:
	var menu := _lab_menu()
	if menu == null:
		push_error("perf_probe: no DevMenu in main")
		return
	menu.call(&"_open", menu.get(&"story_lab"))


func _close_lab() -> void:
	var menu := _lab_menu()
	var lab: Node = menu.call(&"_child", menu.get(&"story_lab")) if menu != null else null
	if lab is CanvasItem:
		(lab as CanvasItem).hide()


func _lab_editor() -> TextEdit:
	var menu := _lab_menu()
	var lab: Node = menu.call(&"_child", menu.get(&"story_lab"))
	lab.call(&"open_errand", lab.get(&"_cards").keys()[0])
	for node in lab.find_children("*", "TextEdit", true, false):
		var edit := node as TextEdit
		if edit.is_visible_in_tree() and edit.editable:
			edit.grab_focus()
			return edit
	return null
