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
## A part that the customer took out: one place that takes it starts empty, and no piece of it is in
## the computer, so the player takes a new one from the storage. null for none.
@export var missing_part: Part
## The pieces that the customer put in the wrong places: the place that each lies on, to the part of
## the piece. Such a piece lies askew on a place that doesn't take it, which stays empty until the
## player lifts the piece off; a place of the piece's own part starts empty. Every place that a piece
## lies on must have its own piece missing or lying elsewhere. Empty for none.
@export var misplaced: Dictionary[Part, Part] = {}
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
## Stand-ins that are in the computer instead of the parts that they pose as ([member Part.poses_as]),
## one in every place that takes such a part, as Skater Bro's organs are. They work like those
## parts, so the hardware counts as fixed with them in.
@export var stand_ins: Array[Part] = []
## A flag that is 1 while none of the [member stand_ins] is in the computer, after the player took
## them out, and 0 while one is. Empty for none.
@export var replaced_flag: StringName = &""
## Plays, and jolts the view, each time the player opens the case while one of the [member stand_ins]
## is in it, as the organs show. null for none.
@export var reveal_stab: SoundSet
## A scene that the open case shows inside it for this visit, whatever the player takes out, such as
## blood on the case's floor. Its origin is the case's, with the floor at y 0.01. null for none.
@export var case_dressing: PackedScene
## True for a haunted computer, as NO PARTS is: its places start empty (Job.places), yet it runs as
## if every part were in (Job.has). Its hardware counts as fixed once the player has taken the side
## panel off and put it back on with its screws in (Job.was_opened), whatever the places hold.
@export var empty_case: bool = false
## False leaves the problem out of CompuFunDB: none of its symptoms or steps shows there.
@export var in_compufun_db: bool = true
## Corruption signs (their ids) that start as the customer sets the computer down, such as blood
## seeping out under it: each flag sign_<id> is set to the counter slot + 1, so that the sign can show
## at that slot.
@export var drop_off_signs: Array[StringName] = []
## How the problem breaks the computer's Win95 setup and when that is fixed; null when the problem
## has no software part.
@export var software_check: SoftwareCheck

## How the customer is affected, in their words. The post-it shows it. From the problem file.
var perceived_issue: String = ""
## What CompuFunDB calls this cause, such as "Clogged CPU fan"; empty names it by its id. From the
## problem file.
var cause: String = ""
## The symptoms: every complaint that this cause can bring, which the player searches CompuFunDB
## for. Problems that can bring the same complaint share its words. From the problem file.
var symptoms: PackedStringArray = []
## How each symptom shows in the game, for people: symptom to text; a symptom without one is
## missing. From the problem file.
var symptom_shows: Dictionary[String, String] = {}
## What the player can check on the computer, as CompuFunDB's CHECK lists them; [member check_yes]
## says which are true when this is the cause. From the problem file.
var checks: PackedStringArray = []
## Check to true (yes: in the file) or false (no:).
var check_yes: Dictionary[String, bool] = {}
## How each check fails in the game when this is the cause, for people: check to text. From the
## problem file.
var check_shows: Dictionary[String, String] = {}
## The repair steps that CompuFunDB prints, hardware first. From the problem file.
var hardware_steps: PackedStringArray = []
var software_steps: PackedStringArray = []
## For people: the story behind the problem and open questions; the game doesn't show it. From the
## problem file.
var notes: String = ""


## Replaces the text of this problem (the post-it, the cause, the symptoms, the checks, how they show, the
## steps and the notes) with the text of [param from]. The mechanics stay.
## What CompuFunDB calls this cause: [member cause], or the id when it has none.
func cause_name() -> String:
	return cause if cause != "" else String(short_name).capitalize()


func take_text(from: Problem) -> void:
	perceived_issue = from.perceived_issue
	cause = from.cause
	symptoms = from.symptoms.duplicate()
	symptom_shows = from.symptom_shows.duplicate()
	checks = from.checks.duplicate()
	check_yes = from.check_yes.duplicate()
	check_shows = from.check_shows.duplicate()
	hardware_steps = from.hardware_steps.duplicate()
	software_steps = from.software_steps.duplicate()
	notes = from.notes
