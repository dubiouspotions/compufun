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
## Something in the computer that doesn't belong there, such as a hamster on the fan: a Part that no
## place takes, lying on the part that it sits on, which doesn't come out until it is out. The
## hardware is fixed only once it is out. null for none.
@export var blocker: Part
@export var hardware_steps: PackedStringArray = []
@export var software_steps: PackedStringArray = []
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
