class_name Finale
extends CanvasLayer
## The end of the world, after the end (TheEnd) and from the F2 World tab: Cambion takes everything. The view
## turns to the shop and the world stands still (the tree pauses; the finale runs on its own). The
## shop's lights flicker, and every thing in the world turns into a bluescreen, from the farthest to
## the nearest, while the view shakes more and more; just before the end, Win95 error boxes pile up
## over the screen. Then the whole window bluescreens. The player's own computer seems to restart and
## hang with a corrupted drive ([HostBoot]), and the credits show every person. Any key or click then
## starts the game again. Cmd+N (Ctrl+N) skips to the next stage. The text is in [member text].

## The finale while it plays is in this group, so that a second one does not start.
const GROUP := &"finale"
enum HostChoice { AUTO, WINDOWS, MACOS, LINUX, CAMBION }

const LOADING_SCREEN := "res://ui/loading_screen.tscn"
const PEOPLE := "res://people/"
const MESSAGE_BOX: PackedScene = preload("res://win95/message_box.tscn")

## The text of the error boxes, the fake restart and the credits.
@export var text: FinaleText
## The computer whose restart shows; AUTO asks the browser, or the OS on desktop.
@export var host: HostChoice = HostChoice.AUTO
## The seconds that the camera takes to turn to the Main view before the world stands still.
@export var settle_seconds: float = 0.6

@export_group("Flicker and error boxes")
## The seconds of flicker before the bluescreen wave starts.
@export var flicker_seconds: float = 5.0
## The seconds between two changes of the flicker, the shortest and the longest.
@export var flicker_steps: Vector2 = Vector2(0.03, 0.12)
## How often a flicker step also dims the whole view, 0 to 1, and the colour that it dims to.
@export_range(0.0, 1.0) var dim_chance: float = 0.15
@export var dim_colour: Color = Color(0.6, 0.6, 0.65)
## The error boxes come in the last this many seconds before the whole window bluescreens.
@export var boxes_seconds: float = 3.5
## The seconds between two error boxes, at the first box and at the last.
@export var box_every_first: float = 0.4
@export var box_every_last: float = 0.06
## The most error boxes on screen.
@export var most_boxes: int = 40
## Every this many boxes plays the Win95 chord.
@export var chord_every: int = 4

@export_group("Bluescreen wave")
## The seconds that the bluescreen takes from the farthest thing to the nearest.
@export var wave_seconds: float = 12.0
## The seconds that a thing flickers between itself and the bluescreen before it stays blue.
@export var turn_seconds: float = 0.4
## How many bluescreens fit in one metre on a thing.
@export var bluescreens_per_metre: float = 0.6
## The share of the wave from which the view shakes, 0 to 1, and how far it shakes at the end, in metres.
@export_range(0.0, 1.0) var shake_from: float = 0.6
@export var shake_metres: float = 0.03

@export_group("The crash, the restart and the credits")
## The seconds that the whole window shows the bluescreen.
@export var bluescreen_seconds: float = 4.0
## The seconds of black screen before the computer seems to start again.
@export var off_seconds: float = 1.5
## The seconds that the boot screen hangs before the error.
@export var stuck_seconds: float = 7.0
## Windows: the seconds of "Preparing Automatic Repair" before the error.
@export var repair_seconds: float = 4.0
## The seconds that the error shows before the credits.
@export var error_seconds: float = 12.0
## The seconds that the credits take to fade in.
@export var credits_fade_seconds: float = 1.5
## The seconds after the fade-in before a key starts the game again, so that a stray key does not.
@export var credits_hold_seconds: float = 1.0

var _playing: bool = false
var _skip: bool = false
var _clock: float = 0.0
var _holding_still: bool = false
var _world: Control
var _buffer: SubViewport
var _camera: Camera3D
var _lights: Dictionary[Light3D, float] = {}
var _flickering: bool = false
var _next_flicker: float = 0.0
var _boxes: int = 0
var _next_box: float = INF
var _boxes_from: float = 0.0
var _boxes_until: float = 0.0
var _credits_from: float = INF
var _material: StandardMaterial3D
# Each thing that the wave turns: {node, distance, at (seconds into the wave), shown (blue now), done}.
var _things: Array[Dictionary] = []
var _blue: Dictionary[GeometryInstance3D, bool] = {}
var _wave_start: float = INF
var _next_reapply: float = 0.0

@onready var _box_layer: SubViewportContainer = %Boxes
@onready var _box_buffer: SubViewport = %BoxBuffer
@onready var _bluescreen: Control = %Bluescreen
@onready var _bluescreen_buffer: SubViewport = _bluescreen.get_node("%Buffer")
@onready var _boot: HostBoot = %Boot
@onready var _credits: Control = %Credits
@onready var _chord: AudioStreamPlayer = %Chord
@onready var _buzz: AudioStreamPlayer = %Buzz


