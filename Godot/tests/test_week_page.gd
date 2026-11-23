extends "res://tests/test.gd"
## The wiki's "The Week" page (dev/story_week_page.gd) shows each day with its date and every errand
## with its brief, problem, missing links and conversations, from the story files.


func run() -> void:
	var week = game.get("week")
	var dates := range(1, 8).map(func(n: int) -> Dictionary: return game.call("date_of", n))
	var missing := StoryCheck.missing_links(week)
	var page := StoryWeekPage.markdown(week, dates, missing, "abc12345")
	check("it names the commit and says where to edit", [page.contains("from commit abc12345"), page.contains("Story Lab (F4")], [true, true])
	check("day 1 with its date", page.contains("## Day 1: Friday, May 31, 1996"), true)
	check("day 7", page.contains("## Day 7: Thursday, June 6, 1996"), true)
	var errands := 0
	for d: Day in week.days:
		for errand: Errand in d.errands:
			errands += 1
			check("%s has a heading" % errand.code, page.contains("### %s %s" % [errand.code, errand.customer.spoken_name()]), true)
	check("one heading per errand", page.count("\n### "), errands)
	check("the skater's brief and problem", [page.contains("the calculator answers 666"), page.contains("**Problem:** Dust Overheat. Post-it: \"Windows starts and turns off\"")], [true, true])
	check("a conversation as text", page.contains("<details><summary>Drop-off: ") and page.contains("(neutral) Yo! What's up! Is this the computer repair shop?"), true)
	check("each missing link under its errand", page.count("\n- ") >= missing.size(), true)
