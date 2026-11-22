@tool
class_name Story
extends RefCounted
## The story as text, for people and agents: an outline of each customer's conversation trees, and
## the missing links of the whole week. The Dialogue and Week tabs show them; dev/story.gd prints
## them from the command line (docs/building-and-testing.md).


## [param customer]'s conversations as an indented outline: each conversation with its moment and
## condition, the customer's lines, and under them the player's choices (">") and their replies
## ("-"), with the flags each needs and sets.
static func outline(customer: Customer) -> String:
	var out := PackedStringArray()
	out.append("# %s (%s)" % [customer.resource_path.get_file().get_basename(), customer.spoken_name()])
	for c: Conversation in customer.conversations:
		if c == null:
			out.append("## (empty conversation slot)")
			continue
		var tags := PackedStringArray([Conversation.Trigger.keys()[c.trigger]])
		if c.once:
			tags.append("once")
		out.append("## %s  [%s]" % [c.id, ", ".join(tags + tags(c.when, c.set_flags))])
		_outline_reply(c, customer.spoken_name(), "", out)
	return "\n".join(out) + "\n"


static func _outline_reply(reply: Reply, speaker: String, indent: String, out: PackedStringArray) -> void:
	for line: DialogueLine in reply.lines:
		if line != null:
			out.append("%s%s (%s): %s" % [indent, speaker, line.pose, line.text.replace("\n", " ")])
	for choice: Choice in reply.choices:
		if choice == null:
			out.append(indent + "> (empty choice slot)")
			continue
		var tags := tags(choice.when, {})
		if choice.ends:
			tags.append("ends")
		out.append("%s> Player: %s%s" % [indent, choice.text.replace("\n", " "), "  [%s]" % ", ".join(tags) if not tags.is_empty() else ""])
		for each: Reply in choice.replies:
			if each == null:
				out.append(indent + "  - (empty reply slot)")
				continue
			var reply_tags := tags(each.when, each.set_flags)
			out.append("%s  - reply%s" % [indent, "  [%s]" % ", ".join(reply_tags) if not reply_tags.is_empty() else ""])
			_outline_reply(each, speaker, indent + "    ", out)


## A condition and the flags set, as short tags: "day 2-3", "needs x", "not y", "sets z=2".
static func tags(when: Condition, sets: Dictionary[StringName, int]) -> PackedStringArray:
	var tags := PackedStringArray()
	if when != null:
		if when.from_day != 1 or when.to_day != 7:
			tags.append("day %d-%d" % [when.from_day, when.to_day])
		for flag: StringName in when.need_flags:
			tags.append("needs " + flag)
		for flag: StringName in when.not_flags:
			tags.append("not " + flag)
	for flag: StringName in sets:
		tags.append("sets %s%s" % [flag, "" if sets[flag] == 1 else "=%d" % sets[flag]])
	return tags


## The missing links of the week, one sentence each, naming where: flags that nothing sets or
## nothing checks, choices that can never play, empty replies, and errands whose customer has nothing
## to say on that day. Adds a message to [param errors] for data that doesn't load.
static func missing_links(customers: Array[Customer], days: Array[Day], errors: Array[String]) -> PackedStringArray:
	var found := PackedStringArray()
	var flag_index := FlagField.index(customers, days, errors)
	var setters: Dictionary = flag_index["setters"]
	var checkers: Dictionary = flag_index["checkers"]
	var signs: Dictionary = flag_index["signs"]
	for flag: StringName in checkers:
		if not setters.has(flag) and not signs.has(flag):
			found.append("Nothing sets the flag %s, which %s checks." % [flag, ", ".join(checkers[flag])])
	for flag: StringName in setters:
		if not checkers.has(flag):
			found.append("Nothing checks the flag %s, which %s sets." % [flag, ", ".join(setters[flag])])
	for c: Customer in customers:
		var who := c.resource_path.get_file().get_basename()
		for conversation: Conversation in c.conversations:
			if conversation == null:
				found.append("%s has an empty conversation slot." % who)
				continue
			_check_reply(conversation, "%s/%s" % [who, conversation.id], found)
			if conversation.trigger == Conversation.Trigger.PHONE and not conversation.choices.is_empty():
				found.append("%s/%s is a phone call with choices, which the phone doesn't show yet." % [who, conversation.id])
	for d: Day in days:
		for i: int in d.errands.size():
			var errand := d.errands[i]
			if errand == null or errand.customer == null:
				continue
			var arrives := errand.customer.conversations.any(func(c: Conversation) -> bool:
				return c != null and c.trigger == Conversation.Trigger.ARRIVE and (c.when == null or (c.when.from_day <= d.number and d.number <= c.when.to_day)))
			if not arrives:
				found.append("Day %d, errand %d: %s has no ARRIVE conversation for day %d." % [d.number, i + 1, errand.customer.resource_path.get_file().get_basename(), d.number])
	return found


static func _check_reply(reply: Reply, where: String, found: PackedStringArray) -> void:
	if reply.lines.is_empty() and reply.choices.is_empty():
		found.append("%s says nothing and offers no choice." % where)
	for choice: Choice in reply.choices:
		if choice == null:
			found.append("%s has an empty choice slot." % where)
			continue
		var asked := "%s > \"%s\"" % [where, choice.text.left(30)]
		if choice.text.strip_edges() == "":
			found.append("%s has a choice with no text." % where)
		if choice.replies.is_empty():
			found.append("%s has no reply, so it is never offered." % asked)
		for each: Reply in choice.replies:
			if each == null:
				found.append("%s has an empty reply slot." % asked)
				continue
			if choice.ends and not each.choices.is_empty():
				found.append("%s ends the conversation, so its reply's choices never show." % asked)
			_check_reply(each, asked, found)
