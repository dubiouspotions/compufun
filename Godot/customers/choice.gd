@tool
class_name Choice
extends Resource
## One thing that the player can say to a customer, and the customer's replies to it: the first
## reply whose condition matches plays.

## What the player says, on the choice's button.
@export_multiline var text: String = ""
## null offers the choice on every day, with any flags.
@export var when: Condition
## The customer's possible replies, in order; the first that matches plays.
@export var replies: Array[Reply] = []
## The conversation ends after the reply, and the customer goes on as after their last line. Off,
## a reply without choices of its own goes back to the choices that this one was among.
@export var ends: bool = false
## After the reply, the list that this choice is in shows again (a + in a story file). Off, the
## conversation goes on below the list (the [member Reply.then] of the reply that offers it).
@export var returns: bool = false


## The reply that plays on day [param day] with [param flags]: the first whose condition matches;
## null when none does.
func reply_on(day: int, flags: Dictionary[StringName, int]) -> Reply:
	for reply: Reply in replies:
		if reply != null and (reply.when == null or reply.when.is_met(day, flags)):
			return reply
	return null