func _ready() -> void:
	add_to_group(GROUP)
	_bluescreen.hide()
	_bluescreen_buffer.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_boot.hide()
	_credits.hide()
	_credits.gui_input.connect(_on_credits_input)
	_boot.text = text


## True from [method play] until the game starts again.
func is_playing() -> bool:
	return _playing


## The stage that shows now: &"corruption", &"bluescreen", &"restart" or &"credits"; &"" before
## [method play].
func stage() -> StringName:
	if _credits.visible:
		return &"credits"
	if _boot.visible:
		return &"restart"
	if _bluescreen.visible:
		return &"bluescreen"
	return &"corruption" if _playing else &""


## True while [param thing] shows the bluescreen.
func is_blue(thing: GeometryInstance3D) -> bool:
	return _blue.has(thing)


## The people in the credits: each person in [constant PEOPLE] with a name and a neutral portrait.
static func cast() -> Array[Person]:
	var people: Array[Person] = []
	for entry: String in ResourceLoader.list_directory(PEOPLE):
		var path := PEOPLE + entry + "person.tres"
		if not entry.ends_with("/") or not ResourceLoader.exists(path):
			continue
		var person := load(path) as Person
		if person == null:
			push_error("Finale: %s is not a Person" % path)
			continue
		if person.name != "" and person.portraits.get(&"neutral") != null:
			people.append(person)
	return people


## Plays a finale in [param tree]'s current scene, showing the restart of [param host_choice]. Does
## nothing while one plays.
static func start(tree: SceneTree, host_choice: HostChoice = HostChoice.AUTO) -> void:
	if tree.get_first_node_in_group(GROUP) != null:
		return
	if tree.current_scene == null:
		push_error("Finale.start: the tree has no current scene to play in")
		return
	var finale := (load("res://finale/finale.tscn") as PackedScene).instantiate() as Finale
	finale.host = host_choice
	tree.current_scene.add_child(finale)
	finale.play()


## Runs the finale from the flicker to the credits. It finds the world in the group "world_post".
func play() -> void:
	if _playing:
		return
	_world = get_tree().get_first_node_in_group(&"world_post") as Control
	_buffer = _world.get_child(0) as SubViewport if _world != null else null
	_camera = _buffer.get_camera_3d() if _buffer != null else null
	if _camera == null:
		push_error("Finale: no world with a camera in the group world_post")
		return
	_playing = true
	Game.go_to_view(&"Main")
	var ui := get_tree().get_first_node_in_group(&"ui_layer") as CanvasLayer
	if ui != null:
		ui.hide()  # the turn buttons and the status line: the player only watches now
	_material = await _make_material()
	for node: Node in _buffer.find_children("*", "Light3D", true, false):
		if not node is DirectionalLight3D:
			# A light that is off now (a ceiling light by day) flickers around full strength.
			var light := node as Light3D
			_lights[light] = light.light_energy if light.visible and light.light_energy > 0.0 else 1.0
	_flickering = true
	await _wait(settle_seconds)
	_holding_still = true
	await _wait(maxf(flicker_seconds - settle_seconds, 0.0))
	_start_wave()
	await _wait(wave_seconds + 0.6)
	_turn_things(wave_seconds + turn_seconds + 1.0)  # a skip ends the wave with everything blue
	_crash()
	await _wait(bluescreen_seconds)
	_bluescreen.hide()
	_boot.host = _host()
	_boot.show_stage(HostBoot.Stage.OFF)
	_boot.show()
	await _wait(off_seconds)
	_boot.show_stage(HostBoot.Stage.STARTING)
	await _wait(stuck_seconds)
	if _boot.host == HostBoot.Host.WINDOWS:
		_boot.show_stage(HostBoot.Stage.REPAIRING)
		await _wait(repair_seconds)
	_boot.show_stage(HostBoot.Stage.FAILED)
	await _wait(error_seconds)
	_show_credits()


func _host() -> HostBoot.Host:
	match host:
		HostChoice.WINDOWS:
			return HostBoot.Host.WINDOWS
		HostChoice.MACOS:
			return HostBoot.Host.MACOS
		HostChoice.LINUX:
			return HostBoot.Host.LINUX
		HostChoice.CAMBION:
			return HostBoot.Host.CAMBION
	return HostBoot.detect()


