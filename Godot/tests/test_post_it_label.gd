extends "res://tests/test.gd"
## The Workview post-it label fits its text fast, however large the paper is on screen.


func run() -> void:
	var label: Control = (load("res://ui/post_it_label.tscn") as PackedScene).instantiate()  # untyped: PostItLabel names Game, which -s scripts can't compile
	root.add_child(label)
	game.restore({"day": 1, "jobs": [{"customer": "res://customers/skater_bro.tres", "slot": 0}]})
	label.set("job", game.jobs[0])
	await process_frame

	var started := Time.get_ticks_msec()
	label.call("follow", Rect2(-500000, -200000, 1000000, 400000))
	var ms := Time.get_ticks_msec() - started
	check("a paper a million pixels wide fits in under 100 ms (took %d ms)" % ms, ms < 100, true)
	check("the font stops at max_font_size", label.call("fitting_font_size"), label.get("max_font_size"))

	label.call("follow", Rect2(0, 0, 160, 45))
	var slanted: int = label.call("fitting_font_size")
	check("a slanted paper gets a smaller font that still fits (%d)" % slanted, slanted > 1 and slanted < roundi(160 * float(label.get("font_fraction"))), true)
	label.call("follow", Rect2(0, 0, 0, 0))
	check("an empty paper gets size 1", label.call("fitting_font_size"), 1)
