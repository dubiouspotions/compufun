class_name CorruptionSign
extends Node
## One corruption sign: a change to the shop that Cambion makes (wiki: In-world - Corruption Signs,
## and Architecture, "Corruption signs"). Its scene is corruption/<id>.tscn; CorruptionSigns loads
## every one into the shop. The sign does not decide when it starts: the trigger layer sets the flag
## sign_<id> to 1, or to a later stage, and the sign shows while that flag is set and [member enabled]
## is on. A sign finds what it changes by group, such as &"logo_signs".

## When in the week the wiki page puts the sign: Early (day 1 to 3), Mid (day 3 to 5), Late (day 5
## to 7). The F2 Signs tab groups the signs by it; the trigger layer may read it.
enum Timing { EARLY, MID, LATE }

## The group of every sign, for the F2 Signs tab.
const GROUP: StringName = &"corruption_signs"

## The feature switch: off, the sign never shows, whatever its flag says. The F2 Signs tab changes it
## while the game runs; the scene keeps the value that the build ships with.
@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_node_ready():
			_sync()
## What the sign does, in a few words, for the F2 Signs tab.
@export var title: String = ""
## When in the week the sign belongs, as the wiki page groups it.
@export var timing: Timing = Timing.EARLY
## How the sign looks in the game, for people: the Story Lab's Signs section shows it.
@export_multiline var description: String = ""
## What the player must do to see the sign, for the F2 Signs tab, such as "Go to the Storage View."
## Empty when the sign shows at once.
@export var hint: String = ""
## The highest stage of the sign. 1: the sign is on or off. More: each stage goes further, or a
## one-time event moves itself on to a "done" stage.
@export var stages: int = 1


## The sign's id, from its file name, such as &"logo_blue".
func id() -> StringName:
	return StringName(scene_file_path.get_file().get_basename())


## The flag that the trigger layer sets to start the sign: sign_<id>.
func flag() -> StringName:
	return Game.sign_flag(id())


## The stage that the sign shows now: the flag's value, or 0 while it is not enabled.
func stage() -> int:
	return Game.flag(flag()) if enabled else 0


## Sets the sign's flag to [param value]: the trigger layer's way to start it, and an event's way to
## record that it is done. 0 takes the sign back.
func set_stage(value: int) -> void:
	Game.set_flag(flag(), value)


func _ready() -> void:
	add_to_group(GROUP)
	if title.is_empty():
		push_error("CorruptionSign: %s has no title" % scene_file_path)
	Game.changed.connect(_sync)
	_sync()


func _sync() -> void:
	_apply(stage())


## True while the sign plays a one-time event that the night must wait for: EndOfDay does not fade
## out the evening until no sign is busy.
func busy() -> bool:
	return false


## Shows [param shown_stage] (0: the shop as it was). Runs on every change of the game, so it must
## converge on that stage from any state, and a 0 must undo the sign completely.
func _apply(_shown_stage: int) -> void:
	pass
