@tool
class_name VoicePerson
extends Resource
## The bottom layer of a voice: who speaks. A Chimera body, shaped by the settings of its build and
## timbre; the mood of a line and an effect layer on top (Voices.layer). The Voice Lab (F3) makes
## them in voices/persons/, and each Customer has one.

## Chimera's body, the vocal tract that the settings shape. Rendered voice files know only this.
@export_enum("male", "female", "child") var body: String = "male"
## Settings by key (the Voice Lab's levers, native/chimera_voice/src/voice_type.rs); a key left
## out keeps Chimera's value.
@export var settings: Dictionary[String, float] = {}
