class_name DialogueOverlay
extends Control
## A customer talks: their portrait, one line of a conversation at a time.
## The portrait sways and breathes, and shakes in time with the voice.

## The player clicked OK on the last line.
signal finished

const _NEUTRAL := &"neutral"
## Source pixels either side of the torso center that still count as the head.
const _HEAD_WINDOW := 4
## A finger on the center line is narrower than this, so it does not set the crown.
const _HEAD_MIN := 16
## Consecutive head-width rows required before a row counts as the crown.
const _HEAD_RUN := 6
## Hands cover the head, so the usual crown scale blows the pose up. Match the neutral portrait's height instead.
const _MATCH_NEUTRAL_HEIGHT := "young_entrepreneur/portrait_irritated03.png"

## How long the portrait takes to rise from behind the box when a conversation starts, in seconds;
## 0 shows it at once.
@export_range(0.0, 2.0) var rise_seconds: float = 0.45
## The share of the crown-to-hem distance that sits above the portrait's slot: 0.18 is about half
## a head over the top edge; a negative value keeps the whole head inside a framed slot.
@export_range(-0.5, 0.5) var head_above: float = 0.18
## How far the portrait sways from side to side, as if keeping its balance, in degrees.
@export_range(0.0, 5.0) var sway_degrees: float = 0.4
## How long one sway, there and back, takes, in seconds.
@export_range(1.0, 20.0) var sway_seconds: float = 6.0
## How much the portrait rises with each breath, as a share of its height.
@export_range(0.0, 0.05) var breath_rise: float = 0.005
## How long one breath takes, in seconds.
@export_range(1.0, 10.0) var breath_seconds: float = 3.5
## How much the portrait stretches up with the voice at its loudest, as a share of its height.
@export_range(0.0, 0.1) var talk_rise: float = 0.02
## How far the portrait tips to each side with the voice at its loudest, in degrees.
@export_range(0.0, 10.0) var talk_degrees: float = 1.2
## How many times a second the portrait tips to and fro while the voice is loud.
@export_range(1.0, 15.0) var talk_shakes: float = 5.0
## How quickly the talking follows the voice's level: higher is snappier, lower is smoother.
@export_range(1.0, 60.0) var talk_follow: float = 25.0
## The portrait's crown moves in steps of this many screen pixels (at 1080p); 0 moves smoothly.
@export_range(0.0, 4.0) var motion_step: float = 1.0
## The Next button's text on every line but the last, and on the last.
@export var next_text: String = "Next"
@export var last_text: String = "OK"

var _customer: Customer
var _conversation: Conversation
var _lines: Array[DialogueLine] = []
var _line: int = 0
# False while the box shows its own error line, which has no voice.
var _voiced: bool = false
var _time: float = 0.0
# The voice level that moves the portrait, smoothed: 0 to 1.
var _talk: float = 0.0
var _rise: Tween
# Where the portrait's slot stands when it has risen: its offset_top and offset_bottom in the scene.
var _slot_top: float
var _slot_bottom: float
# The pixels of the portrait's texture that are not transparent.
var _figure: Rect2i
# The drawn height from the hem to the crown.
var _reach: float = 0.0

@onready var _name: Label = %NameLabel
@onready var _text: TypedLabel = %LineLabel
@onready var _portrait_slot: Panel = %Portrait
@onready var _portrait: TextureRect = %PortraitTexture
@onready var _next: Button = %NextButton
@onready var _voice: VoicePlayer = %Voice


func _ready() -> void:
	_next.pressed.connect(_on_next)
	_portrait_slot.resized.connect(_fit_portrait)
	_slot_top = _portrait_slot.offset_top
	_slot_bottom = _portrait_slot.offset_bottom


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_talk = lerpf(_talk, _voice.level() if _voiced else 0.0, minf(delta * talk_follow, 1.0))
	var sway := sway_degrees * sin(TAU * _time / sway_seconds)
	var shake := talk_degrees * _talk * sin(TAU * _time * talk_shakes)
	var breath := breath_rise * (0.5 + 0.5 * sin(TAU * _time / breath_seconds))
	_portrait.rotation = _snap(deg_to_rad(sway + shake))
	_portrait.scale = Vector2(1.0, 1.0 + _snap(breath + talk_rise * _talk))


# Rounds [param share], a turn in radians or a stretch as a share of the height, so the crown
# moves by whole screen pixels.
func _snap(share: float) -> float:
	if motion_step <= 0.0 or _reach <= 0.0:
		return share
	var step := motion_step / _reach
	return roundf(share / step) * step


