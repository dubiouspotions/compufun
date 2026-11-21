@tool
class_name Conversation
extends Resource
## One conversation of a customer: the lines they say, one at a time. Game plays the first
## conversation whose trigger and condition match.

## The moment a conversation can play. More triggers come with their moments.
enum Trigger {
	ARRIVE, ## The customer brings a computer to the counter.
	PICKUP, ## The customer comes back for a finished computer. With no match, they take it and go.
	PHONE, ## The player calls the customer: what they say when they answer. With no match, a short hello.
}

## Unique within its customer, for example &"arrive".
@export var id: StringName = &""
@export var trigger: Trigger = Trigger.ARRIVE
## null plays on every day, with any flags.
@export var when: Condition
## Plays only the first time it matches.
@export var once: bool = false
@export var lines: Array[DialogueLine] = []
## The voice effect of every line, unless the line has its own; null for none.
@export var effect: VoiceEffect
