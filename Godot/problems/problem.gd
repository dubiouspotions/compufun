class_name Problem
extends Resource
## One computer problem, in the format of the wiki page "Computer Problems". CompuFunDB lists
## every Problem file in this folder.

enum Location { HARDWARE, SOFTWARE, BOTH }

## The internal reference, for example &"no_sound".
@export var short_name: StringName = &""
## How the customer is affected, in their words. The post-it shows it.
@export var perceived_issue: String = ""
## Where the symptoms are, and so which repairs the problem needs.
@export var location: Location = Location.HARDWARE
## The symptoms. Their combination is unique to this problem.
@export var symptoms: PackedStringArray = []
## The part that is broken, for a hardware problem: the player must replace it. null for a
## software problem.
@export var broken_part: Part
@export var hardware_steps: PackedStringArray = []
@export var software_steps: PackedStringArray = []
## For a hardware problem that shows in Windows, as an overheating computer does, until the
## hardware is fixed: the seconds after the desktop appears, which is when the startup sound
## starts, until Windows stutters and hangs. 0 keeps it running.
@export var hangs_after: float = 0.0
## The seconds from the start of the hang until the computer reboots.
@export var hang_seconds: float = 4.0
## How the problem breaks the computer's Win95 setup and when that is fixed; null when the problem
## has no software part.
@export var software_check: SoftwareCheck
