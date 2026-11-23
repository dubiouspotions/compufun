extends "res://tests/test.gd"
## F9 builds its issue title and body from a report, without the network (ui/feedback_screen.gd).

const REPORT := {
	"kind": "bug",
	"note": "The post-it floats.\nSecond line.",
	"time": "2026-11-22T10:00:00",
	"author": "nevyn",
	"marks": [{"hotspot": "PostIt", "ui": ""}, {"hotspot": "", "ui": "/root/Main/UI/Label"}, {"hotspot": "", "ui": ""}],
	"game": {"view": "Main", "phase": "OPEN", "day": 2, "visitor": "res://customers/skater_bro.tres",
		"jobs": [{"problem": "dust_overheat", "slot": 0}], "focus_slot": 0, "connected_slot": -1},
	"build": {"commit": "abc1234", "branch": "main", "godot": "4.7.2", "os": "macOS"},
	"shot": "shot.png",
}

const BODY_HEAD := """The post-it floats.
Second line.

%IMAGE%

| | |
| --- | --- |
| Kind | bug |
| Author | nevyn |
| Time | 2026-11-22T10:00:00 |
| View | Main |
| Phase | OPEN |
| Day | 2 |
| Visitor | skater_bro.tres |
| Jobs | dust_overheat (slot 0) |
| Focus, cable | slot 0, slot -1 |
| Marks | `PostIt`; `/root/Main/UI/Label`; (nothing under it) |
| Build | abc1234 on main, Godot 4.7.2, macOS |

<details><summary>report.json</summary>

```json
"""


func run() -> void:
	var screen: Object = load("res://ui/feedback_screen.gd").new()  # by path: FeedbackScreen names Game
	check("the title is the kind and the note's first line", screen.call("_issue_title", REPORT), "[Bug] The post-it floats.")
	var body: String = screen.call("_issue_body", REPORT)
	check("the body starts with the note, the screenshot and the table", body.begins_with(BODY_HEAD), true)
	check("the body ends with the report as JSON", body.ends_with(JSON.stringify(REPORT, "  ") + "\n```\n\n</details>"), true)
	var drafted := REPORT.duplicate(true)
	drafted["game"]["jobs"] = [{"errand": "0102_skater_bro", "slot": 0}]
	drafted["story_drafts"] = {"res://story/errands/0102_skater_bro.errand": "customer: skater_bro\n\n== drop-off\n(happy) Yo ```!\n", "res://story/errands/0101_middle_manager.errand": ""}
	var with_drafts: String = screen.call("_issue_body", drafted)
	check("a job names its errand", with_drafts.contains("| Jobs | 0102_skater_bro (slot 0) |"), true)
	check("the drafts that the game played are in the issue", [with_drafts.contains("**The game played the writer's Story Lab drafts.**"), with_drafts.contains("<code>res://story/errands/0102_skater_bro.errand</code>"), with_drafts.contains("````\ncustomer: skater_bro"), with_drafts.contains("- `res://story/errands/0101_middle_manager.errand`: removed")], [true, true, true, true])
	check("no drafts, no drafts section", body.contains("Story Lab drafts"), false)
	screen.free()
