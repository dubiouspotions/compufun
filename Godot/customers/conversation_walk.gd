class_name ConversationWalk
extends RefCounted
## The way through one conversation, as docs/dialogue.md ("Conversations") plays it, without UI:
## which lines the customer says now, which choices the player has, and where a pick leads. Game
## decides which choices are offered and sets the flags, so [member Game.conversation] must be the
## conversation that walks; a walk on a [ConversationWalk.Sandbox] reads and sets its own flags
## instead, and leaves Game as it was. The dialogue overlay shows a walk; tests and the Story Lab
## drive one headless:
## [codeblock]
## var walk := ConversationWalk.new(Game.conversation)
## while not walk.is_over():
##     if not walk.lines().is_empty():
##         show(walk.lines())
##         walk.said()
##     elif walk.leave_text() != "":
##         walk.leave()
##     else:
##         walk.pick(walk.choices()[0])
## [/codeblock]
## At any moment the walk is at exactly one of: lines to say, choices to pick from, or the end.
## Leaving lines ([member DialogueLine.leaving]) after which the conversation ends are not among
## [method lines]: the walk ends before them, and [method leaving_lines] holds them. A leaving line
## that something follows plays among [method lines].

## The day and flags that a walk plays on instead of Game's, so that the game stays as it was (the
## Story Lab's Play in editor).
class Sandbox:
	extends RefCounted
	## The day number that conditions see, from 1.
	var day: int
	## The flags that conditions read; what plays sets its flags here, as Game would set them.
	var flags: Dictionary[StringName, int]

	func _init(on_day: int, with_flags: Dictionary[StringName, int]) -> void:
		day = on_day
		flags = with_flags


# A list of choices that the walk is in: the reply that offers it, and the choice last picked from it.
class _Frame:
	extends RefCounted
	var owner: Reply
	var picked: Choice

	func _init(of: Reply) -> void:
		owner = of


## The conversation that this walk plays.
var conversation: Conversation
## The day and flags that the walk plays on; null plays through Game.
var sandbox: Sandbox

# The lists that the walk is in, the outermost first.
var _stack: Array[_Frame] = []
# The reply whose lines play now; null while choices show, at the end, and while leaving lines
# play before a list.
var _reply: Reply
# The lines that play now.
var _lines: Array[DialogueLine] = []
# Leaving lines held back: called out if the walk ends after them, else shown with what follows.
var _leaving: Array[DialogueLine] = []
var _choices: Array[Choice] = []
var _picked: Dictionary[Choice, bool] = {}
# The last pick ends the conversation after its reply's lines.
var _ending: bool = false
var _over: bool = false


## Starts at [param of]'s lines, or at its choices when it has no lines. The conversation's own
## flags are Game's to set as it starts; on a [param on] sandbox, the walk sets them there.
## [br][br]With [param from], a line of [param of], the walk starts at that line instead, as if the
## player had come that way: inside the lists above it, with the choices on the way picked (greyed
## in a + list), and the flags of every reply on the way set (the conversation's own on a sandbox
## only). The reply that holds [param from] plays whatever its condition says.
## [br][br]A null conversation, or a [param from] that is not in it, is over at once, with an error.
func _init(of: Conversation, from: DialogueLine = null, on: Sandbox = null) -> void:
	conversation = of
	sandbox = on
	if of == null:
		push_error("ConversationWalk: no conversation")
		_over = true
		return
	if sandbox != null:
		_set_flags(of.set_flags)
	if from == null:
		_play(of)
		return
	var way: Array[Reply] = []
	if not _find(of, from, way):
		push_error("ConversationWalk: the line '%s' is not in '%s'" % [from.text, of.id])
		_over = true
		return
	for reply: Reply in way.slice(1):
		_went_on(reply)
	if not _stack.is_empty() and _stack.back().picked.replies.has(way.back()):
		_ending = _stack.back().picked.ends
	_play(way.back(), way.back().lines.find(from))


## The lines that the customer says now, in order; empty while choices show and at the end.
func lines() -> Array[DialogueLine]:
	return _lines


## The leaving lines that the customer calls out as they go, in order, once the walk is over;
## empty before that, or when the conversation ends with a line in the box.
func leaving_lines() -> Array[DialogueLine]:
	return _leaving if _over else ([] as Array[DialogueLine])


## The player has seen every line of [method lines]: the walk goes on to the reply's choices, to the
## lines below the list, or to the end. Sets the flags of the lines below a list (Game.go_on, or in
## the sandbox) as it reaches them.
func said() -> void:
	if _lines.is_empty():
		push_error("ConversationWalk.said: no lines play in '%s'" % conversation.id)
		return
	_lines = []
	if _reply == null:
		return  # the leaving lines before a list
	var reply := _reply
	_reply = null
	_after(reply)


## The choices that the player can pick now, as Game offered them when the walk reached the list;
## empty while lines play and at the end.
func choices() -> Array[Choice]:
	return _choices if _lines.is_empty() else ([] as Array[Choice])


## True when the player picked [param choice] earlier in this walk; the overlay greys it.
func was_picked(choice: Choice) -> bool:
	return _picked.has(choice)


