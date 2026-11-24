extends VoicePlayer
## A voice for tests that plays no audio: the test sets its timing and how far its line has played.
## Put it on a scene's VoicePlayer node with set_script before the scene enters the tree.

## Each part's Vector2(start, length) in seconds, as [method VoicePlayer.part_times] gives them for
## every line that it says; empty for a voice that doesn't know its timing.
var times: PackedVector2Array = PackedVector2Array()
## How far the line has played, in seconds; [method say] sets it to 0.
var at: float = 0.0

var _saying: DialogueLine


func say(line: DialogueLine, _person: VoicePerson, _effect: VoiceEffect = null) -> float:
	_saying = line
	at = 0.0
	return _end()


func said() -> DialogueLine:
	return _saying


func part_times() -> PackedVector2Array:
	return times if _saying != null else PackedVector2Array()


func played() -> float:
	return minf(at, _end()) if not part_times().is_empty() else -1.0


func hush() -> void:
	_saying = null


func quiet() -> bool:
	return part_times().is_empty() or at >= _end()


func level() -> float:
	return 0.0


func _end() -> float:
	return times[-1].x + times[-1].y if not times.is_empty() else 0.0
