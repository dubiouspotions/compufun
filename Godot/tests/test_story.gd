extends "res://tests/test.gd"
## The story check finds the missing links, and the outline shows the tree.


func run() -> void:
	var c: Customer = load("res://customers/skater_bro.tres").duplicate()
	c.take_over_path("res://customers/test_pat.tres")
	var talk := Conversation.new()
	talk.id = &"arrive"
	talk.when = Condition.new()
	talk.when.from_day = 2
	talk.when.to_day = 2
	var line := DialogueLine.new()
	line.text = "Hi."
	talk.lines = [line]
	var asked := Choice.new()
	asked.text = "Did you install anything?"
	asked.when = Condition.new()
	asked.when.need_flags = [&"knows_install"]
	var dead := Choice.new()
	dead.text = "Hello?"
	talk.choices = [asked, dead]
	var reply := Reply.new()
	reply.lines = [line]
	reply.set_flags = {&"pat_told": 1}
	asked.replies = [reply]
	c.conversations = [talk]
	var day := make_day(1, [[c, load("res://problems/no_sound.tres")]])
	var errors: Array[String] = []
	var links: PackedStringArray = Story.missing_links([c] as Array[Customer], [day] as Array[Day], errors)
	var text := "\n".join(links)
	check("a checked flag that nothing sets", text.contains("Nothing sets the flag knows_install"), true)
	check("a set flag that nothing checks", text.contains("Nothing checks the flag pat_told"), true)
	check("a choice without a reply", text.contains("\"Hello?\" has no reply"), true)
	check("an errand on a day without an arrival", text.contains("Day 1, errand 1: test_pat has no ARRIVE conversation for day 1"), true)
	check("no load errors", errors, [] as Array[String])
	var outline := Story.outline(c)
	check("the outline shows the choice and its reply", outline.contains("> Player: Did you install anything?  [needs knows_install]") and outline.contains("  - reply  [sets pat_told]"), true)
