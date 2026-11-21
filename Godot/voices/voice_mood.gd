@tool
class_name VoiceMood
extends Resource
## How Chimera says a line in one pose: its speed, its pitch and how much the pitch swings.
## voices/moods/<pose>.tres holds the mood of each pose.

## The speaking speed: 1 is normal, more is faster.
@export_range(0.5, 2.0, 0.01) var rate: float = 1.0
## The pitch, as a factor on the voice's own: 1 is normal, more is higher.
@export_range(0.5, 2.0, 0.01) var pitch: float = 1.0
## How far the pitch swings on stressed syllables: 0.14 is Chimera's normal, 0 is flat.
@export_range(0.0, 0.6, 0.01) var swing: float = 0.14