## The text of the button under [method choices] that leaves the list, or "" when it has none: a list
## with a choice that goes on below it (a -) or that ends the conversation has none. The outermost
## list says the conversation's leave_text, a deeper one its back_text.
func leave_text() -> String:
	var offered := choices()
	if offered.is_empty() or offered.any(func(c: Choice) -> bool: return c.ends or not c.returns):
		return ""
	return conversation.leave_text if _stack.size() == 1 else conversation.back_text


## The player says [param choice], one of [method choices]: its reply plays (Game.choose sets its
## flags, or the walk sets them in the sandbox). Returns false, with an error, when the choice is
## not offered or no reply can play; then the choices stay.
func pick(choice: Choice) -> bool:
	if not choices().has(choice):
		push_error("ConversationWalk.pick: '%s' is not offered in '%s'" % [choice.text if choice != null else "null", conversation.id])
		return false
	var reply := _choose(choice)
	if reply == null:
		return false
	_stack.back().picked = choice
	_picked[choice] = true
	_choices = []
	_ending = choice.ends
	_play(reply)
	return true


## The player presses the leave button ([method leave_text]): the walk goes on below the list, as
## after a - choice. Fails with an error when the list has no leave button.
func leave() -> void:
	if leave_text() == "":
		push_error("ConversationWalk.leave: the list in '%s' has no leave button" % conversation.id)
		return
	_choices = []
	_below(_stack.pop_back().owner)


## True once the conversation has ended: an [code][end][/code] choice's lines are said, or the walk
## ran off the top.
func is_over() -> bool:
	return _over


# [param reply]'s lines start at [param first], the held leaving lines before them; with none but
# leaving lines, those are held and what follows them starts.
func _play(reply: Reply, first: int = 0) -> void:
	var cut := reply.lines.size()
	while cut > first and reply.lines[cut - 1].leaving:
		cut -= 1
	if cut == first:
		_leaving.append_array(reply.lines.slice(first))
		_after(reply)
		return
	_lines = _leaving.duplicate()
	_lines.append_array(reply.lines.slice(first, cut))
	_leaving.assign(reply.lines.slice(cut))
	_reply = reply


# True when [param line] is in [param at] or below it; then [param way] holds the replies from
# [param at] down to the one with the line, and the walk's lists and picks are those on the way.
func _find(at: Reply, line: DialogueLine, way: Array[Reply]) -> bool:
	way.push_back(at)
	if at.lines.has(line):
		return true
	for choice: Choice in at.choices.filter(func(c: Choice) -> bool: return c != null):
		for reply: Reply in choice.replies.filter(func(r: Reply) -> bool: return r != null):
			var frame := _Frame.new(at)
			frame.picked = choice
			_stack.push_back(frame)
			if _find(reply, line, way):
				_picked[choice] = true
				return true
			_stack.pop_back()
	if at.then != null and _find(at.then, line, way):
		return true
	way.pop_back()
	return false


func _offered(reply: Reply) -> Array[Choice]:
	return reply.offered_on(sandbox.day, sandbox.flags) if sandbox != null else Game.offered(reply)


# The reply that [param choice] gets, its flags set; null, with an error, when none can play.
func _choose(choice: Choice) -> Reply:
	if sandbox == null:
		return Game.choose(choice)
	var reply := choice.reply_on(sandbox.day, sandbox.flags)
	if reply == null:
		push_error("ConversationWalk: '%s' has no reply that can play on day %d with flags %s" % [choice.text, sandbox.day, sandbox.flags])
		return null
	_set_flags(reply.set_flags)
	return reply


# The walk goes on to [param reply] other than by a pick: its flags are set.
func _went_on(reply: Reply) -> void:
	if sandbox == null:
		Game.go_on(reply)
	else:
		_set_flags(reply.set_flags)


func _set_flags(sets: Dictionary[StringName, int]) -> void:
	for flag_name: StringName in sets:
		@warning_ignore("static_called_on_instance")
		Game.put_flag(sandbox.flags, flag_name, sets[flag_name])


# The list [param offered] shows, after the leaving lines held back, which play first.
func _offer(offered: Array[Choice]) -> void:
	_choices = offered
	_lines = _leaving
	_leaving = []


# [param reply]'s lines are said: its own choices, or on below them.
func _after(reply: Reply) -> void:
	if _ending:
		_over = true
		return
	var offered := _offered(reply)
	if offered.is_empty():
		_below(reply)
		return
	_stack.push_back(_Frame.new(reply))
	_offer(offered)


# The list of [param owner] is left: on to its then, or up.
func _below(owner: Reply) -> void:
	if owner.then == null:
		_up()
		return
	_went_on(owner.then)
	_play(owner.then)


# The reply that the innermost list's pick led to has played to its end: back to that list for a +,
# else on below it. With no list left, the conversation is over.
func _up() -> void:
	if _stack.is_empty():
		_over = true
		return
	var frame: _Frame = _stack.back()
	if frame.picked.returns:
		var offered := _offered(frame.owner)
		if not offered.is_empty():
			_offer(offered)
			return
	_stack.pop_back()
	_below(frame.owner)
