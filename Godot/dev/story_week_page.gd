class_name StoryWeekPage
extends RefCounted
## The week as one Markdown page for people who read it outside the game: the wiki's "The Week",
## which CI rebuilds from the story files on every push to main. Nobody edits the page; the Story
## Lab edits the files.

const WEEKDAYS: PackedStringArray = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const MONTHS: PackedStringArray = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const BRINGS: Dictionary[Errand.Brings, String] = {
	Errand.Brings.LEAVES: "leaves the computer",
	Errand.Brings.NOTHING: "no computer",
	Errand.Brings.SHOWS: "shows the computer, takes it back",
}
const TRIGGERS: Dictionary[Conversation.Trigger, String] = {
	Conversation.Trigger.ARRIVE: "Drop-off",
	Conversation.Trigger.PICKUP: "Pick-up",
	Conversation.Trigger.PHONE: "Phone",
	Conversation.Trigger.EVENT: "Event",
}


## The page for [param week]. [param dates] holds each day's date (Time datetime dictionaries, day 1
## first); [param missing] is StoryCheck.missing_links(week); [param commit] names what it was built
## from.
static func markdown(week: StoryFiles.Week, dates: Array, missing: PackedStringArray, commit: String) -> String:
	var out := PackedStringArray()
	out.append("The week, day by day: who comes, what each visit is for, and what is said. CI builds this page from the story files in the repo (`Godot/story/`) on every push to `main`, from commit %s. Don't edit it here: edit the week in the Story Lab (F4 in the running game). The writers' guide is [[Writing Dialogue and Planning the Week]]." % commit)
	out.append("")
	out.append("%d things are still missing in the week; each visit lists its own." % missing.size())
	for d: Day in week.days:
		out.append("")
		out.append("## Day %d: %s" % [d.number, _date(dates[d.number - 1] if d.number - 1 < dates.size() else {})])
		var facts := PackedStringArray(["rain" if d.rain else "clear", "warp %s" % str(snappedf(d.warp, 0.01))])
		out.append("_%s_" % ", ".join(facts))
		if d.notes != "":
			out.append("")
			out.append(d.notes)
		var signs := _day_signs(d)
		if signs != "":
			out.append("")
			out.append(signs)
		for errand: Errand in d.errands:
			_errand(out, errand, missing)
	return "\n".join(out) + "\n"


static func _errand(out: PackedStringArray, errand: Errand, missing: PackedStringArray) -> void:
	out.append("")
	var who := errand.customer.spoken_name() if errand.customer != null else "nobody"
	out.append("### %s %s (%s%s)" % [errand.code, who, BRINGS[errand.brings], ", in the shop before it opens" if errand.before_opening else ""])
	if errand.when != null:
		out.append("**Comes when:** %s" % StoryConditionEditor.describe(errand.when))
		out.append("")
	out.append("**What this visit is for:** %s" % (errand.brief.replace("\n", " ") if errand.brief != "" else "_not written yet_"))
	out.append("")
	var problem := errand.problem
	if problem == null:
		out.append("**Problem:** none")
	else:
		var built := "" if StoryProblemPanel.built(problem) else " (not built yet)"
		out.append("**Problem:** %s%s. Post-it: \"%s\"" % [String(problem.short_name).capitalize(), built, problem.perceived_issue])
	var own := PackedStringArray()
	for link: String in missing:
		if link.begins_with(errand.file):
			own.append(link.trim_prefix(errand.file).lstrip(" :").strip_edges())
	if not own.is_empty():
		out.append("")
		out.append("**Still missing:**")
		for link: String in own:
			out.append("- " + link)
	var sections := StoryFormat.write_errand(errand).split("\n== ")
	for i: int in errand.conversations.size():
		var c := errand.conversations[i]
		var section: String = sections[i + 1] if i + 1 < sections.size() else ""
		out.append("")
		out.append("<details><summary>%s: %d lines%s</summary>" % [TRIGGERS[c.trigger], c.all_lines().size(), (" (%s)" % c.brief) if c.brief != "" else ""])
		out.append("")
		out.append("```")
		out.append(section.substr(section.find("\n") + 1).strip_edges(false, true))  # without its "==" line
		out.append("```")
		out.append("")
		out.append("</details>")


static func _day_signs(d: Day) -> String:
	var parts := PackedStringArray()
	if not d.set_flags.is_empty():
		parts.append("as the day starts: " + StoryFlagsEditor.describe(d.set_flags))
	if not d.close_flags.is_empty():
		parts.append("at closing, for the rest of the week: " + StoryFlagsEditor.describe(d.close_flags))
	if not d.close_signs.is_empty():
		parts.append("at closing, until the next morning: " + ", ".join(PackedStringArray(d.close_signs.map(func(id: StringName) -> String: return StoryFactPicker.humanize(id)))))
	return ("**Remembers:** " + "; ".join(parts)) if not parts.is_empty() else ""


static func _date(date: Dictionary) -> String:
	if date.is_empty():
		return "?"
	return "%s, %s %d, %d" % [WEEKDAYS[date.weekday], MONTHS[date.month], date.day, date.year]
