@abstract
class_name SoftwareCheck
extends Resource
## How a software problem breaks a healthy Win95 setup, and how to tell that it is fixed again.
## A problem's setup describes the healthy computer; the check applies the break at boot.


## Breaks [param setup], a computer's running copy, which may hold the player's changes from an
## earlier visit. Breaking it twice must give the same result as once: Game.restore makes new jobs,
## which break the copy again.
@abstract func apply_break(setup: Win95Setup) -> void


## True when [param setup] no longer has the problem.
@abstract func is_fixed(setup: Win95Setup) -> bool


## Repairs [param setup] as the player would, so that [method is_fixed] holds after it: the inverse
## of [method apply_break]. For tests and the week bot; the game itself never calls it.
@abstract func apply_fix(setup: Win95Setup) -> void
