extends "res://tests/test.gd"
## The Story Lab's Call-outs section (dev/story_lab/call_outs_panel.gd): everyone and each customer
## in the list, a set for day 7 with an effect added to a customer as a draft that the game plays,
## and text that doesn't parse, or leaves everyone without a plain set, kept out of the drafts.

const SKATER := "res://story/callouts/skater_bro.callouts"
const EVERYONE := "res://story/callouts/everyone.callouts"


func run() -> void:
	var drafts := StoryDrafts.new(user_dir() + "drafts/")
	drafts.git = func(_arguments: PackedStringArray) -> Dictionary: return {"code": 1, "out": ""}
	var lab: Control = (load("res://dev/story_lab/story_lab.tscn") as PackedScene).instantiate()
	lab.set("drafts", drafts)
	root.add_child(lab)
	await process_frame
	lab.call("show_section", "Call-outs")
	var panel: StoryCallOutsPanel = lab.call("call_outs_panel")
	var list: ItemList = panel.get("_list")
	check("the list has everyone and each customer", list.item_count, 1 + LabUI.resource_names("res://customers/").size())
	check("everyone's opens first", [panel.path(), list.get_item_text(0)], [EVERYONE, "Everyone   1 set"])

	panel.open(&"skater_bro")
	var code: CodeEdit = panel.get("_code")
	check("a customer without a file starts empty", [panel.path(), code.text], [SKATER, ""])
	(panel.get("_day") as OptionButton).select(7)
	var effect: OptionButton = panel.get("_effect")
	for i: int in effect.item_count:
		if effect.get_item_text(i) == "cambion_glitch":
			effect.select(i)
	panel.call("_add_set")
	check("Add set writes the set's head and a line to fill", code.text, "== waiting [if day 7] [effect cambion_glitch]\n(neutral) ")
	panel.call("_save")
	check("a set without a line's text isn't saved", [drafts.has(SKATER), (panel.get("_errors") as ItemList).item_count], [false, 1])
	code.insert_text_at_caret("I am always here.")
	panel.call("_save")
	check("the set is a draft", drafts.text(SKATER), "== waiting [if day 7] [effect cambion_glitch]\n(neutral) I am always here.")
	check("the list counts it", list.get_item_text(list.get_selected_items()[0]).ends_with("1 set"), true)
	check("the game plays it", game.story_errors, PackedStringArray())
	check("restore day 7", game.restore({"day": 7, "phase": "OPEN"}), "")
	var skater := load("res://customers/skater_bro.tres") as Customer
	check("on day 7 the skater calls it out", game.call_outs_of(skater).lines[0].text, "I am always here.")
	check("Send names the call-outs in the title", StoryIssue.title([{"path": SKATER}] as Array[Dictionary], ""), "Story: call-outs skater_bro")

	panel.open(CallOuts.EVERYONE)
	var before := code.text
	code.text = "== waiting [if day 1]\n(neutral) Hello?\n"
	panel.call("_save")
	check("everyone without a plain set isn't saved", drafts.has(EVERYONE), false)
	code.text = before
	lab.queue_free()
	await process_frame
