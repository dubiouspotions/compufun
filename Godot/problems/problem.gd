class_name Problem
extends Resource
## One computer problem, in the format of the wiki page "Computer Problems". CompufunDB lists
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
@export var hardware_steps: PackedStringArray = []
@export var software_steps: PackedStringArray = []
## How the problem breaks the computer's Win95 setup and when that is fixed; null when the problem
## has no software part.
@export var software_check: SoftwareCheck
