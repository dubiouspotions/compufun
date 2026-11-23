@tool
class_name Conversation
extends Reply
## One conversation of a customer: the lines they say, one at a time, and the player's choices
## after them (see Reply). Game plays the first conversation whose trigger and condition match.

## The moment a conversation can play. More triggers come with their moments.
enum Trigger {
	ARRIVE, ## The customer brings a computer to the counter.
	PICKUP, ## The customer comes back for a finished computer. With no match, they take it and go.
	PHONE, ## The player calls the customer: what they say when they answer. With no match, a short hello.
	EVENT, ## The customer pops up behind the counter on their errand's day, in the midday, while their computer is on the counter (docs/dialogue.md). Plays once.
}

## What the conversation must get across, for people; the game doesn't show it.
@export_multiline var brief: String = ""
## Unique within its customer, for example &"arrive". A story file names it <code>/<trigger>/<n>.
@export var id: StringName = &""
@export var trigger: Trigger = Trigger.ARRIVE
## Plays only the first time it matches.
@export var once: bool = false
## The voice effect of every line, the replies' included, unless the line has its own; null for none.
@export var effect: VoiceEffect
## The last button of the player's first list of choices, unless a choice there ends the
## conversation: it lets the customer go.
@export var leave_text: String = "That's all, thanks."
## The last button of each deeper list of choices, unless a choice there ends the conversation: it
## goes back to the list above.
@export var back_text: String = "Something else..."
## An EVENT's line that the customer calls out as they pop up, before the dialogue box opens; null
## for none.
@export var pop_up: DialogueLine


## Every line, [member pop_up] first.
func all_lines() -> Array[DialogueLine]:
	var found := super()
	if pop_up != null:
		found.push_front(pop_up)
	return found
