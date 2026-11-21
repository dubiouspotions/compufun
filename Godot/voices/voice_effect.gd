@tool
class_name VoiceEffect
extends Resource
## The top layer of a voice: an effect, such as a corruption, over the person and the mood
## (Voices.layer). It has a base and an alternate set of settings, and a curve over the line that
## says how much of the alternate plays at each moment; Chimera blends the two live as it speaks,
## on every platform (native/chimera_voice/src/voice_type.rs). Speed, pitch, melody, body and
## intonation are set once per line from the curve's average; the voice source and the effects
## follow the curve. The Voice Lab (F3) makes them in voices/effects/, and the Dialogue tab gives
## one to a conversation or a line.

## Settings by key (the Voice Lab's levers); a key that a side leaves out keeps the layers below.
@export var base: Dictionary[String, float] = {}
@export var alternate: Dictionary[String, float] = {}
## How much of the alternate plays, 0 to 1, from the start of the line (left) to its end (right).
## null plays the base alone; a flat line at 1 plays the alternate the whole line.
@export var curve: Curve

const _CURVE_SAMPLES: int = 32


## The text form that ChimeraVoice and the web voice take, from a base, an alternate and a curve.
static func encode(base_settings: Dictionary, alternate_settings: Dictionary, blend: Curve) -> String:
	var parts: PackedStringArray = []
	for entry: Array in [["base", base_settings], ["alt", alternate_settings]]:
		var pairs: PackedStringArray = []
		for key: String in entry[1]:
			pairs.append("%s=%s" % [key, entry[1][key]])
		if not pairs.is_empty():
			parts.append("%s:%s" % [entry[0], ",".join(pairs)])
	if blend != null:
		var points: PackedStringArray = []
		for i in _CURVE_SAMPLES + 1:
			var x := float(i) / _CURVE_SAMPLES
			points.append("%.4f:%.4f" % [x, clampf(blend.sample(x), 0.0, 1.0)])
		parts.append("curve:" + ",".join(points))
	return "|".join(parts)


## The effect that [param line] is said with: its own, else its conversation's, else null.
static func of(line: DialogueLine, conversation: Conversation) -> VoiceEffect:
	if line != null and line.effect != null:
		return line.effect
	return conversation.effect if conversation != null else null
