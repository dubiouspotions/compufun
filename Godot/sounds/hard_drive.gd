class_name HardDrive
extends AudioStreamPlayer3D
## A computer's hard drive: it seeks, a tick at a time, while something reads from it. One player,
## so a tick cuts the last one off rather than doubling it.

## The ticks of a read.
@export var seek: SoundSet = preload("res://sounds/hdd_seek.tres")
## The seconds between two ticks of a read, picked between x and y.
@export var seek_seconds: Vector2 = Vector2(0.05, 0.2)


## Reads for [param seconds], ticking. False when [param still] stops returning true meanwhile, or
## the drive leaves the tree; [param still] is checked after each tick.
func read(seconds: float, still: Callable = func() -> bool: return true) -> bool:
	while seconds > 0.0:
		if seek != null:
			seek.play_on(self)
		var wait := minf(seconds, randf_range(seek_seconds.x, seek_seconds.y))
		seconds -= wait
		await get_tree().create_timer(wait).timeout
		if not is_inside_tree() or not still.call():
			return false
	return true


## Reads for [param seconds] on [param drive], or just waits them out without one (a computer
## that isn't in the room, as in a test). False as in [method read].
static func read_on(drive: HardDrive, seconds: float, tree: SceneTree, still: Callable = func() -> bool: return true) -> bool:
	if drive != null and drive.is_inside_tree():
		return await drive.read(seconds, still)
	if seconds > 0.0:  # 0 returns at once, as a read of 0 does
		await tree.create_timer(seconds).timeout
	return still.call()
