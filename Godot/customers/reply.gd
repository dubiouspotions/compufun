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


## The choices that the player can say after this reply on day [param day] with [param flags]:
## their condition matches, and one of their replies can play ([method Choice.reply_on]). In order.
func offered_on(day: int, flags: Dictionary[StringName, int]) -> Array[Choice]:
	var found: Array[Choice] = []
	for choice: Choice in choices:
		if choice != null and (choice.when == null or choice.when.is_met(day, flags)) and choice.reply_on(day, flags) != null:
			found.append(choice)
	return found


## Every line of this reply, of the replies under it and of its [member then], depth first.
func all_lines() -> Array[DialogueLine]:
	var found: Array[DialogueLine] = lines.duplicate()
	for choice: Choice in choices:
		if choice == null:
			continue
		for reply: Reply in choice.replies:
			if reply != null:
				found.append_array(reply.all_lines())
	if then != null:
		found.append_array(then.all_lines())
	return found
