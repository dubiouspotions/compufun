@tool
class_name Reply
extends Resource
## What the customer says, and what the player can say back: one step of a conversation tree.
## A Conversation is the first step; each Choice leads to the next.

## null plays on every day, with any flags.
@export var when: Condition
## The flags that this reply sets as it starts to play: name to number, where 0 clears the flag.
## A reply starts a corruption sign with sign_<id>.
@export var set_flags: Dictionary[StringName, int] = {}
@export var lines: Array[DialogueLine] = []
## What the player can say after the last line. Game offers those whose condition matches and that
## have a reply that can play; none ends the step (see Choice.ends).
@export var choices: Array[Choice] = []
## What plays once the player leaves [member choices], by a choice that doesn't return or by the
## leave button: the rest of the conversation below the list. null goes on below the list above, or
## ends the conversation at the top.
@export var then: Reply


## Every line of this reply and of the replies under it, depth first.
func all_lines() -> Array[DialogueLine]:
	var found: Array[DialogueLine] = lines.duplicate()
	for choice: Choice in choices:
		if choice == null:
			continue
		for reply: Reply in choice.replies:
			if reply != null:
				found.append_array(reply.all_lines())
	return found