## Starts [param conversation] of [param customer] at the first line. A null or empty
## conversation shows the error in the box, so the player can still go on.
func start(customer: Customer, conversation: Conversation) -> void:
	if customer == null:
		push_error("DialogueOverlay.start: no customer")
		return
	_customer = customer
	_conversation = conversation
	_line = 0
	_name.text = customer.spoken_name()
	if conversation == null or conversation.lines.is_empty():
		var message := ("%s has no conversation for day %d and flags %s" % [customer.resource_path,
				Game.day_number, Game.flags]) if conversation == null else (
				"%s: the conversation '%s' has no lines" % [customer.resource_path, conversation.id])
		push_error("DialogueOverlay.start: " + message)
		var error_line := DialogueLine.new()
		error_line.text = "ERROR: " + message
		_lines = [error_line]
		_voiced = false
	else:
		_lines = conversation.lines
		_voiced = true
	_rise_portrait()
	_show_line()


## The top right corner of the customer in the portrait, in this overlay's coordinates, as it
## sways; Vector2.INF while no portrait shows or it still rises. Something that hovers over the
## customer goes there, such as the [x] of the corruption sign customer_x.
func portrait_corner() -> Vector2:
	if _portrait.texture == null or not _figure.has_area() or (_rise != null and _rise.is_running()):
		return Vector2.INF
	var texel := _portrait.size / _portrait.texture.get_size()
	var corner := Vector2(_figure.end.x, _figure.position.y) * texel
	return get_global_transform().affine_inverse() * (_portrait.get_global_transform() * corner)


## Slides the portrait up from under the box's bottom edge, where PortraitClip hides it, to where
## it stands in the scene.
func _rise_portrait() -> void:
	if _rise != null:
		_rise.kill()
	_portrait_slot.offset_top = _slot_top
	_portrait_slot.offset_bottom = _slot_bottom
	if rise_seconds <= 0.0:
		return
	# The head reaches above the slot, so the slot starts more than its own height down.
	var drop := (_slot_bottom - _slot_top) * 1.5
	_portrait_slot.offset_top = _slot_top + drop
	_portrait_slot.offset_bottom = _slot_bottom + drop
	_rise = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_rise.tween_property(_portrait_slot, "offset_top", _slot_top, rise_seconds)
	_rise.tween_property(_portrait_slot, "offset_bottom", _slot_bottom, rise_seconds)


## Shows the portrait of [param pose]. A pose the person has no portrait for shows "neutral".
func _show_portrait(pose: StringName) -> void:
	_portrait.texture = null
	_figure = Rect2i()
	var person := _customer.person
	if person == null:
		push_error("DialogueOverlay: %s has no person" % _customer.resource_path)
		return
	var shown := pose if pose != &"" else _NEUTRAL
	if not person.portraits.has(shown):
		push_error("DialogueOverlay: %s has no \"%s\" portrait" % [person.resource_path, shown])
		shown = _NEUTRAL
	if not person.portraits.has(shown):
		return
	_portrait.texture = person.portraits[shown]
	_fit_portrait()


## Each pose is scaled so its hem meets the bottom of the column and the head crosses the top edge at the same height. The young entrepreneur's hands-up pose is scaled to the same height as his neutral portrait.
func _fit_portrait() -> void:
	var tex := _portrait.texture
	if tex == null or _portrait_slot.size.y <= 0.0:
		return
	var image := tex.get_image()
	if image == null:
		push_error("DialogueOverlay: can't read %s" % tex.resource_path)
		return
	var measured := _measure(image)
	if measured.z < 0.0:
		push_error("DialogueOverlay: %s has no visible pixels" % tex.resource_path)
		return
	_figure = image.get_used_rect()
	var crown := measured.y
	var hem := measured.z + 1.0
	var cut := crown + head_above * (hem - crown)
	var scale := _portrait_slot.size.y / (hem - cut)
	if tex.resource_path.ends_with(_MATCH_NEUTRAL_HEIGHT):
		var target := _neutral_height(tex.resource_path)
		if target <= 0.0:
			return
		scale = target / float(image.get_height())
		cut = hem - _portrait_slot.size.y / scale
	var draw := Vector2(image.get_width(), image.get_height()) * scale
	var left := _portrait_slot.size.x * 0.5 - measured.x * scale
	var top := -cut * scale - _portrait_slot.size.y
	_portrait.anchor_left = 0.0
	_portrait.anchor_right = 0.0
	_portrait.anchor_top = 1.0
	_portrait.anchor_bottom = 1.0
	_portrait.offset_left = left
	_portrait.offset_right = left + draw.x
	_portrait.offset_top = top
	_portrait.offset_bottom = top + draw.y
	_reach = (hem - crown) * scale
	# Sway, breathe and talk from the hem at the bottom centre of the slot.
	_portrait.pivot_offset = Vector2(_portrait_slot.size.x * 0.5 - left, -top)


