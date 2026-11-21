@tool
class_name VoiceMood
extends Resource
## The middle layer of a voice: how a line in one pose is said, over the person and under an
## effect (Voices.layer). voices/moods/<pose>.tres holds the mood of each pose; the Voice Lab (F3)
## edits them.

## The speaking speed: 1 is normal, more is faster.
@export_range(0.5, 2.0, 0.01) var rate: float = 1.0
## The pitch, as a factor on the voice's own: 1 is normal, more is higher.
@export_range(0.5, 2.0, 0.01) var pitch: float = 1.0
## How far the pitch swings on stressed syllables: 0.14 is Chimera's normal, 0 is flat.
@export_range(0.0, 0.6, 0.01) var swing: float = 0.14
## More settings by key (the Voice Lab's levers), such as strain or breath; a key left out keeps
## the person's. Rendered voice files know only rate, pitch and swing.
@export var settings: Dictionary[String, float] = {}
