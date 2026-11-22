class_name Ending
extends Resource
## One way the week can end (wiki: Architecture, "The endings"): one file per ending,
## endings/<id>.tres. When the game has ENDED, Game.ending() names the one that plays, and the scene
## of that ending plays while it does.

## The feature switch: off, the ending never plays, whatever its condition says.
@export var enabled: bool = true
## When the ending may play, by the flags on the last day; null always.
@export var when: Condition
## Of the endings that may play, the one with the highest priority does.
@export var priority: int = 0


## The ending's id, from its file name, such as &"finale".
func id() -> StringName:
	return StringName(resource_path.get_file().get_basename())
