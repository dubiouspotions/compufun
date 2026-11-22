class_name Errand
extends Resource
## One visit on a Day: who comes in, what is wrong with their computer this time, what the visit is
## for and what is said. A customer who comes back on a later day brings the same computer, with
## that visit's problem. Loaded from a story file (docs/dialogue.md).

## What the customer does with their computer on this visit.
enum Brings {
	LEAVES, ## They leave it on the counter for repair.
	NOTHING, ## They come without one, and leave when the conversation ends.
	SHOWS, ## It stands on the counter while they visit, and goes with them.
}

@export var customer: Customer
## The problem of the computer on this visit; null for a visit that needs no repair.
@export var problem: Problem
@export var brings: Brings = Brings.LEAVES
## null comes always. Two errands with one [member code] are alternatives: the first, by file name,
## whose condition matches comes.
@export var when: Condition
## What the visit is for, for people; the game doesn't show it.
@export_multiline var brief: String = ""
## The drop-off, pick-up and phone conversations; for each trigger the first that matches plays.
@export var conversations: Array[Conversation] = []
## The errand code from the file name: the day (2 digits) and the place in it (2 digits), such as
## "0503"; "" for an errand that no story file holds.
@export var code: String = ""


## The day of the week in [member code], 1 to 7; 0 without a code.
func day_number() -> int:
	return code.substr(0, 2).to_int() if code.length() == 4 else 0


## The place in the day in [member code], from 1; 0 without a code.
func place() -> int:
	return code.substr(2, 2).to_int() if code.length() == 4 else 0