## Drawn height of the neutral portrait next to [param path], in pixels. Negative when it cannot be measured.
func _neutral_height(path: String) -> float:
	var neutral_path := path.replace("portrait_irritated03.png", "portrait_neutral.png")
	var neutral := load(neutral_path) as Texture2D
	if neutral == null:
		push_error("DialogueOverlay: can't load %s" % neutral_path)
		return -1.0
	var image := neutral.get_image()
	if image == null:
		push_error("DialogueOverlay: can't read %s" % neutral_path)
		return -1.0
	var measured := _measure(image)
	if measured.z < 0.0:
		push_error("DialogueOverlay: %s has no visible pixels" % neutral_path)
		return -1.0
	var hem := measured.z + 1.0
	var cut := measured.y + head_above * (hem - measured.y)
	return image.get_height() * _portrait_slot.size.y / (hem - cut)


## x is the torso center, y is the crown, z is the last opaque row.
func _measure(image: Image) -> Vector3:
	var width := image.get_width()
	var height := image.get_height()
	var top := height
	var bottom := -1
	for y in height:
		for x in width:
			if image.get_pixel(x, y).a <= 0.04:
				continue
			top = mini(top, y)
			bottom = maxi(bottom, y)
	if bottom < 0:
		return Vector3(0, 0, -1)
	var band := bottom - int((bottom - top) * 0.25)
	var torso := PackedInt32Array()
	for y in range(band, bottom + 1):
		for x in width:
			if image.get_pixel(x, y).a > 0.04:
				torso.append(x)
	if torso.is_empty():
		return Vector3(0, 0, -1)
	torso.sort()
	var axis := torso[torso.size() >> 1]
	var crown := _crown(image, axis)
	if crown > bottom:
		return Vector3(0, 0, -1)
	return Vector3(axis, crown, bottom)


## Top of the head on the torso column. A thin shape above it, such as a raised hand, is ignored.
func _crown(image: Image, axis: int) -> int:
	var height := image.get_height()
	var first := height
	var solid := 0
	for y in height:
		var run := _center_run(image, y, axis)
		if first == height and run > 0:
			first = y
		if run >= _HEAD_MIN:
			solid += 1
			if solid >= _HEAD_RUN:
				return y - _HEAD_RUN + 1
		else:
			solid = 0
	return first


func _center_run(image: Image, y: int, axis: int) -> int:
	var width := image.get_width()
	var x0 := maxi(axis - _HEAD_WINDOW, 0)
	var x1 := mini(axis + _HEAD_WINDOW, width - 1)
	var hit := -1
	for x in range(x0, x1 + 1):
		if image.get_pixel(x, y).a > 0.04:
			hit = x
			break
	if hit < 0:
		return 0
	var left := hit
	while left > 0 and image.get_pixel(left - 1, y).a > 0.04:
		left -= 1
	var right := hit
	while right + 1 < width and image.get_pixel(right + 1, y).a > 0.04:
		right += 1
	return right - left + 1


func _show_line() -> void:
	var line := _lines[_line]
	_text.type_out(line.text if line != null else "")
	_show_portrait(line.pose if line != null else _NEUTRAL)
	_next.text = next_text if _line < _lines.size() - 1 else last_text
	_speak(line)


## Stops the shown line's voice; the line and its text stay.
func hush() -> void:
	_voice.hush()


## Says the shown line again from its start, as when the player looks back at the customer.
func replay() -> void:
	if _line < _lines.size():
		_speak(_lines[_line])


## Plays the voice file of [param line]. A line without one stays silent: its voice is not rendered yet.
func _speak(line: DialogueLine) -> void:
	_voice.hush()
	if _voiced:
		_voice.say(line, _customer.voice, VoiceEffect.of(line, _conversation))


func _on_next() -> void:
	if _text.is_typing():  # a click while the line types shows the rest
		_text.finish()
		return
	if _line >= _lines.size() - 1:
		_voice.hush()
		finished.emit()
		return
	_line += 1
	_show_line()
