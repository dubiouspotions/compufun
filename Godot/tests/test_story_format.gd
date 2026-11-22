extends "res://tests/test.gd"
## Story files: an errand and a day parse into resources, write back to the same text, and a broken
## file names the line and what is wrong (docs/dialogue.md).

const ERRAND := """customer: skater_bro
problem: dust_overheat
when: not skater_gone, days 1-3
brief:
	Meet the skater.
	Nothing points the player there.

== drop-off [once]
brief: He arrives cheerful.
(neutral) Yo! Is this the computer repair shop?
- Welcome to CompuFun!
	(happy) Sweet!
	(neutral) My computer isn't working!
- Did your mom give it away?
	(angry) Whatever dude.. [effect cambion_glitch]

- What seems to be the issue?
	(problem) Windows opens, then it turns off!

+ When did it start?
	set skater_new_windows, skater_mood=2
	(thinking) Right after I got the new Windows.
+ Did you install anything?
	if skater_new_windows
		set skater_cambion
		(happy) Oh yeah. Floppies.
	else
		(neutral) Nah.
+ Cambion? [if skater_cambion]
	(happy) It's the rad one. [effect cambion_glitch] [leaving]
- OK, leave it with me. [end]
	(happy) Cool.
(neutral) This line plays after a minus choice that doesn't end.

== pick-up [if skater_cambion, day 5] [effect cambion_glitch] [leave Bye.]
(happy) Dude!

== phone
"""

const DAY := """weather: rain
warp: 0.15
on start: sign_pipedream
on close: sign_logo_blue, logo_stage=2
close signs: posters_bounce
between customers: 10-20
notes:
	Early corruption signs start.
	Never obvious.
"""


func run() -> void:
	var parsed := StoryFormat.parse_errand(ERRAND, "res://story/errands/0101_skater_bro.errand")
	check("the errand parses", parsed.errors, PackedStringArray())
	var errand := parsed.value as Errand
	check("code, day and place", [errand.code, errand.day_number(), errand.place()], ["0101", 1, 1])
	check("customer and problem", [errand.customer.resource_path, errand.problem.resource_path], ["res://customers/skater_bro.tres", "res://problems/dust_overheat.tres"])
	check("when", [errand.when.not_flags, errand.when.from_day, errand.when.to_day], [[&"skater_gone"], 1, 3])
	check("brief", errand.brief, "Meet the skater.\nNothing points the player there.")
	check("three conversations", errand.conversations.map(func(c: Conversation) -> String: return c.id), ["0101/drop-off/1", "0101/pick-up/1", "0101/phone/1"])

	var talk := errand.conversations[0]
	check("drop-off: once, brief, first line", [talk.once, talk.brief, talk.lines[0].text, talk.lines[0].mood], [true, "He arrives cheerful.", "Yo! Is this the computer repair shop?", &"neutral"])
	check("the greeting list", talk.choices.map(func(c: Choice) -> String: return c.text), ["Welcome to CompuFun!", "Did your mom give it away?"])
	check("a line's own effect", talk.choices[1].replies[0].lines[0].effect.resource_path, "res://voices/effects/cambion_glitch.tres")
	var issue := talk.then
	check("both greetings meet at one question", issue.choices.map(func(c: Choice) -> String: return c.text), ["What seems to be the issue?"])
	var questions := issue.then
	check("the questions: + returns, - goes on", questions.choices.map(func(c: Choice) -> bool: return c.returns), [true, true, true, false])
	check("set flags", questions.choices[0].replies[0].set_flags, {&"skater_new_windows": 1, &"skater_mood": 2})
	var install := questions.choices[1]
	check("if and else", [install.replies.size(), install.replies[0].when.need_flags, install.replies[1].when], [2, [&"skater_new_windows"], null])
	check("a choice's condition", questions.choices[2].when.need_flags, [&"skater_cambion"])
	var called: DialogueLine = questions.choices[2].replies[0].lines[0]
	check("effect and leaving on one line", [called.text, called.effect != null, called.leaving], ["It's the rad one.", true, true])
	check("end", questions.choices[3].ends, true)
	check("after the list", questions.then.lines[0].text, "This line plays after a minus choice that doesn't end.")
	var pickup := errand.conversations[1]
	check("pick-up tags", [pickup.when.need_flags, pickup.when.from_day, pickup.when.to_day, pickup.effect != null, pickup.leave_text], [[&"skater_cambion"], 5, 5, true, "Bye."])
	check("an empty phone", errand.conversations[2].lines.size(), 0)
	check("written back the same", StoryFormat.write_errand(errand), ERRAND)

	var day_parsed := StoryFormat.parse_day(DAY, "res://story/days/day_2.day")
	check("the day parses", day_parsed.errors, PackedStringArray())
	var day := day_parsed.value as Day
	check("the day", [day.number, day.rain, day.warp, day.set_flags, day.close_flags, day.close_signs, day.first_wait_seconds, day.gap_seconds],
		[2, true, 0.15, {&"sign_pipedream": 1}, {&"sign_logo_blue": 1, &"logo_stage": 2}, [&"posters_bounce"], Vector2(5, 8), Vector2(10, 20)])
	check("the day written back the same", StoryFormat.write_day(day), DAY)

	_check_errors("errand", StoryFormat.parse_errand("customer: nobody\ncomputer: maybe\nhat: red\n\n== lunch\n(neutral) Hi\n", "res://story/errands/0101_x.errand").errors, [
		":1: no customer 'nobody'", ":2: computer: 'maybe' is not leaves, none or shows", ":3: 'hat: red' is not a key here", ":5: '== lunch': the trigger must be",
	])
	_check_errors("script", StoryFormat.parse_errand("customer: skater_bro\n\n== drop-off\n(neutral) Hi\n  (happy) spaces\n\t\t(happy) too deep\nelse\n- Bye [maybe]\n", "res://story/errands/0101_x.errand").errors, [
		":5: indented with spaces", ":6: indented deeper", ":7: 'else' must start", ":8: [maybe] is not a tag of a choice",
	])
	_check_errors("file names", StoryFormat.parse_errand("customer: skater_bro\n", "res://story/errands/skater.errand").errors, ["the file name must be"])
	_check_errors("day", StoryFormat.parse_day("weather: snow\nwarp: 2\non start: Bad Flag\n", "res://story/days/day_9.day").errors, [
		"day_9.day:1: the file name", ":1: weather: 'snow'", ":2: warp: '2'", ":3: 'Bad Flag' is not a flag name",
	])


# Each of [param expected] is in one error, in order, and there are no others.
func _check_errors(label: String, errors: PackedStringArray, expected: Array) -> void:
	var found := []
	for i: int in mini(errors.size(), expected.size()):
		found.append(errors[i].contains(expected[i]))
	check("%s errors: %s" % [label, errors], [errors.size(), found], [expected.size(), expected.map(func(_e: String) -> bool: return true)])
