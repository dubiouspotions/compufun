extends "res://tests/test.gd"
## The Workview post-it label fits its text fast, however large the paper is on screen, and turns
## with the paper on a computer lying on its side.


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

	label.call("follow", Rect2(100, 50, 45, 160), -1)
	check("a paper turned a quarter turn lays the text out across its height", label.get("size"), Vector2(160, 45))
	check("and turns it (%s)" % label.get("rotation"), is_equal_approx(label.get("rotation"), -PI * 0.5), true)
	var centre: Vector2 = label.get("position") + label.get("pivot_offset")
	check("and centres it on the paper, to the pixel (%s)" % centre, centre.distance_to(Vector2(122.5, 130)) <= 1.0, true)
	label.queue_free()
	await _check_lying_in_workview()


# In the Workview, the text on the post-it of a lying computer reads from the bottom up.
func _check_lying_in_workview() -> void:
	var shop: Node3D = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	for lying: bool in [false, true]:
		check("restore a job in the Workview, lying %s" % lying, game.restore({"jobs": [{"customer": "res://customers/skater_bro.tres",
			"problem": "dust_overheat", "slot": 0, "lying": lying}], "focus_slot": 0, "view": "Workview"}), "")
		await create_timer(1.0).timeout  # the camera's move, and the case tipping over
		var post_it: Node3D = shop.call("pinned_post_it")
		check("the post-it is pinned, lying %s" % lying, post_it != null, true)
		if post_it != null:
			check("the post-it's text turns with the case, lying %s" % lying, shop.call("post_it_quarter_turns", post_it), -1 if lying else 0)
	shop.queue_free()
