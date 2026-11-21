class_name CeilingMouse
extends Node3D
## The easter egg in the shop ceiling (wiki: Architecture, "The ceiling mouse"). Once in the whole
## game, a mouse squeaks in its hole above the player; when the player looks straight up, it peeks
## out and drops a computer mouse into the player's hand. With a full hand it keeps the computer
## mouse and tries again on the next look. The flag [constant FLAG] holds how far it got, so a
## conversation can check it.

## How far the ceiling mouse got: the value of the flag [constant FLAG].
enum Stage { HIDING, SQUEAKING, DROPPED }

## The flag that holds the [enum Stage].
const FLAG: StringName = &"ceiling_mouse"

## The seconds after the game starts before the mouse squeaks: a random time from x to y.
@export var wait_seconds: Vector2 = Vector2(30.0, 120.0)
## The seconds between two squeaks while the mouse waits for the player to look up: from x to y.
@export var squeak_seconds: Vector2 = Vector2(4.0, 8.0)
## The view that looks up at the hole. The mouse peeks out when the player is in it.
@export var up_view: StringName = &"Up"
## The part that the mouse drops.
@export var part: Part
## The seconds that the camera takes to look up, before the mouse peeks out.
@export var look_seconds: float = 0.8
## The height of the head above the hole while it hides inside the ceiling, in metres.
@export var hide_height: float = 0.25
## How far below the hole the computer mouse hangs from the snout, in metres.
@export var hang_depth: float = 0.2
## How far the computer mouse falls before it lands in the hand, in metres: to just above the eye.
@export var fall_depth: float = 1.25
## The seconds that the computer mouse takes to fall into the hand.
@export var fall_seconds: float = 0.5

var _peek: Tween
# True once the mouse peeked out during this look up; it peeks once per look.
var _peeked: bool = false

@onready var _head: Node3D = %Head
@onready var _dust: CPUParticles3D = %Dust
@onready var _squeak: AudioStreamPlayer3D = %Squeak
@onready var _wait: Timer = %Wait
@onready var _squeaks: Timer = %Squeaks
@onready var _carried: Node3D = %Carried


## The [enum Stage] that the flag holds now.
static func stage() -> int:
	return Game.flag(FLAG)


func _ready() -> void:
	if part == null or part.model == null:
		push_error("CeilingMouse: %s has no part with a model to drop" % get_path())
	else:
		_carried.add_child(part.model.instantiate())
	_wait.timeout.connect(func() -> void: Game.set_flag(FLAG, Stage.SQUEAKING))
	_squeaks.timeout.connect(_squeak_again)
	Game.changed.connect(_sync)
	_sync()


func _sync() -> void:
	var now := stage()
	if now != Stage.HIDING:
		_wait.stop()
	elif _wait.is_stopped():
		_wait.start(randf_range(wait_seconds.x, wait_seconds.y))
	_dust.emitting = now == Stage.SQUEAKING
	if now != Stage.SQUEAKING:
		_squeaks.stop()
	elif _squeaks.is_stopped():
		_squeak_again()
	if Game.view != up_view:
		_peeked = false
	# A restore that goes back to the start stops a peek; the peek sets DROPPED itself.
	if _peek != null and now == Stage.HIDING:
		_peek.kill()
		_peek = null
	if _peek != null:
		return
	if now == Stage.SQUEAKING and Game.view == up_view and not _peeked:
		_start_peek()
		return
	_head.position.y = hide_height
	_head.rotation.z = 0.0
	_carried.visible = false


func _squeak_again() -> void:
	_squeak.play()
	_squeaks.start(randf_range(squeak_seconds.x, squeak_seconds.y))


# Peeks out with the computer mouse under its snout, squeaks and wiggles. Into an empty hand it lets
# go; with a full hand it takes the computer mouse back in. Then it hides.
func _start_peek() -> void:
	_peeked = true
	var drops := Game.hand == null
	_carried.position = Vector3(0.0, 0.03, 0.0)
	_carried.visible = true
	_peek = create_tween()
	_peek.tween_interval(look_seconds)
	_peek.tween_property(_head, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_peek.parallel().tween_property(_carried, "position:y", -hang_depth, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_peek.tween_callback(_squeak.play)
	_peek.tween_property(_head, "rotation:y", 0.35, 0.12)
	_peek.tween_property(_head, "rotation:y", -0.35, 0.2)
	_peek.tween_property(_head, "rotation:y", 0.0, 0.12)
	if drops:
		_peek.tween_property(_carried, "position:y", -fall_depth, fall_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_peek.tween_callback(_land)
	else:
		_peek.tween_property(_carried, "position:y", 0.03, 0.3).set_delay(0.3)
	_peek.tween_property(_head, "position:y", hide_height, 0.5).set_delay(0.3)
	_peek.tween_callback(_end_peek)


# The computer mouse lands in the hand. A hand that filled since the peek began leaves it with the
# mouse, which then peeks again on the next look.
func _land() -> void:
	_carried.visible = false
	if stage() == Stage.SQUEAKING and Game.take_new_part(part):
		Game.set_flag(FLAG, Stage.DROPPED)


func _end_peek() -> void:
	_peek = null
	_sync()