func _process(delta: float) -> void:
	_clock += delta
	if not _playing:
		return
	# Reconciled every frame: a tool that pauses and unpauses (F9, the Voice Lab) must not let the
	# world run again under the finale.
	if _holding_still and not get_tree().paused:
		get_tree().paused = true
	if _flickering and _clock >= _next_flicker:
		_flicker()
	if _clock >= _next_box and _boxes < most_boxes:
		_add_box()
		var progress := clampf((_clock - _boxes_from) / maxf(_boxes_until - _boxes_from, 0.01), 0.0, 1.0)
		_next_box = _clock + lerpf(box_every_first, box_every_last, progress)
	if _clock >= _wave_start:
		_turn_things(_clock - _wave_start)


# Only the skip is taken this early; every other key goes to the focused screen first (F2, F3, F9).
func _input(event: InputEvent) -> void:
	if _playing and event.is_action_pressed(&"skip_ahead") and OS.is_debug_build():
		_skip = true
		get_viewport().set_input_as_handled()


# A key that no screen took: it starts the game again in the credits, and otherwise does nothing, so
# that no key turns the view while the world ends. This comes before the room's _unhandled_input.
func _unhandled_key_input(event: InputEvent) -> void:
	if not _playing:
		return
	get_viewport().set_input_as_handled()
	if _credits.visible and event.is_pressed() and not event.is_echo():
		_try_start_again()


func _on_credits_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		_credits.accept_event()
		_try_start_again()


# Waits [param seconds] of the finale's own clock, which runs while the tree is paused, or until a skip.
func _wait(seconds: float) -> void:
	_skip = false
	var until := _clock + seconds
	while _clock < until and not _skip:
		await get_tree().process_frame


# The bluescreen as a texture on any thing: Win95's own bluescreen, drawn once.
func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * bluescreens_per_metre
	var image: Image = null
	if DisplayServer.get_name() != "headless":
		_bluescreen_buffer.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		image = _bluescreen_buffer.get_texture().get_image()
		if image == null or image.is_empty():
			push_error("Finale: the bluescreen did not draw; things turn plain blue")
	if image == null or image.is_empty():
		material.albedo_color = _blue_colour()
		return material
	var error := image.generate_mipmaps()
	if error != OK:
		push_error("Finale: no mipmaps for the bluescreen texture: %s" % error_string(error))
	material.albedo_texture = ImageTexture.create_from_image(image)
	return material


func _blue_colour() -> Color:
	return (_bluescreen.get_node("%Blue") as ColorRect).color


func _flicker() -> void:
	_next_flicker = _clock + randf_range(flicker_steps.x, flicker_steps.y)
	for light: Light3D in _lights:
		if is_instance_valid(light):
			light.visible = true
			light.light_energy = _lights[light] * (randf_range(0.0, 0.3) if randf() < 0.5 else randf_range(0.8, 1.3))
	_world.modulate = dim_colour if randf() < dim_chance else Color.WHITE


func _add_box() -> void:
	if text == null or text.popup_messages.is_empty():
		push_error("Finale: no error box messages in the text")
		_boxes = most_boxes
		return
	var box := MESSAGE_BOX.instantiate()
	box.set(&"error_sound", null)
	_box_buffer.add_child(box)
	box.call(&"show_message", text.popup_title, text.popup_messages[randi() % text.popup_messages.size()])
	var room := Vector2(_box_buffer.size) - (box as Control).get_combined_minimum_size()
	(box as Control).position = Vector2(randf() * maxf(room.x, 0.0), randf() * maxf(room.y, 0.0)).round()
	if chord_every > 0 and _boxes % chord_every == 0:
		_chord.play()
	_boxes += 1


# Lists every thing in the world with the time when the wave reaches it: the farthest at once, the
# nearest at the end, evenly in the logarithm of the distance, so the shop takes as long as the alley.
# Hidden things are listed too: a bluescreen on a hidden thing is harmless, and shows if it appears.
func _start_wave() -> void:
	var eye := _camera.global_position
	var near := INF
	var far := 0.0
	for node: Node in _buffer.find_children("*", "GeometryInstance3D", true, false):
		var thing := node as GeometryInstance3D
		if not thing.is_inside_tree() or thing is GPUParticles3D or thing is CPUParticles3D:
			continue
		var distance := maxf(eye.distance_to(thing.global_transform * thing.get_aabb().get_center()), 0.3)
		near = minf(near, distance)
		far = maxf(far, distance)
		_things.append({node = thing, distance = distance, shown = false, done = false})
	var span := maxf(log(far) - log(near), 0.001)
	for thing: Dictionary in _things:
		thing.at = wave_seconds * (log(far) - log(thing.distance)) / span
	var environment := _environment()
	if environment != null:
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = _blue_colour()
		environment.fog_light_color = _blue_colour()
	_buzz.play()
	_wave_start = _clock
	_boxes_until = _clock + wave_seconds + 0.6
	_boxes_from = maxf(_clock, _boxes_until - boxes_seconds)
	_next_box = _boxes_from


