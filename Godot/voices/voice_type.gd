@tool
class_name VoiceType
extends Resource
## A way of speaking that the Voice Lab (F3) makes and the Dialogue tab gives to a conversation or
## a line: a base voice, an alternate voice, and a curve over the line that says how much of the
## alternate plays at each moment. Chimera blends the two live as it speaks, on every platform
## (native/chimera_voice/src/voice_type.rs). Speed, pitch, melody, body and intonation are set once
## per line from the curve's average; the voice source and the effects follow the curve.

## Settings by key (the Voice Lab's levers); a key that a voice leaves out changes nothing.
@export var base: Dictionary[String, float] = {}
@export var alternate: Dictionary[String, float] = {}
## How much of the alternate plays, 0 to 1, from the start of the line (left) to its end (right).
## null plays the base alone; a flat line at 1 plays the alternate the whole line.
@export var curve: Curve

const _CURVE_SAMPLES: int = 32


## The text form that ChimeraVoice and the web voice take.
func encode() -> String:
	var parts: PackedStringArray = []
	for entry: Array in [["base", base], ["alt", alternate]]:
		var pairs: PackedStringArray = []
		for key: String in entry[1]:
			pairs.append("%s=%s" % [key, entry[1][key]])
		if not pairs.is_empty():
			parts.append("%s:%s" % [entry[0], ",".join(pairs)])
	if curve != null:
		var points: PackedStringArray = []
		for i in _CURVE_SAMPLES + 1:
			var x := float(i) / _CURVE_SAMPLES
			points.append("%.4f:%.4f" % [x, clampf(curve.sample(x), 0.0, 1.0)])
		parts.append("curve:" + ",".join(points))
	return "|".join(parts)


## The voice type that [param line] is said in: its own, else its conversation's, else null.
static func of(line: DialogueLine, conversation: Conversation) -> VoiceType:
	if line != null and line.voice_type != null:
		return line.voice_type
	return conversation.voice_type if conversation != null else null
