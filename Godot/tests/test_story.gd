extends "res://tests/test.gd"
## The story check (StoryCheck) finds the missing links of a week and indexes who sets and who checks
## each flag.


func run() -> void:
	var week := StoryFiles.Week.new()
	for n: int in range(1, 8):
		var d := Day.new()
		d.number = n
		week.days.append(d)
	week.days[0].set_flags = {&"sign_pipedream": 1, &"skater_bro_runs_cambion": 1}
	add(week, "0101_skater_bro", """customer: skater_bro
problem: dust_overheat

== drop-off
(neutral) Hi.
+ Did you install anything? [if knows_install]
	set pat_told
	(happy) Yes.
+ Hello?
- Bye. [if not gone_young_entrepreneur]
	(sulky) Bye then.
""")
	add(week, "0102_office_girl", "customer: office_girl\nproblem: dust_overheat\n\n== pick-up\n(happy) Thanks.\n")
	add(week, "0103_hat_guy", "customer: hat_guy\ncomputer: none\n")
	add(week, "0201_hat_guy", "customer: hat_guy\ncomputer: none\nwhen: flag_a\n\n== drop-off\n(neutral) A.\n")
	add(week, "0201_office_girl", "customer: office_girl\ncomputer: none\nwhen: not flag_a\n\n== drop-off\n(neutral) Not A.\n")
	add(week, "0202_hat_guy", "customer: hat_guy\ncomputer: none\nwhen: flag_b, day 2\n\n== drop-off\n(neutral) B.\n\n== pick-up\nset flag_a, flag_b\n(neutral) Set.\n")
	var bare := Problem.new()
	bare.take_over_path("res://problems/test_bare.tres")
	var bare_errand: Errand = add(week, "0301_hat_guy", "customer: hat_guy\n\n== drop-off\n(neutral) Hm.\n")
	bare_errand.problem = bare
	add(week, "0302_hat_guy", """customer: hat_guy
computer: none

== drop-off
(neutral) Bye now. [leaving]
(neutral) Still here.
+ Anything else?
	(neutral) See you. [leaving]
- No.
	(neutral) Fine.
	(neutral) Later! [leaving]
	(neutral) Really later! [leaving]
""")
	add(week, "0303_hat_guy", """customer: hat_guy
computer: none

== drop-off
(neutral) Over there. [look right]
(neutral) Up there. [look up]
(neutral) Bye. [look left] [leaving]

== phone
(neutral) Look! [look ahead]
""")

	var links := StoryCheck.missing_links(week)
	var text := "\n".join(links)
	var drop_off := "res://story/errands/0101_skater_bro.errand (0101/drop-off/1"
	check("every link starts with a file path", Array(links).all(func(link: String) -> bool: return link.begins_with("res://")), true)
	check("a checked flag that nothing sets", text.contains(drop_off + " > \"Did you install anything?\") checks the flag knows_install, which nothing sets."), true)
	check("a set flag that nothing checks", text.contains(drop_off + " > \"Did you install anything?\") sets the flag pat_told, which nothing checks."), true)
	check("a choice without lines", text.contains(drop_off + " > \"Hello?\"): the + choice has no lines, so its list shows again at once."), true)
	check("a mood without a portrait or a voice", [text.contains("\"Bye then.\" is in the mood sulky, which res://people/skater_bro/person.tres has no portrait for."), text.contains("which has no voice (res://voices/moods/sulky.tres)")], [true, true])
	check("an errand without a drop-off", text.contains("res://story/errands/0102_office_girl.errand has no drop-off conversation."), true)
	check("but not one that brings nothing and says nothing", text.contains("0103_hat_guy.errand has no drop-off"), false)
	check("alternatives that cover every flag value always come", text.contains("errand code 0201"), false)
	check("an errand code that can come with nobody", text.contains("res://story/errands/0202_hat_guy.errand: errand code 0202 can come with nobody on day 2: with no flags set, no alternative's 'when' holds."), true)
	check("a problem without repair mechanics", text.contains("0301_hat_guy.errand names the problem res://problems/test_bare.tres, which has no repair mechanics"), true)
	check("signs, Cambion and the [x] link their flags", [text.contains("sign_pipedream"), text.contains("runs_cambion"), text.contains("gone_young_entrepreneur")], [false, false, false])
	var leaving := "res://story/errands/0302_hat_guy.errand (0302/drop-off/1"
	check("a leaving line that a line follows", text.contains(leaving + "): \"Bye now.\" is [leaving], but the conversation can go on after it, so it plays in the dialogue box."), true)
	check("a leaving line that its + list follows", text.contains(leaving + " > \"Anything else?\"): \"See you.\" is [leaving]"), true)
	check("but not the leaving lines that end the conversation", [text.contains("\"Later!\""), text.contains("Really later!")], [false, false])
	var looks := "res://story/errands/0303_hat_guy.errand (0303/"
	check("a look that is not left, right or ahead", text.contains(looks + "drop-off/1): \"Up there.\" has the look up, which is not left or right or ahead."), true)
	check("a look that never turns the view", [text.contains(looks + "drop-off/1): \"Bye.\" has the look left, which turns the view only"), text.contains(looks + "phone/1): \"Look!\" has the look ahead, which turns the view only")], [true, true])
	check("but not a look before a line in the box", text.contains("Over there."), false)
	check("no other links", links.size(), 13)

	var index := StoryCheck.flag_index(week)
	check("who sets pat_told", index[&"pat_told"]["set_by"], PackedStringArray([drop_off + " > \"Did you install anything?\")"]))
	check("a day sets a sign, which checks it", [index[&"sign_pipedream"]["set_by"], Array(index[&"sign_pipedream"]["checked_by"]).any(func(c: String) -> bool: return c.begins_with("res://corruption/pipedream.tscn ("))], [PackedStringArray(["res://story/days/day_1.day (on start)"]), true])
	check("an unset sign is known for the flag picker", index.has(&"sign_logo_blue"), true)
	check("a pick-up sets two flags", index[&"flag_b"]["set_by"], PackedStringArray(["res://story/errands/0202_hat_guy.errand (0202/pick-up/1)"]))
	check("the sign titles", StoryCheck.sign_titles()[&"sign_customer_x"], "An [x] closes the young entrepreneur for good")


func add(week: StoryFiles.Week, file_name: String, text: String) -> Errand:
	var parsed := StoryFormat.parse_errand(text, "res://story/errands/%s.errand" % file_name)
	check("%s parses" % file_name, parsed.errors, PackedStringArray())
	var errand := parsed.value as Errand
	week.days[errand.day_number() - 1].errands.append(errand)
	return errand