func _environment() -> Environment:
	for node: Node in _buffer.find_children("*", "WorldEnvironment", true, false):
		return (node as WorldEnvironment).environment
	return null


# A thing flickers between itself and the bluescreen for turn_seconds, then stays blue. A label or a
# sprite goes out instead. The change is in the renderer, not in the node's material_override, which
# the thing's own script may use; as a write to that property puts the thing's own material back,
# the blue is put on again every few frames.
func _turn_things(elapsed: float) -> void:
	var reapply := _clock >= _next_reapply
	if reapply:
		_next_reapply = _clock + 0.2
	for thing: Dictionary in _things:
		if not is_instance_valid(thing.node):
			_blue.erase(thing.node)
			thing.done = true
			continue
		var node := thing.node as GeometryInstance3D
		if thing.done:
			if reapply:
				_show_blue(node, true)
			continue
		var at: float = thing.at
		var blue := elapsed >= at or (elapsed >= at - turn_seconds and int(elapsed * 16.0) % 2 == 0)
		thing.done = elapsed >= at
		if blue != thing.shown:
			thing.shown = blue
			_show_blue(node, blue)
	var shake := shake_metres * smoothstep(shake_from, 1.0, elapsed / maxf(wave_seconds, 0.01))
	_camera.h_offset = randf_range(-shake, shake)
	_camera.v_offset = randf_range(-shake, shake)


func _show_blue(thing: GeometryInstance3D, blue: bool) -> void:
	if blue:
		_blue[thing] = true
	else:
		_blue.erase(thing)
	if thing is Label3D or thing is SpriteBase3D:
		RenderingServer.instance_set_visible(thing.get_instance(), thing.is_visible_in_tree() and not blue)
	else:
		var own := thing.material_override.get_rid() if thing.material_override != null else RID()
		RenderingServer.instance_geometry_set_material_override(thing.get_instance(), _material.get_rid() if blue else own)


# The whole window bluescreens with the Critical Stop chord.
func _crash() -> void:
	_flickering = false
	_wave_start = INF
	_boxes = most_boxes
	_world.modulate = Color.WHITE
	_camera.h_offset = 0.0
	_camera.v_offset = 0.0
	_box_layer.hide()
	_buzz.stop()
	_bluescreen_buffer.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_bluescreen.show()
	_chord.play()


# The credits fade in over the black of the restart, so the frozen shop never shows between them.
func _show_credits() -> void:
	_boot.show_stage(HostBoot.Stage.OFF)
	(%Thanks as Label).text = text.thanks
	(%CastHeading as Label).text = text.cast_heading
	(%Lines as Label).text = text.credits
	(%Hint as Label).text = text.restart_hint
	var row := %Cast as HBoxContainer
	var people := cast()
	var width := minf(170.0, get_viewport().get_visible_rect().size.x * 0.9 / maxf(people.size(), 1.0) - row.get_theme_constant(&"separation"))
	for person: Person in people:
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var portrait := TextureRect.new()
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.texture = _cut_to_person(person.portraits[&"neutral"])
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(width, width * 1.5)
		var label := Label.new()
		label.text = person.name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size.x = width
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override(&"font_size", 20)
		column.add_child(portrait)
		column.add_child(label)
		row.add_child(column)
	_credits.modulate.a = 0.0
	_credits.show()
	_credits_from = _clock + credits_fade_seconds + credits_hold_seconds
	create_tween().tween_property(_credits, "modulate:a", 1.0, credits_fade_seconds)


# The portrait cut to the person in it: the pictures have wide transparent margins.
static func _cut_to_person(portrait: Texture2D) -> Texture2D:
	var image := portrait.get_image()
	if image == null:
		push_error("Finale: cannot read the portrait %s" % portrait.resource_path)
		return portrait
	if image.is_compressed() and image.decompress() != OK:
		push_error("Finale: cannot decompress the portrait %s" % portrait.resource_path)
		return portrait
	var used := image.get_used_rect()
	if used.size == Vector2i.ZERO:
		return portrait
	var cut := AtlasTexture.new()
	cut.atlas = portrait
	cut.region = Rect2(used)
	return cut


func _try_start_again() -> void:
	if _clock < _credits_from:
		return
	get_tree().paused = false
	Game.reboot()
	var error := get_tree().change_scene_to_file(LOADING_SCREEN)
	if error != OK:
		get_tree().paused = true
		(%Hint as Label).text = "Cannot start again from %s: %s" % [LOADING_SCREEN, error_string(error)]
		push_error("Finale: cannot start the game again from %s: %s" % [LOADING_SCREEN, error_string(error)])
		return
	_playing = false
	_holding_still = false
