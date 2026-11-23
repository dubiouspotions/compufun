class_name Problem
extends Resource
## One computer problem. Its .tres holds the mechanics; the text that writers edit (the post-it,
## the symptoms and the steps) is in the problem file story/problems/<short_name>.problem, which
## StoryFiles.load_week fills into the cached resource (docs/dialogue.md). CompuFunDB lists every
## Problem file in this folder.

enum Location { HARDWARE, SOFTWARE, BOTH }

## The internal reference and the file names, for example &"no_sound".
@export var short_name: StringName = &""
## Where the symptoms are, and so which repairs the problem needs.
@export var location: Location = Location.HARDWARE
## The part that is broken, for a hardware problem: the player must replace it. null for a
## software problem.
@export var broken_part: Part
## Something in the computer that doesn't belong there, such as a hamster on the fan: a Part that no
## place takes, lying on the part that it sits on, which doesn't come out until it is out. The
## hardware is fixed only once it is out. null for none.
@export var blocker: Part
## For a hardware problem that shows in Windows, as an overheating computer does, until the
## hardware is fixed: the seconds after the desktop appears, which is when the startup sound
## starts, until Windows stutters and hangs. 0 keeps it running.
@export var hangs_after: float = 0.0
## The seconds from the start of the hang until the computer reboots.
@export var hang_seconds: float = 4.0
## Not empty: the hang shows the Win95 bluescreen with this message, in silence, instead of freezing
## with a buzz, as a broken hard drive does.
@export_multiline var hang_message: String = ""
## For a hardware problem that shows on the screen, as an overheating GPU does: how much the picture
## breaks up in coloured blocks and torn lines while the computer runs, 0 (not at all) to 1, until
## the hardware is fixed.
@export_range(0.0, 1.0) var screen_artifacts: float = 0.0
## How the problem breaks the computer's Win95 setup and when that is fixed; null when the problem
## has no software part.
@export var software_check: SoftwareCheck

## How the customer is affected, in their words. The post-it shows it. From the problem file.
var perceived_issue: String = ""
## The symptoms, as CompuFunDB lists them and its records mark them. Their combination is unique to
## this problem. From the problem file.
var symptoms: PackedStringArray = []
## How each symptom shows in the game, for people: symptom to text; a symptom without one is
## missing. From the problem file.
var symptom_shows: Dictionary[String, String] = {}
## The repair steps that CompuFunDB prints, hardware first. From the problem file.
var hardware_steps: PackedStringArray = []
var software_steps: PackedStringArray = []
## For people: the story behind the problem and open questions; the game doesn't show it. From the
## problem file.
var notes: String = ""


## Replaces the text of this problem (the post-it, the symptoms, how they show, the steps and the
## notes) with the text of [param from]. The mechanics stay.
func take_text(from: Problem) -> void:
	perceived_issue = from.perceived_issue
	symptoms = from.symptoms.duplicate()
	symptom_shows = from.symptom_shows.duplicate()
	hardware_steps = from.hardware_steps.duplicate()
	software_steps = from.software_steps.duplicate()
	notes = from.notes
